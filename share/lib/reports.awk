BEGIN {
  FS = "@#";
  nf_report = 0;
  is_report = 0;
  broken_reports = 0;
  success = 0;
  error = 0;
  repaired = 0;
  current_technique = "";
  current_component = "";
  new_technique = 0;
  header_printed = 0;
  end_run = 0;
  padding_dash = "--------------------------------------------------------------------------------"
  padding =      "################################################################################"
  "date +%s.%N" | getline starttime;
  # needed to be able to call the same command a second time
  close("date +%s.%N");
}
{
  is_report = 0;

  if (NF > 1)
  {
    # $1 is the report, the rest is the message
    # split the first part of the report
    nf_report = split($1, r, "##|@@");

    ## variable -> report field:
    # r[2]    -> technique
    # r[3]    -> result
    # r[7]    -> component
    # r[8]    -> key
    # message -> message
    ##

    # the rest is the message
    message = substr($0, length($1) + 3);

    if (nf_report == 10 && match(r[1], /.*R: $/))
    {
      # line has been parsed as a valid report
      is_report = 1;
    }
  }
  
  if (summary_only)
  {
    print $0
  }

  if (!is_report)
  {
    # very likely a broken report
    if (match($0, /.*R: @@/))
    {
      broken_reports++;
    } 

    if (info)
    {
      print darkgreen $0 normal;
    }
    next
  }
  
  # Wait for the StartRun to display the config id
  if (r[8] == "StartRun")
  {
    printf "%s\n\n", message;
    next
  }
  if (r[8] == "EndRun")
  {
    end_run = 1;
    # skip this one
    next
  }

  # New control log introduced in 4.2
  if (r[3] == "control" && r[4] == "rudder" && r[5] == "run")
  {
    if (r[7] == "start")
    {
      printf "Start execution with config [%s]\n\n", r[8];
      next
    }
    if (r[7] == "end")
    {
      end_run = 1;
      # skip this one
      next
    }
  }
  
  if (r[3] == "result_success")
  {
    success++;
    if (quiet)
    {
      next
    }
    color = green;
    result = "success";
  }
  else if (r[3] == "result_error")
  {
    error++;
    color = red;
    result = "error";
  }
  else if (r[3] == "result_na")
  {
    if (quiet)
    {
      next
    }
    color = green;
    result = "n/a";
  }
  else if (r[3] == "result_repaired")
  {
    repaired++;
    color = yellow;
    result = "repaired";
  }
  else if (r[3] == "log_warn")
  {
    color = magenta;
    result = "warning";
  }
  else if (r[3] == "log_info" || r[3] == "log_debug" || r[3] == "log_trace" || r[3] == "log_repaired")
  {
    if (!info)
    {
      next
    }
    color = cyan;
    result = "info";
  }
  else
  {
    if (quiet)
    {
      next
    }
    color = white;
    result = r[3];
  }
  if (r[8] == "None")
  { 
    # Do not display "None" keys
    r[8] = "";
  }
  
  { 
    if (!summary_only)
    {
      if (multiline)
      {      
        if (!header_printed)
        {
          header_printed = 1;
          printf "%s%-80.80s%s\n", white, padding, normal;
        }
        
        printf "%s%s%s: %s\n", color, result, normal, message;
      
        if (r[8] != "")
        {
          printf "%s%-80.80s%s\n", white, "-- Key: " r[8] " " padding_dash, normal;
        }
        
        printf "%s%-80.80s%s\n", white, "-- Component: " r[7] " " padding_dash, normal;
      
        printf "%s%-80.80s%s\n", white, "-- Technique: " r[2] " " padding_dash, normal;
        
        printf "%s%-80.80s%s\n\n", white, padding, normal;
        
        if (!last_line) {
          printf "%s%-80.80s%s\n", white, padding, normal;
        }
      }
      else {
        if (!header_printed)
        {
          header_printed = 1;
          printf "%s%-8.8s %-25.25s %-25.25s %-18.18s %s%s\n", white, "Result", "Technique", "Component", "Key", "Message", normal;
        }
      
        printf "%s%-8.8s%s ", color, result, normal;

        if (full_strings)
        {
          printf "%-25s %-25s %-18s", r[2], r[7], r[8];
        }
        else
        {
          if (length(r[2]) > 25)
          {
            printf "%-24.24s| ", r[2];
          } else {
            printf "%-25.25s ", r[2];
          }

          if (length(r[7]) > 25)
          {
            printf "%-24.24s| ", r[7];
          } else {
            printf "%-25.25s ", r[7];
          }

          if (length(r[8]) > 18)
          {
            printf "%-17.17s| ", r[8];
          } else {
            printf "%-18.18s ", r[8];
          }
        }

        printf "%s\n", message
      }
      if (has_fflush) 
      {
        fflush();
      }
    }
  }
}
END {
  "date +%s.%N" | getline endtime;

  # Check if agent run finished correctly
  if (!end_run && full_compliance)
  {
    error++;
    printf "%s", red;
    if (multiline)
    {
      printf "error: Rudder agent was interrupted during execution by a fatal error.";
      if (!info) {
        printf " Run with -i to see log messages.";
      }
    }
    else
    {
      printf "error    Rudder agent was interrupted during execution by a fatal error";
      if (!info) {
        printf "\n         Run with -i to see log messages.";
      }
    }
    printf "%s\n", normal;
  }

  # Check for unparsable reports
  if (broken_reports)
  {
    printf "%s", magenta;
    if (multiline)
    {
      printf "warning: %d reports were not parsable.", broken_reports;
      if (!info) {
        printf " Run with -i to see log messages.";
      }
    }
    else
    {
      printf "warning  %d reports were not parsable.", broken_reports;
      if (!info) {
        printf "\n         Run with -i to see log messages.";
      }
    }
    printf "%s\n", normal;
  }

  printf "\n%s%-80.80s%s\n", white, "## Summary " padding, normal

  if (success > 0)
  {
    printf "success: %s%6s%s\n", green, success, normal
  }
  if (repaired > 0)
  {
    printf "repaired: %s%5s%s\n", yellow, repaired, normal
  }
  if (error > 0)
  {
    printf "error: %s%8s%s\n", red, error, normal;
  }

  printf "execution time: %.2fs\n", endtime - starttime, endtime, starttime;

  printf "%s%-80.80s%s\n", white, padding, normal

  if (error != 0)
  {
    exit 1;  
  }
}
