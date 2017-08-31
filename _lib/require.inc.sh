
function require() {
  for name in $*
  do
    path=$(which "$name")
    if [ -x "$path" ]
    then
      echo "$path"
      return
    fi
  done
  error "Couldn't find $(echo $* | sed 's/ / or /g')" >&2
  exit 1
}

