#!/usr/bin/env bash

HERE=$(dirname "$BASH_SOURCE")
. $HERE/project_path.inc.sh

ERRORS=""

error() {
  echo "$*" 1>&2
  ERRORS+="$*"
}

GCLOUD=$(which gcloud)
if [ ! -x "$GCLOUD" ]
then
  error "Please install the gcloud commandline tools: https://cloud.google.com/sdk/downloads#interactive"
fi

KUBECTL=$(which kubectl)
if [ ! -x "$KUBECTL" ]
then
  error "Please install kubectl: gcloud components install kubectl"
fi

MINIKUBE=$(which minikube)
if [ ! -x "$MINIKUBE" ]
then
  error "Please install minikube: https://github.com/kubernetes/minikube/releases/latest"
fi

KONTEMPLATE=$(which kontemplate)
if [ ! -x "$KONTEMPLATE" ]
then
  error "Please install kontemplate: https://github.com/tazjin/kontemplate"
fi

GIT=$(which git)
if [ ! -x "$GIT" ]
then
  error "Please install git: https://git-scm.com/downloads"
fi

if ! git lfs >/dev/null 2>&1
then
  error "Please install git lfs: https://git-lfs.github.com/"
fi

NODE=$(which node)
if [ ! -x "$NODE" ]
then
  error "Please install node: https://nodejs.org/en/download/"
else
  NPM=$(which npm)
  if [ ! -x "$NPM" ]
  then
    error "Could not find npm - is your node install broken?"
  fi
fi

COMPOSER=$(which composer)
if [ ! -x "$COMPOSER" ]
then
  COMPOSER=$(which composer.phar)
  if [ ! -x "$COMPOSER" ]
  then
    error "Please install composer: https://getcomposer.org/download/"
  fi
fi

GPG=$(which gpg)
if [ ! -x "$GPG" ]
then
  error "Please install GPG:"
  error "  Mac: brew install gpg"
  error "  Ubuntu / Debian: apt install gnupg2"
  error "  Redhat / CentOS: yum install gnupg2"
fi

JQ=$(which jq)
if [ ! -x "$JQ" ]
then
  error "Please install jq:"
  error "  Mac: brew install jq"
  error "  Ubuntu / Debian: apt install jq"
  error "  Other: https://stedolan.github.io/jq/download/"
fi

if ! sed --version 2>&1 | grep -Fq 'GNU sed'
then

  SED=$(which gsed)
  if [ ! -x "$SED" ]
  then
    error "Please install GNU sed:"
    error "  Mac: brew install gnu-sed"
  fi

fi

BLACKBOX=$(which blackbox_decrypt_all_files)
if [ ! -x "$BLACKBOX" ]
then
  error "Please install blackbox: https://github.com/StackExchange/blackbox"
fi

if [ -z "$ERRORS" ]
then
  echo "Looks good!"
else
  exit 1
fi

