
PRETTY_FILTER="${BASEDIR}/../lib/reports.awk"

BUNDLE=""
CLASS=""
VERBOSITY=""
# Use multiline formatting
MULTILINE=0
# Display logs between Rudder reports
DISPLAY_INFO=0
# Only display a summary at the end of the run, keep the logs unmodified
SUMMARY_ONLY=0
# Only display errors
QUIET=0
# Display full strings
FULL_STRINGS=0
# Prefix lines with hostname
MULTIHOST=0

UUID=$(cat /opt/rudder/etc/uuid.hive 2>/dev/null)
[ $? -ne 0 ] && UUID="Not yet configured"

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

VERSION=`${RUDDER_BIN} agent version`
# Some awk version crash miserably when fflush is not defined
# Since there is no way to detect it within awk, detect it here and pass it a parameter
AWK_FFLUSH=`awk 'BEGIN{fflush();}' /dev/null 2>/dev/null && echo OK`
if [ `uname -s 2>/dev/null` = 'AIX' ]
then
  AWK_OPTS="-u"
fi

PRETTY="awk -v info=\"\${DISPLAY_INFO}\" -v full_strings=\"\${FULL_STRINGS}\" -v summary_only=\"\${SUMMARY_ONLY}\" -v quiet=\"\${QUIET}\" -v multiline=\"\${MULTILINE}\" -v multihost=\"\${MULTIHOST}\" \
            -v green=\"\${GREEN}\" -v darkgreen=\"\${DARKGREEN}\" -v red=\"\${RED}\" -v yellow=\"\${YELLOW}\" -v magenta=\"\${MAGENTA}\" -v normal=\"\${NORMAL}\" -v white=\"\${WHITE}\" -v cyan=\"\${CYAN}\" \
            -v dblue=\"\${DBLUE}\" -v dgreen=\"\${DGREEN}\" -v has_fflush=\"\${AWK_FFLUSH}\" ${AWK_OPTS} -f ${PRETTY_FILTER}"
