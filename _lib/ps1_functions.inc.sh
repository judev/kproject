#!/usr/bin/env bash

#
# Source this file in your ~/.bash_profile or interactive startup file.
# This is done like so:
#
#    [[ -s "$HOME/etc/lib/ps1_functions" ]] &&
#      source "$HOME/etc/lib/ps1_functions"
#
# Then in order to set your prompt you simply do the following for example
#
# Examples:
#
#   ps1_set --prompt ∫
#
#   or
#
#   ps1_set --prompt ∴
#
# This will yield a prompt like the following, for example,
#
# 00:00:50 wayneeseguin@GeniusAir:~/projects/db0/rvm/rvm  (git:master:156d0b4)  ruby-1.8.7-p334@rvm
# ∴
#


ps1_identity()
{
  if [[ $UID -eq 0 ]]  ; then
    printf " \033[31m\\\u\033[0m"
  else
    printf " \033[32m\\\u\033[0m"
  fi

  printf "@\033[36m\\h\033[35m:\w\033[0m "

  return 0
}

ps1_git()
{
  local branch="" line="" attr=""

  shopt -s extglob # Important, for our nice matchers :)

  if ! command -v git >/dev/null 2>&1 ; then
    printf " \033[1;37m\033[41m[git not found]\033[m "
    exit 0
  fi

  # First we determine the current git branch, if any.
  while read -r line
  do
    case "${line}" in
      [[=*=]][[:space:]]*) # on linux, man 7 regex
        branch="${line/[[=*=]][[:space:]]/}"
        ;;
    esac
  done < <(git branch 2>/dev/null)

  # Now we display the branch.
  sha1=($(git log --no-color -1 2>/dev/null))
  sha1=${sha1[1]}
  sha1=${sha1:0:7}

  case ${branch} in
   production|prod) attr="1;37m\033[" ; color=41 ;; # red
   master|deploy)   color=31                     ;; # red
   stage|staging)   color=33                     ;; # yellow
   dev|development) color=34                     ;; # blue
   next)            color=36                     ;; # gray
   *)
     if [[ -n "${branch}" ]] ; then # Feature Branch :)
       color=32 # green
     else
       color=0 # reset
     fi
     ;;
  esac

  if [[ $color -gt 0 ]] ; then
    printf " \033[${attr}${color}m(git:${branch}:$sha1)\033[0m "
  fi

  return 0
}

ps1_env() {
  env=$(config_current)
  attr=""
  case ${env} in
    production|prod|live) attr="1;37m\033[" ; color=41 ;; # red
    stage|staging|qa)   color=33                       ;; # yellow
    dev|development|local) color=32                    ;; # green
    *)
      if [[ -n "${env}" ]] ; then
        color=34 # blue
      else
        color=0 # reset
      fi
      ;;
  esac

  if [[ $color -gt 0 ]] ; then
    printf " \033[${attr}${color}m[env:${env}]\033[0m "
  fi

  return 0
}

ps1_set()
{
  local prompt_char='$'
  local separator="\n"
  local env=""

  if [[ $UID -eq 0 ]] ; then
    prompt_char='#'
  fi

  while [[ $# -gt 0 ]] ; do
    token="$1" ; shift

    case "$token" in
      --trace)
        export PS4="+ \${BASH_SOURCE##} : \${FUNCNAME[0]:+\${FUNCNAME[0]}()}  \${LINENO} > "
        set -o xtrace
        ;;
      --prompt)
        prompt_char="$1"
        shift
        ;;
      --separator)
        separator="$1"
        shift
        ;;
      *)
        true # Ignore everything else.
        ;;
    esac
  done

  PS1="\D{%H:%M:%S}$(ps1_identity)\$(ps1_git)\$(ps1_env)${separator}${prompt_char} "
}

ps2_set()
{
  PS2="  \[\033[0;40m\]\[\033[0;33m\]> \[\033[1;37m\]\[\033[1m\]"
}

