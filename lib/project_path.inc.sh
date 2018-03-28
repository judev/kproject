
PATH="$PROJECT_ROOT_PATH/bin/xplatform":$PATH

if [ "Darwin" = "$(uname)" ]
then

  PATH="$PROJECT_ROOT_PATH/bin/osx":$PATH

elif [ "Linux" = "$(uname)" ]
then

  PATH="$PROJECT_ROOT_PATH/bin/linux-x86_64":$PATH

else

  echo "System '$(uname)' not currently supported" >&2
  exit 1

fi

PATH="$PROJECT_ROOT_PATH/bin":$PATH

