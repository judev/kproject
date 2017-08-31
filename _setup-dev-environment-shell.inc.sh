
HERE=$(dirname "$BASH_SOURCE")

. $HERE/_lib/config_functions.inc.sh
. $HERE/_lib/ps1_functions.inc.sh

export PATH="$PROJECT_ROOT_PATH/bin":$PATH

config_init "$PROJECT_ROOT_PATH"
ps1_set --prompt $

export MINIKUBE

command . <(kubectl completion bash)
command . <(minikube completion bash)
command . <(helm completion bash)
command . <(kproject completion bash)

kproject chart sync-pull -y >/dev/null 2>&1

