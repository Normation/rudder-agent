_global() {
  if [ $COMP_CWORD -ge 1 ]; then
    case ${COMP_WORDS[1]} in
      package)
        if declare -f _rudderpkg > /dev/null; then
          _rudderpkg
        else
          _rudder
        fi
      ;;
      *)
        _rudder
      ;;
    esac
  fi
}
_rudder() {
  local cur="$2"
  local prev="$3"
  local obj cmd base opts

  base="/opt/rudder/share/commands"
  # base objects: agent server remote ...
  obj=$(cd ${base} && ls -1 | cut -f 1 -d "-" | sort -u)
  if [ "${COMP_CWORD}" = "1" ]
  then
    # first level -> base objects
    COMPREPLY=( $(compgen -W "help ${obj}" -- "${cur}") )
  elif [ "${COMP_CWORD}" = "2" ]
  then
    # second level -> commands
    cmd=$(cd ${base} && ls -1 | grep "^${COMP_WORDS[1]}" | cut -f 2- -d "-")
    COMPREPLY=( $(compgen -W "help ${cmd}" -- "${cur}") )
  else
    # other level -> options
    opts=$(grep '# @man \*-.\*:' "${base}/${COMP_WORDS[1]}-${COMP_WORDS[2]}" | sed -e 's/# @man \*\([^*]*\)\*.*/\1/')
    COMPREPLY=( $(compgen -W "help ${opts}" -- "${cur}") )
  fi
} && complete -F _global rudder
