# This file provide helpers to make API call from Rudder commands
API_URL="https://127.0.0.1/rudder"
TECHNIQUES_DIRECTORY="${CONFIGURATION_DIRECTORY}/technique"

DOWNLOAD_COMMAND="curl --silent --show-error --insecure --location --proxy '' --globoff"
HEADER_OPT="--header"

# This functions tests if the API call returns "OK"
simple_api_call() {
  url="$1"
  action="$2"
  display_command="$3"
  expected="$4"
  curl_opt="$5"
  curl_command="${DOWNLOAD_COMMAND} ${curl_opt} \"${url}\""
  if ${display_command};
  then
    printf "${WHITE}${curl_command}${NORMAL}\n"
  fi
  result=`eval ${DOWNLOAD_COMMAND} \"${url}\"`
  code=$?
  if [ ${code} -eq 0 ] && [ "${result}" = "${expected}" ]
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
    printf "${RED}A token is mandatory to query the server${NORMAL}\n" >&2
    exit 1
  fi

  eval ${DOWNLOAD_COMMAND} ${HEADER_OPT} "\"X-API-Token: ${token}\"" ${HEADER_OPT} "\"Content-Type: application/json;charset=utf-8\"" ${HEADER_OPT} "\"X-API-Version: latest\"" \"${url}${api}\"

}

# This function makes an API call and will add the filter param after the bash call to the api. It may be useful when passing extra curl options.
# Also if display_command is set to "true", the executed command will be printed
filtered_api_call() {
  url="$1"
  token="$2"
  action="$3"
  filter="$4"
  display_command="$5"
  curl_command="${DOWNLOAD_COMMAND} --header \"X-API-Token: ${token}\" --request ${action} \"${url}\" ${filter}"
  if ${display_command};
  then
    printf "${WHITE}${curl_command}${NORMAL}\n\n" >&2
  fi
  eval ${curl_command}
}

