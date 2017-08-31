
container_list() {

  (
    command cd "$PROJECT_ROOT_PATH/containers"
    find . -mindepth 1 -maxdepth 1 -type d -printf '%f\n'
  )

}

__resolve_container_path() {
  if [ -d "$1" ]
  then
    echo $(command cd "$1"; pwd)
  elif [ -d "$PROJECT_ROOT_PATH/containers/$1" ]
  then
    echo $(command cd "$PROJECT_ROOT_PATH/containers/$1"; pwd)
  else
    echo $1
  fi
}

container_build() {
  config_get_minikube

  PUSH=""
  if grep -Fq '\--push' <<<"$*"
  then
    PUSH="1"
  fi

  gcloud_docker_login

  for CONTAINER_PATH in $@
  do
    if [ "$CONTAINER_PATH" != "--push" ]
    then
      CONTAINER_PATH=$(__resolve_container_path $CONTAINER_PATH)
      if [ -f "$CONTAINER_PATH/Dockerfile" ]
      then
        IMAGE="$(basename "$CONTAINER_PATH")"

        date +'%y%m%d-%H%M%S' > "$CONTAINER_PATH/VERSION"
        VERSION=$(cat "$CONTAINER_PATH"/VERSION)

        test -x "$CONTAINER_PATH/build.sh" && "$CONTAINER_PATH/build.sh"

        docker build -t $DOCKER_REPO/$IMAGE:latest $CONTAINER_PATH
        docker tag $DOCKER_REPO/$IMAGE:latest $DOCKER_REPO/$IMAGE:$VERSION

        info "Built $DOCKER_REPO/$IMAGE:$VERSION"

        VALUES_FILES=$(find "$PROJECT_ROOT_PATH/services/" -name 'values*.yaml' | xargs grep -Fl "$DOCKER_REPO")
        for F in $VALUES_FILES
        do
           if grep -q "$DOCKER_REPO/$IMAGE" "$F"
           then
            grep -nA1 "$DOCKER_REPO/$IMAGE" "$F" | \
              grep tag: | \
              sed -r 's/^([0-9]+)-( *tag: )(.+)$/sed -i"" '"'"'\1s\/tag: .*\/tag: '$VERSION'\/'"'"' /' | \
              awk '{print $0"'$F'"}' | \
              sh && info "Updated image tag in $F"
          fi
        done

        if [ -n "$PUSH" ]
        then
          container_push "$CONTAINER_PATH"
        fi

      else
        echo "No Dockerfile in $CONTAINER_PATH" 1>&2
      fi
    fi
  done

}

container_push() {

  config_get_minikube

  gcloud_docker_login

  for CONTAINER_PATH in $@
  do
    CONTAINER_PATH=$(__resolve_container_path $CONTAINER_PATH)
    IMAGE="$(basename "$CONTAINER_PATH")"
    VERSION=$(cat "$CONTAINER_PATH"/VERSION)
    docker push $DOCKER_REPO/$IMAGE:latest
    docker push $DOCKER_REPO/$IMAGE:$VERSION

    info "Pushed $DOCKER_REPO/$IMAGE:$VERSION"

    if container_security_enabled
    then
      container_security_push "$IMAGE" "$VERSION"
    fi

  done

}

container_security_enabled() {
  test -r "$PROJECT_ROOT_PATH/.tenable-container-registry"
}

container_security_push() {
  local IMAGE=$1
  local VERSION=$2
  if container_security_enabled
  then
    (
      . "$PROJECT_ROOT_PATH/.tenable-container-registry"
      docker tag "$DOCKER_REPO/$IMAGE:$VERSION" "$TENABLE_IO_DOCKER_REPO/$IMAGE:latest"
      docker tag "$DOCKER_REPO/$IMAGE:$VERSION" "$TENABLE_IO_DOCKER_REPO/$IMAGE:$VERSION"
      docker push "$TENABLE_IO_DOCKER_REPO/$IMAGE:latest"
      docker push "$TENABLE_IO_DOCKER_REPO/$IMAGE:$VERSION"
    )

    info "Pushed $TENABLE_IO_DOCKER_REPO/$IMAGE:$VERSION"

    container_security_check "$IMAGE" "$VERSION"

  fi

}

container_security_check() {
  local NAME=$1
  local VERSION=$2 # optional, will default to latest
  if container_security_enabled
  then
    if [ -z "$VERSION" ]
    then
      local CONTAINER_PATH=$(__resolve_container_path "$NAME")
      VERSION=$(cat "$CONTAINER_PATH"/VERSION)
    fi
    local URL="$TENABLE_IO_DOCKER_REPO/$NAME:$VERSION"
    (
      . "$PROJECT_ROOT_PATH/.tenable-container-registry"

      json=$(curl -s -H "X-ApiKeys: accessKey=$TENABLE_IO_ACCESS_KEY; secretKey=$TENABLE_IO_SECRET_KEY" https://cloud.tenable.com/container-security/api/v1/reports/by_image?image_id=$(docker images --format='{{.ID}}' "$container_url" | sed 's/^sha256://'))
      set +e
      message=$(jq .message --exit-status --raw-output <<<"$json")
      res=$?
      set -e
      if [ "$res" == "0" ]
      then
        echo "Security scan: $message" 1>&2
        exit 1
      else
        jq '("Risk score: \(.risk_score) / 10"),("Issues found: \(.findings|length)"),"Full report: https://cloud.tenable.com/container-security/reports/tag/html/\(.id)"' -r <<<"$json"
      fi

    )
  else
    error_exit "No security repo configured"
  fi
}

