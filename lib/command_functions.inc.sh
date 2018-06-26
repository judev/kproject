
__command_group() {
  local group=$1
  if [ "$group" == "exec" ]
  then
    echo 'scripts'
  else
    echo "$group"
  fi
}

__command_root() {
  local group=$(__command_group "$1")
  if [ -d "$(dirname "$BASH_SOURCE")/../commands/$group" ]
  then
    echo "$(command cd "$(dirname "$BASH_SOURCE")/../commands/$group"; pwd)"
  else
    echo "$PROJECT_ROOT_PATH/$group"
  fi
}

command_list() {
  local group=$(__command_group "$1")
  local path=$(__command_root "$group")

  if [ -d "$path" ]
  then
    for command in $(find "$path" -type f -name run | sort)
    do
      let len="2 + ${#path}"
      echo $(dirname "$command") | tail -c+$len #| tr '/' ' '
    done
  else
    echo "command_list: group $group not found" >&2
  fi
}

command_root_path() {
  local group=$(__command_group "$1")
  local path=$(__command_root "$group")

  echo $path
}

command_help() {
  local group=$(__command_group "$1")
  local name=$2
  local path=$(__command_root "$group")"/$name/help"
  if [ -x "$path" ]
  then
    (
      config_export
      "$path"
    )
  elif [ -r "$path" ]
  then
    cat "$path"
  fi
}

command_get() {
  local group=$(__command_group "$1")
  shift

  local path=$(__command_root "$group")

  while true
  do
    name=$1
    if [ -n "$name" ] && [ -d "$path/$name" ]
    then
      path="$path/$name"
    elif [ -f "$path/run" ]
    then
      echo "$path"
      break
    else
      return 1
    fi
    shift
  done
}

command_call() {
  path=$(command_get "$1")
  if [ -n "$path" ]
  then
    (
      config_export
      "$path/run" $@
    )
  else
    echo "Not found $path/$name" 1>&2
    return 1
  fi
}

