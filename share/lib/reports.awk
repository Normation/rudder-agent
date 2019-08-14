BEGIN {
  is_report = 0;
  broken_reports = 0;

  # report counters
  run_error = 0;
  audit_compliant = 0;
  enforce_compliant = 0;
  audit_error = 0;
  enforce_error = 0;
  enforce_repaired = 0;
  audit_noncompliant = 0;
  audit_notapplicable = 0;
  enforce_notapplicable = 0;

  mode_color["Audit"] = dblue;
  mode_color["Enforce"] = dgreen;
  mode_color[""] = normal;

  state_color["compliant"] = green;
  state_color["non-compliant"] = magenta;
  state_color["error"] = red;
  state_color["repaired"] = yellow;
  state_color["info"] = cyan;
  state_color["warning"] = magenta;
  state_color["n/a"] = green;

  header_printed = 0;
  end_run = 0;
  padding_dash = "--------------------------------------------------------------------------------";
  padding =      "################################################################################";
  broken_date = 0
  "date +%s -d \"2018-01-01 00:00:00+00:00\" 2>/dev/null" | getline fixed_date
  if(fixed_date != 1514764800) {
    broken_date=1
  }
  if(broken_date) {
    "date +%s" | getline starttime;
  } else {
    "date +%s.%N" | getline starttime;
  }
  # needed to be able to call the same command a second time
  close("date +%s.%N");
  # Initialize timer to allow computing time taken for parsing the policies
  timer()
}

# We need it because length() only exists in gawk
function alen (a) {
  k = 0;
  for (i in a)
    k++;
  return k;
}

function timer() {
  "date +%s.%N" | getline component_end_time;
  close("date +%s.%N");
  tmp_time = component_end_time - component_begin_time;
  component_begin_time = component_end_time;
  return tmp_time
}

function print_count_offset(offset, marker, color, count, text) {
  for (c=0; c<offset; c++) {
    printf " ";
  }
  printf "%s %s%s%s %s\n", marker, color, count, normal, text;
}

function print_report_singleline() {
  if (hostname) {
    printf "%s%-15.15s ", normal, hostname;
  }

  if (timing) {
    if (mode != "") {
      printf "%6.2fs ", component_time;
    } else {
      printf "%6.6s  ", "";
    }
  }

  if (full_strings) {
    printf "%s%-7.7s%s %s%-13.13s%s ", mode_color[mode], mode, normal, state_color[result], result, normal;
    } else {
      if (mode) {
      separator = "| ";
    } else {
      separator = "  ";
    }
    printf "%s%-1.1s%s%s%s%-13.13s%s ", mode_color[mode], mode, normal, separator, state_color[result], result, normal;
  }

  if (full_strings) {
    printf "%-25s %-25s %-18s ", technique, component, key;
  } else {
    if (length(technique) > 25) {
      printf "%-24.24s| ", technique;
    } else {
      printf "%-25.25s ", technique;
    }

    if (length(component) > 25) {
      printf "%-24.24s| ", component;
    } else {
      printf "%-25.25s ", component;
    }

    if (length(key) > 18) {
      printf "%-17.17s| ", key;
    } else {
      printf "%-18.18s ", key;
    }
  }

  printf "%s\n", message;
}

