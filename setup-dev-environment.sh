#!/usr/bin/env bash

set -e

HERE=$(dirname "$BASH_SOURCE")

PROJECT_ROOT_PATH=$1
if [ -z "$PROJECT_ROOT_PATH" ]
then
  PROJECT_ROOT_PATH=$(pwd)
elif [ -d "$PROJECT_ROOT_PATH" ]
then
  PROJECT_ROOT_PATH=$(command cd "$PROJECT_ROOT_PATH"; pwd)
else
  mkdir -p "$PROJECT_ROOT_PATH"
  PROJECT_ROOT_PATH=$(command cd "$PROJECT_ROOT_PATH"; pwd)
fi
export PROJECT_ROOT_PATH

# Check that the necessary software is installed

"$HERE/check-dev-environment.sh" >/dev/null

# Set up default environment configurations, if they don't already exist

if [ -f "$PROJECT_ROOT_PATH/.project.properties" ]
then
  . "$PROJECT_ROOT_PATH/.project.properties"
else
  if [ -f "$PROJECT_ROOT_PATH/.project.defaults" ]
  then
    . "$PROJECT_ROOT_PATH/.project.defaults"
  else
    echo -n "Enter project ID ([a-z0-9_-]+): "
    read PROJECT_ID
    echo -n "Enter project Email suffix: @"
    read PROJECT_EMAIL_SUFFIX
    echo -n "Enter Docker repo: "
    read DOCKER_REPO
    echo -n "Enter Chart repo GCS bucket name: "
    read CHART_REPO_GCS_BUCKET
  fi
fi

test -d "$PROJECT_ROOT_PATH/environments" || mkdir -p "$PROJECT_ROOT_PATH/environments"
test -d "$PROJECT_ROOT_PATH/environments/local" || mkdir -p "$PROJECT_ROOT_PATH/environments/local"

test -f "$PROJECT_ROOT_PATH/.project.properties" || (
  echo PROJECT_ROOT_PATH='"'"$PROJECT_ROOT_PATH"'"'
  echo CHART_REPO_LOCAL_PATH='"'"$PROJECT_ROOT_PATH/charts"'"'
  echo PROJECT_ID='"'"$PROJECT_ID"'"'
  echo PROJECT_EMAIL_SUFFIX='"'"$PROJECT_EMAIL_SUFFIX"'"'
  echo DOCKER_REPO='"'"$DOCKER_REPO"'"'
  echo CHART_REPO_GCS_BUCKET='"'"$CHART_REPO_GCS_BUCKET"'"'
) > "$PROJECT_ROOT_PATH/.project.properties"

test -f "$PROJECT_ROOT_PATH/environments/local/common.properties" || (
  echo ENVIRONMENT_NAME=local
  echo ENVIRONMENT_TYPE=minikube
  echo BASE_HOSTNAME=${PROJECT_ID}.local
  echo URL_SCHEME=http
  echo HELM_RELEASE_NAME=local
) > "$PROJECT_ROOT_PATH/environments/local/common.properties" 

test -f "$PROJECT_ROOT_PATH/environments/local/gcloud-configuration.properties" || (
  echo core/project=staging-${PROJECT_EMAIL_SUFFIX}
  echo compute/zone=europe-west1-b
) > "$PROJECT_ROOT_PATH/environments/local/gcloud-configuration.properties" 

test -L "$PROJECT_ROOT_PATH/environments/current" || (
  ln -s "$PROJECT_ROOT_PATH/environments/local" "$PROJECT_ROOT_PATH/environments/current" 
)

. "$HERE/_lib/log.inc.sh"
. "$HERE/_lib/require.inc.sh"

# check for GPG key, check that it's registered with blackbox otherwise send it to admin
BB_ADMINS="$PROJECT_ROOT_PATH/keyrings/live/blackbox-admins.txt"
if [ -r "$BB_ADMINS" ]
then

  FOUND=""
  while IFS='' read -r line || [[ -n "$line" ]]; do
    if gpg --list-secret-keys | grep -qF "$line"
    then
      FOUND=1
      break
    fi
  done < "$BB_ADMINS"
  if [ -z "$FOUND" ]
  then
    error "GPG key not registered"
    if email=$(gpg --list-secret-keys | grep -Eo "[^<]+@$PROJECT_EMAIL_SUFFIX")
    then
      echo "Exporting your GPG public key"
      gpg --export --output "$email".pub "$email"
      echo "Please send the file $(pwd)/${email}.pub to the admin of this git repo"
      exit
    else
      cat <<EOT
Generate a GPG key for your $PROJECT_EMAIL_SUFFIX email address and share public key
with someone who already has decrypt access.

Use the GPG defaults, use a strong passphrase that you won't forget.

Replace example@$PROJECT_EMAIL_SUFFIX with your real $PROJECT_EMAIL_SUFFIX email address.

gpg --gen-key
gpg --export --output example@$PROJECT_EMAIL_SUFFIX.pub example@$PROJECT_EMAIL_SUFFIX

Send the .pub file to someone with decrypt access.

Once they've added your key you can "git pull" and continue setup.
EOT
    fi
    exit 1
  fi

fi

BLACKBOX_DECRYPT=$(require blackbox_decrypt_all_files)
"$BLACKBOX_DECRYPT"

. "$PROJECT_ROOT_PATH/code/clone.sh"

BOOT_FILE="$(dirname "$BASH_SOURCE")/_setup-dev-environment-shell.inc.sh"

bash --rcfile <(echo "test -f /etc/profile && . /etc/profile ; test -f ~/.bash_profile && . ~/.bash_profile ; . $BOOT_FILE")

