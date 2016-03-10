
. "${BASEDIR}/../lib/common.sh"

PRETTY_FILTER="${BASEDIR}/../lib/reports.awk"

BUNDLE=""
CLASS=""
VERBOSITY=""
DEBUG_CLASS="-D debug"
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

UUID=$(cat /opt/rudder/etc/uuid.hive 2>/dev/null)
[ $? -ne 0 ] && UUID="Not yet configured"

VERSION=`"${BASEDIR}/agent-version"`

PRETTY="awk -v info=\"\${DISPLAY_INFO}\" -v full_strings=\"\${FULL_STRINGS}\" -v summary_only=\"\${SUMMARY_ONLY}\" -v quiet=\"\${QUIET}\" -v multiline=\"\${MULTILINE}\" \
            -v green=\"\${GREEN}\" -v darkgreen=\"\${DARKGREEN}\" -v red=\"\${RED}\" -v yellow=\"\${YELLOW}\" -v magenta=\"\${MAGENTA}\" -v normal=\"\${NORMAL}\" -v white=\"\${WHITE}\" -v cyan=\"\${CYAN}\" \
            -f ${PRETTY_FILTER}"
