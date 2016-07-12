# This file provide helpers to make API call from Rudder commands

. "${BASEDIR}/../lib/common.sh"

if type curl >/dev/null 2>/dev/null
then
  DOWNLOAD_COMMAND="curl --silent --show-error --insecure --location --proxy ''"
  HEADER_OPT="--header"
else
  DOWNLOAD_COMMAND="wget --quiet --no-check-certificate --no-proxy -O -"
  HEADER_OPT="--header"
fi

# This functions tests if the API call returns "OK"
simple_api_call() {
  url="$1"
  action="$2"
  display_command="$3"
  curl_command="${DOWNLOAD_COMMAND} \"${url}\""
  if ${display_command};
  then
    printf "${WHITE}${curl_command}${NORMAL}\n"
  fi
  result=`eval ${DOWNLOAD_COMMAND} \"${url}\"`
  code=$?
  if [ ${code} -eq 0 ] && [ "${result}" = "OK" ]
  then
    printf "${GREEN}ok${NORMAL}: ${action}.\n"
  else
    printf "${RED}error${NORMAL}: Could not ${action}\n"
    echo "${result}"
    exit 1
  fi
}

# retrieve one entry from ~/.rudder
_get_conf() {
  conf="$1"
  name="$2"
  conffile=~/.rudder
  [ -f "${conffile}" ] || return
  [ -z "${conf}" ] && conf=".*"
  # extract inifile section | extract value
  sed -n "/^\\[${conf}\\]$/,/^\\[.*\\]$/p" "${conffile}" | sed -n "/^${name} *= */s/^${name} *= *//p"
}

# This function calls the api with a token
full_api_call() {
  api="$1"
  url="$2"
  conf="$3"
  token="$4"

  if [ -z "${url}" ]
  then
    url=`_get_conf "${conf}" "url"`
    if [ -z "${url}" ]
    then
      host=`cat /var/rudder/cfengine-community/policy_server.dat 2>/dev/null`
      [ -z "${host}" ] && host="localhost"
      url="https://${host}/rudder"
    fi
  fi

  [ -z "${token}" ] && token=`_get_conf "${conf}" "token"`
  if [ -z "${token}" ]
  then
    echo "A token is mandatory to query the server"
    exit 1
  fi
  eval ${DOWNLOAD_COMMAND} ${HEADER_OPT} "\"X-API-Token: ${token}\"" ${HEADER_OPT} "\"Content-Type: application/json;charset=utf-8\"" ${HEADER_OPT} "\"X-API-Version: latest\"" \"${url}${api}\"
}

