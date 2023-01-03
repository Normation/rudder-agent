# This file provide helpers to make API call from Rudder commands
API_URL="http://127.0.0.1:8080/rudder"

DOWNLOAD_COMMAND="curl --silent --show-error ${CERTIFICATE_OPTION} --location --proxy '' --globoff"

# This functions tests if the API call return value
# - url: full url
# - action_info: text describing action performed
# - display_command: true for debug info, false otherwise
# - expected: expected output result
# - curl_opt: extra curl options
checked_api_call() {
  url="$1"
  action_info="$2"
  display_command="$3"
  expected="$4"
  curl_opt="$5"
  curl_command="${DOWNLOAD_COMMAND} ${curl_opt} \"${url}\""
  if ${display_command};
  then
    printf "${WHITE}${curl_command}${NORMAL}\n"
  fi
  result=`eval ${curl_command}`
  code=$?
  if [ ${code} -eq 0 ] && [ "${result}" = "${expected}" ]
  then
    printf "${GREEN}ok${NORMAL}: ${action_info}.\n"
  else
    printf "${RED}error${NORMAL}: Could not ${action_info}\n"
    echo "${result}"
    exit 1
  fi
}

# This function makes an API call to the webapp
# - url: full url
# - action: http verb (GET, POST ...)
# - curl_opt: extra curl options
# - display_command: true for debug info, false otherwise
rudder_api_call() {
  api="$1"
  action="$2"
  curl_opt="$3"
  display_command="$4"
  curl_command="${DOWNLOAD_COMMAND} --header \"X-API-Token: ${TOKEN}\" --header \"Content-Type: application/json\" --request ${action} \"${API_URL}/api/latest${api}\" ${curl_opt}"
  if ${display_command};
  then
    printf "${WHITE}${curl_command}${NORMAL}\n\n" >&2
  fi
  eval ${curl_command}
}

