# Paths
RUDDER_VAR="/var/rudder"
RUDDER_DIR="/opt/rudder"
RUDDER_JSON="${RUDDER_VAR}/cfengine-community/inputs/rudder.json"
SERVER_HASH_FILE="${RUDDER_VAR}/lib/ssl/policy_server_hash"
CFE_SERVER_HASH_FILE="${RUDDER_VAR}/cfengine-community/ppkeys/policy_server_hash"
AGENT_CONFIGURATION="${RUDDER_DIR}/etc/agent.conf"

# Standard classes for verbosity
DEBUG_CLASS="-D trace"
VERBOSE_CLASS="-D debug"
INFO_CLASS="-D info"

# Reset colors
clear_colors() {
    COLOR=""
    GREEN=""
    DARKGREEN=""
    RED=""
    BLUE=""
    PINK=""
    WHITE=""
    WHITELIGHT=""
    MAGENTA=""
    YELLOW=""
    CYAN=""
    NORMAL=""
    DBLUE=""
    DGREEN=""
}

# Command used to start/stop/restart a service
service_action() {
  service="$1"
  action="$2"

  if systemctl list-units --type service --all ${service}.service 2>&1 | grep -q '\b1 loaded units listed'; then
    CMD="systemctl ${action} ${service}"
    if [ "${service}" = "rudder-agent" ] && [ "${QUIET}" != "true" ]; then
      # Display information about subservices
      SUBSERVICES=""
      for subservice in "rudder-cf-serverd" "rudder-cf-execd"; do
        status="disabled"
        systemctl -q is-enabled "${subservice}" && status="enabled" || true
        echo "${subservice}: ${status}"
      done
    fi
  elif [ -x /usr/sbin/service ]; then
    CMD="/usr/sbin/service ${service} ${action}"
  elif [ -x /etc/init.d/${service} ]; then
    CMD="/etc/init.d/${service} ${action}"
  elif [ "${action}" = "start" ] && [ -x /usr/bin/startsrc ]; then
    CMD="startsrc -s ${service}"
  elif [ "${action}" = "stop" ] && [ -x /usr/bin/stopsrc ]; then
    CMD="stopsrc -s ${service}"
  fi

  if [ -n "${CMD}" ]
  then
    $CMD
    RET="$?"
    if [ "${action}" = "start" ] || [ "${action}" = "stop" ]; then
      if [ $RET -eq 0 ]
      then
        [ "$QUIET" = false ] && printf "${GREEN}ok${NORMAL}: ${action} service ${service} succeeded\n"
      else
        [ "$QUIET" = false ] && printf "${RED}error${NORMAL}: ${action} service ${service} failed\n"
      fi
    fi
    return $RET
  else
    printf "${RED}error${NORMAL}: Don't know how to ${action} ${service}.\n" 1>&2
    return 1
  fi
}

init_commands() {
  ## If we are on AIX, use alternative commands and options
  if [ "${OS_FAMILY}" = "AIX" ]; then
    CP_A="cp -hpPr"
  elif [ "${OS_FAMILY}" = "SunOS" ]; then
    CP_A="cp -pPr"
  else
    CP_A="cp -a"
  fi

  # Detect the correct ps tool to use
  ns=$(ps --no-header -o utsns --pid $$ 2>/dev/null || true)
  if [ -d "/proc/bc" ] && [ -e "/proc/bc/0" ]; then # we have openvz
    if [ -e /bin/vzps ]; then # we have vzps
      PS_COMMAND="/bin/vzps -E 0"
    else # use rudder provided vzps
      PS_COMMAND="${RUDDER_DIR}/bin/vzps.py -E 0"
    fi
  elif [ -n "${ns}" ]; then # we have namespaces
    # the sed is here to prepend a fake user field that is removed by the -o option (it is never used)
    PS_COMMAND="eval ps --no-header -e -O utsns | egrep '^[[:space:]]*[[:digit:]]*[[:space:]]+${ns}' | sed 's/^/user /'"
  else # standard unix
    PS_COMMAND="ps -ef"
  fi
}

# To be used instead of the hostame command
get_hostname() {
  # Try to mimic CFEngine behavior, at least on Linux
  # Necessary for log files names
  OS=$(uname -s)
  HOSTNAME=$(uname -n)

  if [ "${OS}" = "Linux" ] && type hostname >/dev/null 2>/dev/null; then
     fqname=$(hostname --fqdn)
     if [ $? -eq 0 ] && echo "${fqname}" | grep -q '.' 2>/dev/null; then
       HOSTNAME="${fqname}"
    fi
  fi
  echo "${HOSTNAME}"
}

# Check for jq presence
need_jq() {
  if ! type jq >/dev/null 2>/dev/null
  then
    printf "${RED}ERROR: 'jq' must be installed to query hosts from server${NORMAL}\n"
    exit 2
  fi
}

# get a single entry from rudder.json
rudder_json_value() {
  grep "$1" "${RUDDER_JSON}" | sed 's/.*"'$1'" *: *"\(.*\)",.*/\1/'
}

# stat -c %y compatible with other unices
modification_time() {
  if [ "${OS_FAMILY}" = "AIX" ]; then
    # be careful, there is a litteral tab below
    LANG=C istat "$1" | sed -n '/Last modified/s/Last modified:[ 	]*//p'
  elif [ "${OS_FAMILY}" = "Darwin" ]; then
    stat -f "%Sm" "$1"
  else
    stat -c "%y" "$1"
  fi
}