{
  #### 1/ Parse the line

  is_report = 0;

  n = split($0, r, /@@/);
  if (n) {
    # 1 is R:
    technique = r[2];
    state = r[3];
    ruleid = r[4];
    directiveid = r[5];
    # 6 is generation
    component = r[7];
    key = r[8];
    # take the rest
    rest = "";
    for(i=9;i<=n;i++) {
      rest = rest "@@" r[i];
    }

    if (match(rest, /##/)) { # match the first ##
      # date then rest
      rest = substr(rest,RSTART+RLENGTH)
      if (match(rest, /@#/)) { # match the first @#
        # node id then message
        message = substr(rest,RSTART+RLENGTH)
        # line has been parsed as a valid report
        is_report = 1;
      }
    }

    if (directive_array[directiveid] != 1)  {
      directive_array[directiveid] = 1;
    }

  }

  # get original time from report in summary mode
  if (short_summary) {
    if (!original_time) {
      if (match(r[9], /##/)) { # match the first ##
        original_time = substr(r[9],0,RSTART-1)
      }
    }
    if (!broken_date && original_time) {
      # Needed to correctly eval complete command with some versions of awk
      command = "date +%s.%N -d \"" original_time "\""
      command | getline original_time_s;
    }
  }
  
  # for raw mode
  if (summary_only && !no_report) {
    print $0;
    if (!is_report) {
      next
    }
  }

  # for formatted mode
  if (!is_report) {
    # very likely a broken report
    if (match($0, /.*R: @@/)) {
      broken_reports++;
    }

    # CFEngine error
    if (!no_report && (match($0, /^   error: /))) {
      print red $0 normal;
      next
    }

    if (info && !no_report) {
      print darkgreen $0 normal;
    }
    next
  }

  # Parse hostname
  if (match($0, /.*> ->/)) {
    hostname=substr($0, RSTART, RLENGTH-4);
  }
  
  #### 2/ Parse start and end of the run

  # Wait for the StartRun to display the config id
  if (key == "StartRun") {
    if (timing) {
      parsing_time = timer();
      printf "Parsing time: %.2fs\n", parsing_time;
    }
    printf "%s\n\n", message;
    next
  }
  if (key == "EndRun") {
    end_run = 1;
    # skip this one
    next
  }

  # New control log introduced in 4.2
  if (state == "control" && ruleid == "rudder" && directiveid == "run" )
  {
    if (component == "start")
    {
      if (timing) {
        parsing_time = timer();
        printf "Parsing time: %.2fs\n", parsing_time;
      }
      if (!short_summary) {
        printf "Start execution with config [%s]\n\n", key;
      }
      next
    }
    if (component == "end")
    {
      end_run = 1;
      # skip this one
      next
    }
  }
  
  #### 3/ Parse report mode

  if (match(state, /^result_/)) {
    mode = "Enforce";
  } else if (match(state, /^audit_/)) {
    mode = "Audit";
  } else {
    # a simple log 
    mode = "";
  }

  # Compute time
  if (mode != "" && timing) {
    component_time = timer();
  } else {
    component_time = ""
  }

  #### 4/ Check report type

  if (state == "result_success") {
    enforce_compliant++;
    if (quiet) {
      next
    }
    result = "compliant";
  } else if (state == "result_error") {
    enforce_error++;
    result = "error";
  } else if (state == "result_na") {
    enforce_notapplicable++;
    if (quiet) {
      next
    }
    result = "n/a";
  } else if (state == "result_repaired") {
    enforce_repaired++;
    result = "repaired";
  } else if (state == "log_warn") {
    result = "warning";
  } else if (state == "log_info" || state == "log_debug" || state == "log_trace" || state == "log_repaired") {
    if (!info) {
      next
    }
    result = "info";
  } else if (state == "audit_compliant") {
    audit_compliant++;
    if (quiet)
    { 
      next
    }
    result = "compliant";
  } else if (state == "audit_noncompliant") {
    audit_noncompliant++;
    result = "non-compliant";
  } else if (state == "audit_error") {
    audit_error++;
    result = "error";
  } else if (state == "audit_na") {
    audit_notapplicable++;
    if (quiet) {
      next
    }
    result = "n/a";
  } else {
    if (quiet) {
      next
    }
    result = state;
  }
  if (key == "None") { 
    # Do not display "None" keys
    key = "";
  }

  if(no_report) {
    next
  }
  #### 5/ Display reports
  { 
    if (!summary_only) {

      if (!header_printed) {
        printf "%s", white;

        header_printed = 1;
        if (multihost) {
          printf "%-15.15s ", "Hostname";
        }

        if (timing) {
          printf "%8.8s", "Time "          
        }

        if (full_strings) {
          printf "%-7.7s ", "Mode";
       	} else {
          printf "%-1.1s| ", "Mode";
       	}

       	printf "%-13.13s %-25.25s %-25.25s %-18.18s %s%s\n", "State", "Technique", "Component", "Key", "Message", normal;
      }

      print_report_singleline();

      if (has_fflush) {
        fflush();
      }
    }
  }
}
END {
  #### 6/ End of the run, time to compute result and display summary

  # Print a single line of summary
  if (short_summary) {
    if(original_time_s) {
      duration=endtime-original_time_s
    } else {
      duration=0
    }
    if(original_time) {
      printf "%s (%3.0fs) ", original_time, duration
    }
    printf "%sEnforce%s: %s%3d%s compliant, %s%3d%s repaired, %s%3d%s N/A, %s%3d%s errors  ", dgreen, normal, green, enforce_compliant, normal, yellow, enforce_repaired, normal, green, enforce_notapplicable, normal, red, enforce_error, normal
    printf "%sAudit%s: %s%3d%s compliant, %s%3d%s non-compliant, %s%3d%s N/A, %s%3d%s errors\n", dblue, normal, green, audit_compliant, normal, magenta, audit_noncompliant, normal, green, audit_notapplicable, normal, red, audit_error, normal
    exit 0
  }

  if(broken_date) {
    "date +%s" | getline endtime;
  } else {
    "date +%s.%N" | getline endtime;
  }

  # If we defined a custom bundlesequence, it is expected to not have everything
  if (partial_run) {
    printf "%s", cyan;
    printf "info     Rudder agent was run on a subset of policies - not all policies were checked";
    printf "%s\n", normal;
  }

  # Check if agent run finished correctly
  if (!end_run && full_compliance  && !partial_run) {
    run_error++;
    printf "%s", red;

    printf "error    Rudder agent was interrupted during execution by a fatal error";
    if (!info) {
      printf "\n         Run with -i to see log messages.";
    }

    printf "%s\n", normal;
  }

  # Check for unparsable reports
  if (broken_reports) {
    printf "%s", magenta;
    
    printf "warning  %d reports were not parsable.", broken_reports;
    if (!info) {
      printf "\n         Run with -i to see log messages.";
    }

    printf "%s\n", normal;
  }

  # Begin summary display
  printf "\n%s%-80.80s%s\n", white, "## Summary " padding, normal;

  audit_components = audit_compliant+audit_noncompliant+audit_error+audit_notapplicable;
  enforce_components = enforce_compliant+enforce_notapplicable+enforce_error+enforce_repaired;

  # Component count makes no sense when not in full compliance
  if (full_compliance) {
    printf "%s components verified in %s directives\n", audit_components+enforce_components, alen(directive_array);
  } else {
    printf "Not all components were displayed because we are not in full compliance mode. Please run with -g to force full compliance mode.\n";
  }

  if (enforce_components > 0) {
    print_count_offset(3, "=>", dgreen, enforce_components, "components in " dgreen "Enforce" normal " mode");

    if (enforce_compliant > 0) {
      print_count_offset(6, "->", green, enforce_compliant, "compliant");
    }
    if (enforce_repaired > 0) {
      print_count_offset(6, "->", yellow, enforce_repaired, "repaired");
    }
    if (enforce_notapplicable > 0) {
      print_count_offset(6, "->", green, enforce_notapplicable, "not-applicable");
    }
    if (enforce_error > 0) {
      print_count_offset(6, "->", red, enforce_error, "error");
    }
  }

  if (audit_components > 0) {
    print_count_offset(3, "=>", dblue, audit_components, "components in " dblue "Audit" normal " mode");
  
    if (audit_compliant > 0) {
      print_count_offset(6, "->", green, audit_compliant, "compliant");
    }
    if (audit_notapplicable > 0) { 
      print_count_offset(6, "->", green, audit_notapplicable, "not-applicable");
    }
    if (audit_noncompliant > 0) {
      print_count_offset(6, "->", magenta, audit_noncompliant, "non-compliant");
    }
    if (audit_error > 0) {
      print_count_offset(6, "->", red, audit_error, "error");
    }
  }

  if (run_error > 0) {
    printf "%sThis summary is incomplete as the agent was interrupted during execution%s\n", red, normal;
  }

  printf "Execution time: %.2fs\n", endtime - starttime;

  printf "%s%-80.80s%s\n", white, padding, normal;

  # Set return code
  if (run_error+audit_error+audit_noncompliant+enforce_error != 0) {
    exit 1;
  }
}
