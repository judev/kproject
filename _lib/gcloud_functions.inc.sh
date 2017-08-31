
gcloud_auth() {
  GCP_ACCOUNT=$(gcloud auth list 2>/dev/null | grep -oE '[^ ]+@'$PROJECT_EMAIL_SUFFIX)
  if [ -z "$GCP_ACCOUNT" ]
  then
    echo -n "Please enter your $PROJECT_EMAIL_SUFFIX email address: "
    read GCP_ACCOUNT
    gcloud auth login "$GCP_ACCOUNT"
  fi

  export GCP_ACCOUNT
}

gcloud_docker_login() {
  GCP_ACCOUNT=$(gcloud auth list 2>/dev/null | grep -oE '[^ ]+@'$PROJECT_EMAIL_SUFFIX)
  if [ -z "$(gcloud auth application-default print-access-token --account="$GCP_ACCOUNT")" ]
  then
    gcloud auth application-default login $GCP_ACCOUNT
  fi
  docker login -u oauth2accesstoken -p "$(gcloud auth print-access-token --account="$GCP_ACCOUNT")" https://eu.gcr.io
}

gcloud_use() {
  CONFIG_NAME="$1"

  if ! gcloud config configurations describe "$CONFIG_NAME" >/dev/null 2>&1
  then
    gcloud config configurations create "$CONFIG_NAME" --no-activate
  fi

  gcloud config configurations activate "$CONFIG_NAME"

  gcloud_auth

}

