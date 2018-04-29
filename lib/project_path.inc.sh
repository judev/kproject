
PATH="$KPROJECT_PATH/3rdparty/blackbox/bin":$PATH

for root_path in "$KPROJECT_PATH" "$PROJECT_ROOT_PATH"
do
  PATH="$root_path/bin/xplatform":$PATH

  if [ "Darwin" = "$(uname)" ]
  then

    PATH="$root_path/bin/osx":$PATH

  elif [ "Linux" = "$(uname)" ]
  then

    PATH="$root_path/bin/linux-x86_64":$PATH

  else

    echo "System '$(uname)' not currently supported" >&2
    exit 1

  fi

  PATH="$root_path/bin":$PATH
done

