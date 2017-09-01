

function info() {
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  YELLOW="\033[0;33m"
  NOCOLOR="\033[0m"
  printf "${GREEN}$1${NOCOLOR}\n"
}

function error() {
  RED="\033[0;31m"
  GREEN="\033[0;32m"
  YELLOW="\033[0;33m"
  NOCOLOR="\033[0m"
  printf "${RED}$1${NOCOLOR}\n"
}

function error_exit() {
  error "$*"
  exit 1
}

