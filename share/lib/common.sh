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
    NORMAL="\\033[0;39m"
else
    clear_colors
fi

# Information extracted from the policies
RUDDER_JSON="${RUDDER_VAR}/cfengine-community/inputs/rudder.json"
PROMISES_CF="${RUDDER_VAR}/cfengine-community/inputs/promises.cf"

if [ -f "${RUDDER_JSON}" ]
then
  RUDDER_REPORT_MODE=$(grep 'RUDDER_REPORT_MODE' "${RUDDER_JSON}" | sed 's/.*"RUDDER_REPORT_MODE":"\(.*\)",.*/\1/')
elif [ -f "${PROMISES_CF}" ]
  # To be compatible with old promises. This should be removed once rudder.json is everywhere.
  RUDDER_REPORT_MODE=$(grep -E '"changes_only" *expression' "${PROMISES_CF}" | sed 's/.*strcmp("\(.*\)", "changes-only".*/\1/')
fi

