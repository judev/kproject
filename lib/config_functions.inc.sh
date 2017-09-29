
if [ -n "$PROJECT_ROOT_PATH" ]
then
  CONFIG_ENVIRONMENTS_PATH="$PROJECT_ROOT_PATH/environments"
else
  echo "PROJECT_ROOT_PATH not set" 1>&2
  exit 1
fi

CONFIG_ROOT_PATH=$PROJECT_ROOT_PATH

config_export() {
  eval $(cat "$CONFIG_ROOT_PATH/.project.properties" | sed 's/^/export /')
  eval $(cat "$CONFIG_ROOT_PATH/environments/$ENVIRONMENT_NAME/common.properties" | sed 's/^/export /')
  export ENVIRONMENT_PATH="$CONFIG_ROOT_PATH/environments/$ENVIRONMENT_NAME"
  export ENVIRONMENT_CHART="$ENVIRONMENT_PATH/${PROJECT_ID}-${ENVIRONMENT_NAME}"
  export -f config_get_minikube info error error_exit
}

config_get_minikube() {
  MINIKUBE="minikube --profile=${PROJECT_ID}-local"
  ($MINIKUBE status | grep Running > /dev/null) || $MINIKUBE start
  $MINIKUBE addons list | grep -qF 'ingress: enabled' || $MINIKUBE addons enable ingress
  eval $($MINIKUBE docker-env)
}

config_init() {
  CONFIG_ROOT_PATH=$1
  CONFIG_ENVIRONMENTS_PATH="$1/environments"

  if [ -f "$CONFIG_ROOT_PATH/.project.properties" ]
  then
    . "$CONFIG_ROOT_PATH/.project.properties"
  fi

  if [ -L "$CONFIG_ENVIRONMENTS_PATH/current" ]
  then
    NAME="$(basename "$(readlink "$CONFIG_ENVIRONMENTS_PATH/current")")"
    . "$CONFIG_ENVIRONMENTS_PATH/current/common.properties"
    CONFIG_NAME="$PROJECT_ID-$NAME"
    __config_post_init
  else
    E=$(config_list | head -n1)
    if [ -n "$E" ]
    then
      config_use "$E"
    fi
  fi
}

config_list() {
  for NAME in $(ls -1 "$CONFIG_ENVIRONMENTS_PATH")
  do
    if [ "$NAME" != "current" ]
    then
      if [ "$(readlink "$CONFIG_ENVIRONMENTS_PATH/current")" == "$CONFIG_ENVIRONMENTS_PATH/$NAME" ]
      then
        echo "$NAME (active)"
      else
        echo "$NAME"
      fi
    fi
  done
}

config_current() {
  if [ -L "$CONFIG_ENVIRONMENTS_PATH/current" ]
  then
    echo "$(basename "$(readlink "$CONFIG_ENVIRONMENTS_PATH/current")")"
  fi
}

config_use() {
  NAME="$1"

  if [ -f "$CONFIG_ROOT_PATH/.project.properties" ]
  then
    . "$CONFIG_ROOT_PATH/.project.properties"
  fi

  if [ -e "$CONFIG_ENVIRONMENTS_PATH/$NAME" ]
  then
    unlink "$CONFIG_ENVIRONMENTS_PATH/current" 
    ln -s "$CONFIG_ENVIRONMENTS_PATH/$NAME" "$CONFIG_ENVIRONMENTS_PATH/current" 
    . "$CONFIG_ENVIRONMENTS_PATH/current/common.properties"
  else
    echo "Configuration $NAME not found" 1>&2
    return 1
  fi

  CONFIG_NAME="$PROJECT_ID-$NAME"

  kproject gcloud use "$CONFIG_NAME"

  if [ "$ENVIRONMENT_TYPE" == "minikube" ]
  then
    config_get_minikube
    kubectl config use-context "$CONFIG_NAME"
  else
    GCP_ACCOUNT=$(gcloud auth list 2>/dev/null | grep -oE '[^ ]+@'$PROJECT_EMAIL_SUFFIX)
    while IFS='' read -r line || [[ -n "$line" ]]; do
      gcloud config set ${line/=/ }
      if grep -qF container/cluster <<<"$line"
      then
        gcloud container clusters get-credentials ${line#*=} --account="$GCP_ACCOUNT"
      fi
    done < "$CONFIG_ENVIRONMENTS_PATH/current/gcloud-configuration.properties"
  fi

  __config_post_init

}

__config_post_init() {
  if [ -n "$KPROJECT_COMPLETING" ]
  then
    return
  fi
  local NEWMINIKUBE=$(test -z "$MINIKUBE" && echo 1)
  if [ -n "$NEWMINIKUBE" ]
  then
    config_get_minikube
  fi
  if [ "$ENVIRONMENT_TYPE" == "minikube" ]
  then
    if [ -n "$NEWMINIKUBE" ]
    then
      MACHINE_IP="$($MINIKUBE ip)"

      grep -E "$MACHINE_IP.+$BASE_HOSTNAME" /etc/hosts >/dev/null || (
        info "Adding '$BASE_HOSTNAME' to /etc/hosts - you may be prompted for your password"

        set +e
        GSED="$(which gsed)"
        set -e
        if [ -x "$GSED" ]
        then
          SED=gsed
        else
          SED=sed
        fi

        sudo bash -c "$SED -i'' '/$BASE_HOSTNAME/d' /etc/hosts; \
          echo '$MACHINE_IP $BASE_HOSTNAME' >> /etc/hosts; \
          echo '$MACHINE_IP en.$BASE_HOSTNAME' >> /etc/hosts; \
          echo '$MACHINE_IP www.$BASE_HOSTNAME' >> /etc/hosts; \
          echo '$MACHINE_IP admin.$BASE_HOSTNAME' >> /etc/hosts; \
          echo '$MACHINE_IP newsletter.$BASE_HOSTNAME' >> /etc/hosts"

        echo "Done"
      )
    fi

    kubectl config use-context "$CONFIG_NAME" > /dev/null
  fi

  (kubectl get deployment --namespace=kube-system | grep -F tiller >/dev/null 2>&1) || (
    helm init
    helm repo list | grep "$CHART_REPO_GCS_BUCKET" >/dev/null || helm repo add "$CHART_REPO_GCS_BUCKET" "https://$CHART_REPO_GCS_BUCKET.storage.googleapis.com"
  )
}

