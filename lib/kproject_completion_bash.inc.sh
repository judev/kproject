# bash completion for kproject                                 -*- shell-script -*-

__debug()
{
  if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
    echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
  fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__my_init_completion()
{
  COMPREPLY=()
  _get_comp_words_by_ref "$@" cur prev words cword
}

__index_of_word()
{
  local w word=$1
  shift
  index=0
  for w in "$@"; do
    [[ $w = "$word" ]] && return
    index=$((index+1))
  done
  index=-1
}

__contains_word()
{
  local w word=$1; shift
  for w in "$@"; do
    [[ $w = "$word" ]] && return
  done
  return 1
}

__kproject_handle_reply()
{
  __debug "${FUNCNAME[0]}"
  case $cur in
    -*)
      if [[ $(type -t compopt) = "builtin" ]]; then
        compopt -o nospace
      fi
      local allflags
      if [ ${#must_have_one_flag[@]} -ne 0 ]; then
        allflags=("${must_have_one_flag[@]}")
      else
        allflags=("${flags[*]} ${two_word_flags[*]}")
      fi
      COMPREPLY=( $(compgen -W "${allflags[*]}" -- "$cur") )
      if [[ $(type -t compopt) = "builtin" ]]; then
        [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
      fi

      # complete after --flag=abc
      if [[ $cur == *=* ]]; then
        if [[ $(type -t compopt) = "builtin" ]]; then
          compopt +o nospace
        fi

        local index flag
        flag="${cur%%=*}"
        __index_of_word "${flag}" "${flags_with_completion[@]}"
        if [[ ${index} -ge 0 ]]; then
          COMPREPLY=()
          PREFIX=""
          cur="${cur#*=}"
          ${flags_completion[${index}]}
          if [ -n "${ZSH_VERSION}" ]; then
            # zfs completion needs --flag= prefix
            eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
          fi
        fi
      fi
      return 0;
      ;;
  esac

  # check if we are handling a flag with special work handling
  local index
  __index_of_word "${prev}" "${flags_with_completion[@]}"
  if [[ ${index} -ge 0 ]]; then
    ${flags_completion[${index}]}
    return
  fi

  # we are parsing a flag and don't have a special handler, no completion
  if [[ ${cur} != "${words[cword]}" ]]; then
    return
  fi

  local completions
  completions=("${commands[@]}")
  if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
    completions=("${must_have_one_noun[@]}")
  fi
  if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
    completions+=("${must_have_one_flag[@]}")
  fi
  COMPREPLY=( $(compgen -W "${completions[*]}" -- "$cur") )

  if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
    COMPREPLY=( $(compgen -W "${noun_aliases[*]}" -- "$cur") )
  fi

  if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
    declare -F __kproject_custom_func >/dev/null && __kproject_custom_func
  fi

  __ltrim_colon_completions "$cur"
}

# The arguments should be in the form "ext1|ext2|extn"
__kproject_handle_filename_extension_flag()
{
  local ext="$1"
  _filedir "@(${ext})"
}

__kproject_handle_subdirs_in_dir_flag()
{
  local dir="$1"
  pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1
}

__kproject_handle_flag()
{
  __debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

  # if a command required a flag, and we found it, unset must_have_one_flag()
  local flagname=${words[c]}
  local flagvalue
  # if the word contained an =
  if [[ ${words[c]} == *"="* ]]; then
    flagvalue=${flagname#*=} # take in as flagvalue after the =
    flagname=${flagname%%=*} # strip everything after the =
    flagname="${flagname}=" # but put the = back
  fi
  __debug "${FUNCNAME[0]}: looking for ${flagname}"
  if __contains_word "${flagname}" "${must_have_one_flag[@]}"; then
    must_have_one_flag=()
  fi

  # if you set a flag which only applies to this command, don't show subcommands
  if __contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
    commands=()
  fi

  # keep flag value with flagname as flaghash
  if [ -n "${flagvalue}" ] ; then
    flaghash[${flagname}]=${flagvalue}
  elif [ -n "${words[ $((c+1)) ]}" ] ; then
    flaghash[${flagname}]=${words[ $((c+1)) ]}
  else
    flaghash[${flagname}]="true" # pad "true" for bool flag
  fi

  # skip the argument to a two word flag
  if __contains_word "${words[c]}" "${two_word_flags[@]}"; then
    c=$((c+1))
    # if we are looking for a flags value, don't show commands
    if [[ $c -eq $cword ]]; then
      commands=()
    fi
  fi

  c=$((c+1))

}

__kproject_handle_noun()
{
  __debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

  if __contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
    must_have_one_noun=()
  elif __contains_word "${words[c]}" "${noun_aliases[@]}"; then
    must_have_one_noun=()
  fi

  nouns+=("${words[c]}")
  c=$((c+1))
}

__kproject_handle_command()
{
  __debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

  local next_command
  if [[ -n ${last_command} ]]; then
    next_command="_${last_command}_${words[c]//:/__}"
  else
    if [[ $c -eq 0 ]]; then
      next_command="_$(basename "${words[c]//:/__}")"
    else
      next_command="_${words[c]//:/__}"
    fi
  fi
  c=$((c+1))
  __debug "${FUNCNAME[0]}: looking for ${next_command}"
  if declare -F $next_command >/dev/null
  then
    $next_command
  else
    cmd=$(echo $(sed 's/_kproject_//g' <<<"$next_command") | tr '_' '/' )
    dir=$(dirname "$(which kproject)")/commands/$cmd
    if [ -d "$dir" ]
    then
      last_command=$(sed 's/^_//' <<<"$next_command")
      if [ -x "$dir/completions" ]
      then
        completion_script="$dir/completions"
      fi
      __kproject_handle_dir "$dir"
    fi
  fi
}

__kproject_handle_word()
{
  if [[ $c -ge $cword ]]; then
    __kproject_handle_reply
    return
  fi
  __debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
  if [[ "${words[c]}" == -* ]]; then
    __kproject_handle_flag
  elif __contains_word "${words[c]}" "${commands[@]}"; then
    __kproject_handle_command
  elif [[ $c -eq 0 ]] && __contains_word "$(basename "${words[c]}")" "${commands[@]}"; then
    __kproject_handle_command
  else
    __kproject_handle_noun
  fi
  __kproject_handle_word
}

__kproject_get_config()
{
  local out
  if out=$(kproject env list | awk '{print $1}' 2>/dev/null); then
    COMPREPLY=( $( compgen -W "${out[*]}" -- "$cur" ) )
  fi
}

__kproject_custom_func() {
  local out
  if [ -x "$completion_script" ]
  then
    if out=$("$completion_script" 2>/dev/null); then
      COMPREPLY=( $( compgen -W "${out[*]}" -- "$cur" ) )
    fi
    return
  elif [ -r "$completion_script" ]
  then
    if out=$(cat "$completion_script"); then
      COMPREPLY=( $( compgen -W "${out[*]}" -- "$cur" ) )
    fi
    return
  fi
  case ${last_command} in
    kproject_config_use )
      __kproject_get_config
      return
      ;;
    *)
      ;;
  esac
}

_kproject_completion()
{
  last_command="kproject_completion"
  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  must_have_one_noun+=("bash")
  # must_have_one_noun+=("zsh")
  noun_aliases=()
}


_kproject_config_list()
{
  last_command="kproject_config_list"
  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  noun_aliases=()
}

_kproject_config_use()
{
  last_command="kproject_config_use"
  commands=()

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  noun_aliases=()
}

_kproject_config()
{
  last_command="kproject_config"
  commands=()
  commands+=("list")
  commands+=("use")

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  noun_aliases=()
}

__kproject_handle_dir()
{
  commands=()
  dir=$1
  for name in $(ls -1 "$dir")
  do
    if [ -d "$dir/$name" ]
    then
      commands+=("$name")
    fi
  done

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  noun_aliases=()
}

_kproject()
{
  last_command="kproject"
  commands=()
  commands+=("env")
  commands+=("exec")
  commands+=("completion")
  dir=$(dirname "$(which kproject)")/commands
  for name in $(ls -1 "$dir")
  do
    if [ -d "$dir/$name" ]
    then
      commands+=("$name")
    fi
  done

  flags=()
  two_word_flags=()
  local_nonpersistent_flags=()
  flags_with_completion=()
  flags_completion=()

  must_have_one_flag=()
  must_have_one_noun=()
  noun_aliases=()
}

__start_kproject()
{
  local cur prev words cword
  declare -A flaghash 2>/dev/null || :
  if declare -F _init_completion >/dev/null 2>&1; then
    _init_completion -s || return
  else
    __my_init_completion -n "=" || return
  fi

  local c=0
  local flags=()
  local two_word_flags=()
  local local_nonpersistent_flags=()
  local flags_with_completion=()
  local flags_completion=()
  local commands=("kproject")
  local must_have_one_flag=()
  local must_have_one_noun=()
  local last_command
  local completion_script
  local nouns=()

  __kproject_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
  complete -o default -F __start_kproject kproject
else
  complete -o default -o nospace -F __start_kproject kproject
fi

# ex: ts=4 sw=4 et filetype=sh
