BEGIN {
  FS = "[#@][#@]";
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
  ## Enter the main loop
  # $2 -> technique
  # $3 -> result
  # $7 -> component
  # $8 -> key
  # $11 -> message
  ##
  
  if (summary_only)
  {
    print $0
  }
  # The line may begin with a color char (particularly in CFEngine 3.7 output)
  else if (!match($1, /.*R: $/) || NF != 11)
  {
    if (info)
    {
      print darkgreen $0 normal;
    }
    next
  }
  
  # Wait for the StartRun to display the config id
  if ($8 == "StartRun")
  {
    printf "%s\n\n", $11;
    next
  }
  if ($8 == "EndRun")
  {
    end_run = 1;
    # skip this one
    next
  }
  
  if ($3 == "result_success")
  { 
    success++;
    if (quiet)
    {
      next
    }
    color = green;
    result = "success";
  }
  else if ($3 == "result_error")
  {
    error++;
    color = red;
    result = "error";
  }
  else if ($3 == "result_na")
  {
    if (quiet)
    {
      next
    }
    color = green;
    result = "n/a";
  }
  else if ($3 == "result_repaired")
  {
    repaired++;
    color = yellow;
    result = "repaired";
  }
  else if ($3 == "log_warn")
  {
    color = magenta;
    result = "warning";
  }
  else if ($3 == "log_info" || $3 == "log_debug" || $3 == "log_trace" || $3 == "log_repaired")
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
    result = $3;
  }
  if ($8 == "None")
  { 
    # Do not display "None" keys
    $8 = "";
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
        
        printf "%s%s%s: %s\n", color, result, normal, $11;
      
        if ($8 != "")
        {
          printf "%s%-80.80s%s\n", white, "-- Key: " $8 " " padding_dash, normal;
        }
        
        printf "%s%-80.80s%s\n", white, "-- Component: " $7 " " padding_dash, normal;
      
        printf "%s%-80.80s%s\n", white, "-- Technique: " $2 " " padding_dash, normal;
        
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
          printf "%-25s %-25s %-18s", $2, $7, $8;
        }
        else
        {
          if (length($2) > 25)
          {
            printf "%-24.24s| ", $2;
          } else {
            printf "%-25.25s ", $2;
          }

          if (length($7) > 25)
          {
            printf "%-24.24s| ", $7;
          } else {
            printf "%-25.25s ", $7;
          }

          if (length($8) > 18)
          {
            printf "%-17.17s| ", $8;
          } else {
            printf "%-18.18s ", $8;
          }
        }

        printf "%s\n", $11
      }
      fflush();
    }
  }
}
END {
  "date +%s.%N" | getline endtime;

  # Check if agent run finished correctly
  if (!end_run)
  {
    error++;
    if (multiline)
    {
      printf "%serror: Rudder agent was interrupted during execution by a fatal error. Run with -i to see log messages.%s\n", red, normal;
    }
    else {
      printf("%serror    Rudder agent was interrupted during execution by a fatal error\n         Run with -i to see log messages.%s\n", red, normal)
    }
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
