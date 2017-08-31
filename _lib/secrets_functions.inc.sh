
secrets_changed() {
  if test -z "$@" || grep -qF ' --all' "$@"
  then
    for SECRET_PATH in "$PROJECT_ROOT_PATH/private/$ENVIRONMENT_NAME"/*.properties
    do
      __secret_check_changed "$SECRET_PATH"
    done
  else
    for SECRET_PATH in "$@"
    do
      __secret_check_changed "$SECRET_PATH"
    done
  fi
}

__secret_check_changed() {
  local SECRET_PATH="$1"
  local SECRET_NAME=$(basename "$SECRET_PATH")
  SECRET_NAME=${SECRET_NAME%.properties}
  local LOCAL_TS=$(stat -c'%Y' "$SECRET_PATH")
  local REMOTE_TS=$(date -d "$(kubectl get secret "$SECRET_NAME" -o custom-columns=date:metadata.creationTimestamp --no-headers 2>/dev/null)" +'%s')
  if [ "$LOCAL_TS" -gt "$REMOTE_TS" ]
  then
    echo "$SECRET_PATH"
  fi
}

secrets_deploy() {
  if test -z "$@"
  then
    secrets_deploy_changed
  elif grep -qF ' --all' "$@"
  then
    secrets_deploy_all
  else
    for SECRET_PATH in "$@"
    do
      secrets_deploy_path "$SECRET_PATH"
    done
  fi
}

secrets_deploy_all() {
  for SECRET_PATH in "$PROJECT_ROOT_PATH/private/$ENVIRONMENT_NAME"/*.properties
  do
    secrets_deploy_path "$SECRET_PATH"
  done
}

secrets_deploy_changed() {
  for SECRET_PATH in $(secrets_changed)
  do
    secrets_deploy_path "$SECRET_PATH"
  done
}

secrets_deploy_path() {
  local SECRET_PATH=$1
  base=$(basename "$SECRET_PATH")
  base=${base%.properties}

  kubectl delete secret "$base" > /dev/null 2>&1
  kubectl create secret generic "$base" $(__secrets_build_args "$SECRET_PATH")
}

__secrets_build_args() {
  local SECRET_PATH="$1"
  local args=""
  local keypair
  for keypair in $(cat "$SECRET_PATH")
  do
    args="$args --from-literal=$keypair"
  done
  echo "$args"
}

secrets_create_registry_key() {
  if ! kubectl get secret project-registry-key >/dev/null 2>&1
  then
    if [ -f "$PROJECT_ROOT_PATH/private/project-registry-service-account.json" ]
    then
      local EMAIL=$(python -c"import json; print (json.load(open("'"'"$PROJECT_ROOT_PATH/private/project-registry-service-account.json"'"'"))['client_email'])")
      kubectl create secret docker-registry project-registry-key \
        --docker-username "_json_key" \
        --docker-password "$(cat "$PROJECT_ROOT_PATH/private/project-registry-service-account.json")" \
        --docker-email "$EMAIL" \
        --docker-server "https://$DOCKER_REPO"
    else
      echo "private/project-registry-service-account.json not found" 1>&2
      exit 1
    fi
  fi
}

