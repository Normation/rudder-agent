# This file provide helpers to make API call from Rudder commands

. "${BASEDIR}/../lib/common.sh"

if type curl >/dev/null 2>/dev/null
then
  DOWNLOAD_COMMAND="curl -sS -k -L"
else
  DOWNLOAD_COMMAND="wget -q --no-check-certificate -O -"
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
  result=`eval ${curl_command}`
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
