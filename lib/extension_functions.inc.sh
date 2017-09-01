
__extension_group() {
  local group=$1
  if [ "$group" == "exec" ]
  then
    echo 'scripts'
  else
    echo "$group"
  fi
}

__extension_root() {
  local group=$(__extension_group "$1")
  if [ -d "$(dirname "$BASH_SOURCE")/../commands/$group" ]
  then
    echo "$(dirname "$BASH_SOURCE")/../commands/$group"
  else
    echo "$PROJECT_ROOT_PATH/$group"
  fi
}

extension_list() {
  local group=$(__extension_group "$1")
  local path=$(__extension_root "$group")

  for command in $(find "$path" -type f -name run | sort)
  do
    let len="2 + ${#path}"
    echo $(dirname "$command") | tail -c+$len #| tr '/' ' '
  done
}

extension_help() {
  local group=$(__extension_group "$1")
  local name=$2
  local path=$(__extension_root "$group")"/$name/help"
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

extension_call() {

  local group=$(__extension_group "$1")
  shift

  local path=$(__extension_root "$group")

  while true
  do
    name=$1
    if [ -n "$name" ] && [ -d "$path/$name" ]
    then
      path="$path/$name"
    elif [ -f "$path/run" ]
    then
      (
        config_export
        "$path/run" $@
      )
      break
    else
      echo "Not found $path/$name" 1>&2
      return 1
    fi
    shift
  done

}

