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
test -d "$PROJECT_ROOT_PATH/environments/staging" || mkdir -p "$PROJECT_ROOT_PATH/environments/staging"

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
  echo BASE_HOSTNAME=medshr.local
  echo URL_SCHEME=http
  echo HELM_RELEASE_NAME=local
) > "$PROJECT_ROOT_PATH/environments/local/common.properties" 

test -f "$PROJECT_ROOT_PATH/environments/local/gcloud-configuration.properties" || (
  echo core/project=staging-medshr-net
  echo compute/zone=europe-west1-b
) > "$PROJECT_ROOT_PATH/environments/local/gcloud-configuration.properties" 

test -f "$PROJECT_ROOT_PATH/environments/staging/common.properties" || (
  echo ENVIRONMENT_NAME=staging
  echo ENVIRONMENT_TYPE=gke
  echo BASE_HOSTNAME=staging-medshr.net
  echo URL_SCHEME=https
  echo HELM_RELEASE_NAME=staging
) > "$PROJECT_ROOT_PATH/environments/staging/common.properties" 

test -f "$PROJECT_ROOT_PATH/environments/staging/gcloud-configuration.properties" || (
  echo core/project=staging-medshr-net
  echo compute/zone=europe-west1-b
  echo container/cluster=staging-medshr-net
) > "$PROJECT_ROOT_PATH/environments/staging/gcloud-configuration.properties" 

test -L "$PROJECT_ROOT_PATH/environments/current" || (
  ln -s "$PROJECT_ROOT_PATH/environments/local" "$PROJECT_ROOT_PATH/environments/current" 
)

. "$HERE/_lib/log.inc.sh"
. "$HERE/_lib/require.inc.sh"

# TODO: check for GPG key, check that it's registered with blackbox otherwise send it to JV

BLACKBOX_DECRYPT=$(require blackbox_decrypt_all_files)
#"$BLACKBOX_DECRYPT"

# Fetch code repositories

COMPOSER=$(require composer composer.phar)
NPM=$(require npm)
YARN=$(require yarn)

# fetch backend code if necessary
#
test -d "$PROJECT_ROOT_PATH/code/backend" || (
  info "Cloning backend source repo to code/backend"
  git clone --recursive git@code.medshr.org:backend/medshr.net "$PROJECT_ROOT_PATH/code/backend"
  command cd "$PROJECT_ROOT_PATH/code/backend"
  $COMPOSER install
  $YARN install
  $NPM run bower install
  ./gulp scripts styles
)

# fetch frontend code if necessary
#
test -d "$PROJECT_ROOT_PATH/code/frontend" || (
  info "Cloning frontend source repo to code/frontend"
  git clone --recursive git@code.medshr.org:frontend/medshr.net "$PROJECT_ROOT_PATH/code/frontend"
  command cd "$PROJECT_ROOT_PATH/code/frontend"
  $YARN install
  $NPM run build
)

# fetch newsletter code if necessary
#
test -d "$PROJECT_ROOT_PATH/containers/newsletter" || (
  info "Cloning newsletter source repo to containers/newsletter"
  git clone --recursive git@code.medshr.org:backend/newsletter.git "$PROJECT_ROOT_PATH/containers/newsletter"
)

# fetch dashboard code if necessary
#
test -d "$PROJECT_ROOT_PATH/code/dashboard" || (
  info "Cloning dashboard source repo to code/dashboard"
  git clone --recursive git@code.medshr.org:frontend/dashboard "$PROJECT_ROOT_PATH/code/dashboard"
  command cd "$PROJECT_ROOT_PATH/code/dashboard"
  $YARN install
  $NPM run build
)


BOOT_FILE="$(dirname "$BASH_SOURCE")/_setup-dev-environment-shell.inc.sh"

bash --rcfile <(echo "test -f /etc/profile && . /etc/profile ; test -f ~/.bash_profile && . ~/.bash_profile ; . $BOOT_FILE")

