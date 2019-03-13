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

  if systemctl list-units --type service --all ${service}.service 2>&1 | grep -q "^${service}.service"; then
    CMD="systemctl ${action} ${service}"
  elif [ -x /usr/sbin/service ]; then
    CMD="service ${service} ${action}"
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
  # detect OS family
  OS_FAMILY=`uname -s`
  
  if [ "${OS_FAMILY}" = "AIX" ] || [ "${OS_FAMILY}" = "SunOS" ]; then
    CP_A="cp -hpPr"
  else
    CP_A="cp -a"
  fi

  # Detect the correct ps tool to use
  ns=$(ps --no-header -o utsns --pid $$ 2>/dev/null || true)
  if [ -d "/proc/bc" ] && [ -e "/proc/bc/0" ]; then # we have openvz
    if [ -e /bin/vzps ]; then # we have vzps
      PS_COMMAND="/bin/vzps -E 0"
    else # use rudder provided vzps
      PS_COMMAND="/opt/rudder/bin/vzps.py -E 0"
    fi
  elif [ -n "${ns}" ]; then # we have namespaces
    # the sed is here to prepend a fake user field that is removed by the -o option (it is never used)
    PS_COMMAND="eval ps --no-header -e -O utsns | grep -E '^[[:space:]]*[[:digit:]]*[[:space:]]+${ns}' | sed 's/^/user /'"
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
  
  if [ "${OS}" = "Linux" ]; then
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

# Avoid loading system librairies
if [ `uname -s 2>/dev/null` = 'AIX' ]
then
  export LIBPATH=""
fi

# Paths
RUDDER_VAR="/var/rudder"

# Standard classes for verbosity
DEBUG_CLASS="-D trace,debug,info"
VERBOSE_CLASS="-D debug,info"
INFO_CLASS="-D info"

# Information extracted from the policies
RUDDER_JSON="${RUDDER_VAR}/cfengine-community/inputs/rudder.json"
PROMISES_CF="${RUDDER_VAR}/cfengine-community/inputs/promises.cf"

if [ -f "${RUDDER_JSON}" ]; then
  RUDDER_REPORT_MODE=$(grep 'RUDDER_REPORT_MODE' "${RUDDER_JSON}" | sed 's/.*"RUDDER_REPORT_MODE":"\(.*\)",.*/\1/')
  AGENT_RUN_INTERVAL=$(grep 'AGENT_RUN_INTERVAL' "${RUDDER_JSON}" | sed 's/.*"AGENT_RUN_INTERVAL":"\(.*\)",.*/\1/')
  RUDDER_NODE_CONFIG_ID=$(grep 'RUDDER_NODE_CONFIG_ID' "${RUDDER_JSON}" | sed 's/.*"RUDDER_NODE_CONFIG_ID":"\(.*\)",.*/\1/')
fi

if [ "${RUDDER_REPORT_MODE}" = "changes-only" ] || [ "${RUDDER_REPORT_MODE}" = "reports-disabled" ]
then
  FULL_COMPLIANCE=0
else
  FULL_COMPLIANCE=1
fi
