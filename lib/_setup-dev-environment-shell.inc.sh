
HERE=$(dirname "$BASH_SOURCE")
KPROJECT_ROOT_PATH=$(command cd "$HERE"/..; pwd)

. $HERE/config_functions.inc.sh
. $HERE/log.inc.sh
. $HERE/ps1_functions.inc.sh

. $HERE/project_path.inc.sh

export PATH="$KPROJECT_ROOT_PATH":$PATH

config_init "$PROJECT_ROOT_PATH"
ps1_set --prompt $

export MINIKUBE

command . <(kubectl completion bash)
command . <(minikube completion bash)
command . <(kproject completion bash)

GSED="$(which gsed)"
if [ -x "$GSED" ]
then
  SED=gsed
else
  SED=sed
fi
export SED