# Check that a bootstrap is necessary
bootstrap_check() {
  # create folder if it doesn't exist
  if [ ! -d "${RUDDER_VAR}/cfengine-community/inputs" ]
  then
    mkdir -p ${RUDDER_VAR}/cfengine-community/inputs
  fi

  if [ "$(ls -A ${RUDDER_VAR}/cfengine-community/inputs)" = "" ]
  then
    cp ${RUDDER_DIR}/share/bootstrap-promises/* ${RUDDER_VAR}/cfengine-community/inputs/
    rudder agent update
  fi
}

# Compare major rudder versions, return 255,0,1
# empty value < anything
major_compare() {
  [ "$1" = "" ] && return 255
  [ "$2" = "" ] && return 1
  major_a1=$(echo "$1" | cut -d. -f1)
  major_a2=$(echo "$1" | cut -d. -f2)
  major_b1=$(echo "$2" | cut -d. -f1)
  major_b2=$(echo "$2" | cut -d. -f2)
  [ "${major_a1}" -lt "${major_b1}" ] && return 255
  [ "${major_a1}" -gt "${major_b1}" ] && return 1
  [ "${major_a2}" -lt "${major_b2}" ] && return 255
  [ "${major_a2}" -gt "${major_b2}" ] && return 1
  return 0
}

# Read one line of directives.csv
parse_directive() {
  IFS=, read _uuid _mode _generation _hooks _technique _technique_version _is_system _name || return 1
  uuid=$(echo "${_uuid}"| sed 's/^"\(.*\)"$/\1/')
  mode=$(echo "${_mode}"| sed 's/^"\(.*\)"$/\1/')
  generation=$(echo "${_generation}"| sed 's/^"\(.*\)"$/\1/')
  hooks=$(echo "${_hooks}"| sed 's/^"\(.*\)"$/\1/')
  technique=$(echo "${_technique}"| sed 's/^"\(.*\)"$/\1/')
  technique_version=$(echo "${_technique_version}"| sed 's/^"\(.*\)"$/\1/')
  is_system=$(echo "${_is_system}"| sed 's/^"\(.*\)"$/\1/')
  name=$(echo "${_name}"| sed 's/^"\(.*\)"$/\1/')
}

# read one key of agent.conf if file exists
agent_conf() {
  if [ -f ${AGENT_CONFIGURATION} ]; then
    key="$1"
    sed -n "/^${key} *=/s/^${key} *= *//p" "${AGENT_CONFIGURATION}"
  fi
}

# get port used to talk https with the server
get_https_port() {
  # get port from configuration
  PORT=$(agent_conf https_port)
  # if not trust the server on this
  if [ "${PORT}" = "" ]; then
    PORT=$(rudder_json_value 'HTTPS_POLICY_DISTRIBUTION_PORT')
  fi
  # else default to 443
  if [ "${PORT}" != "" ]; then
    PORT=":${PORT}"
  fi
  echo "${PORT}"
}

# Colors configuration (enable colors only if stdout is a terminal)
if [ -t 1 ]; then
    COLOR="-Calways"
    GREEN="\\033[1;32m"
    DARKGREEN="\\033[0;32m"
    RED="\\033[1;31m"
    BLUE="\\033[1;34m"
    TPINK="\\033[1;35m"
    WHITE="\\033[0;02m"
    WHITELIGHT="\\033[1;08m"
    MAGENTA="\\033[1;35m"
    YELLOW="\\033[1;33m"
    CYAN="\\033[1;36m"
    NORMAL="\\033[0;39m\\033[0;49m"
    DBLUE="\\033[0;34m"
    DGREEN="\\033[0;32m"
else
    clear_colors
fi

# Information extracted from the policies
if [ -f "${RUDDER_JSON}" ]; then
  RUDDER_REPORT_MODE=$(rudder_json_value 'RUDDER_REPORT_MODE')
  AGENT_RUN_INTERVAL=$(rudder_json_value 'AGENT_RUN_INTERVAL')
  RUDDER_NODE_CONFIG_ID=$(rudder_json_value 'RUDDER_NODE_CONFIG_ID')
  RUDDER_SYSLOG_PROTOCOL=$(rudder_json_value 'RUDDER_SYSLOG_PROTOCOL')
  RUDDER_VERIFY_CERTIFICATES=$(rudder_json_value 'RUDDER_VERIFY_CERTIFICATES')
  RUDDER_NODE_KIND=$(rudder_json_value 'RUDDER_NODE_KIND')
fi
# run interval default value
[ "${AGENT_RUN_INTERVAL}" = "" ] && AGENT_RUN_INTERVAL=5

# Rudder uuid
UUID=$(cat ${RUDDER_DIR}/etc/uuid.hive 2>/dev/null)
[ $? -ne 0 ] && UUID="Not yet configured"

if [ "${RUDDER_REPORT_MODE}" = "changes-only" ] || [ "${RUDDER_REPORT_MODE}" = "reports-disabled" ]
then
  VERBOSITY=""
  FULL_COMPLIANCE=0
else
  # info as minimal verbosity level for complete reporting
  VERBOSITY="-I ${INFO_CLASS}"
  FULL_COMPLIANCE=1
fi

if [ "${RUDDER_VERIFY_CERTIFICATES}" = "true" ]
then
  CERTIFICATE_OPTION=""
else
  CERTIFICATE_OPTION="--insecure"
fi

TOKEN=""
if [ -f ${RUDDER_VAR}/run/api-token ]
then
  TOKEN=$(cat ${RUDDER_VAR}/run/api-token 2>/dev/null)
fi

# detect OS family
OS_FAMILY=`uname -s`

