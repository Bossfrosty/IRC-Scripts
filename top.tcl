################################################
#             top_v2.tcl 2025                  #
################################################
# Description:
# This script is designed to manage and display user statistics 
# for a word counter game on an IRC channel. It includes commands 
# for retrieving top scores for different timeframes (today, week, month, year)
# and individual statistics using commands like !top and !topstat.
# The script also handles point additions and resets on a daily basis 
# and maintains user data in specified file paths.
#
# Commands: 
# - !top (week, month, year): Retrieves the top scores for the specified timeframe.
# - !topstat (me, nick): Retrieves statistics for the specified user.
#
# Script Functions
# 1. top:pub_msg - Handles incoming messages and updates user statistics.
# 2. top:users - Updates user data in the users file.
# 3. top:add_points - Adds points to the specified user for the given timeframe.
# 4. top:get_top - Retrieves the top scores for the specified timeframe.
# 5. top:pub_top - Handles the command to retrieve top scores.
# 6. top:pub_stats - Handles the command to retrieve user statistics.
# 7. top:get_nick_stats - Retrieves statistics for a specific user.
# 8. top:points_reset - Resets points at the specified time.
# 9. top:points_reset_now - Resets points for the specified timeframe.
# 10. top:rank_score - Retrieves the rank and score for a specific user.
# 11. top:manual_add_points - Manually adds points to a user.
# 12. top:suffix - Generates a suffix for the rank.
# 13. top:commify - Formats numbers with commas for better readability.
#
# To activate, use the command .chanset #channel +topnick
################################################

################################################
# Setup Settings
# 1. Set Save File Path
set save_file "/home/user/botfolder/scripts/top/"
# 2. Set default channel flag
set def_flag "topnick"
################################################

# Initialize variables
set current_time [clock format [clock seconds] -format "%Y-%m-%d/%H:%M:%S"]
set current_month_num [scan [clock format [clock seconds] -format "%m"] %d]
set current_month_name [clock format [clock seconds] -format "%B"]
set current_year [clock format [clock seconds] -format "%Y"]

# Calculate the start of the current week (Monday)
set start_of_week [clock format [expr {[clock seconds] - (([clock format [clock seconds] -format "%w"] - 1) * 86400)}] -format "%d"]

# Calculate the end of the current week (Sunday)
set end_of_week [clock format [expr {[clock seconds] + ((7 - [clock format [clock seconds] -format "%w"]) * 86400)}] -format "%d"]
set current_date [clock format [clock seconds] -format "%b. %d, %Y"] 

# Set the default channel flag
setudef flag $def_flag

# Bind the commands
bind pub - "!top" top:pub_top
bind pub - "!topstat" top:pub_stats
bind pub - "!topstats" top:pub_stats
bind pubm - * top:pub_msg
bind msg mn "topadd" top:manual_add_points

# Automatically reset points at midnight
bind time - "00 00 * * *" top:points_reset

################################################

################################################

proc top:pub_msg {nick host hand chan text} {
    global top save_file current_month_num
    set cur_month [expr $current_month_num]
    set ident [lindex [split $host @] 0]
    set host [lindex [split $host @] 1]
    set ident [string map {"~" ""} $ident]
    set char_count [string length $text]
    set text [string trim $text]
    set word_count [llength [split $text " "]]

    if {![file exists $save_file]} {
        file mkdir $save_file
    }
    
    top:add_points today $nick $ident $chan $word_count
    top:add_points week $nick $ident $chan $word_count
    top:add_points month $nick $ident $chan $word_count
    top:add_points year $nick $ident $chan $word_count
    top:users $nick $ident $host $chan $text
}

proc top:users {nick ident host chan text} {
    global top save_file current_time
    set text [string map {" " "`@"} $text]
    set chan [string tolower $chan]
    set file_path "${save_file}users/users.txt"
    if {![file exists $file_path]} {
        file mkdir ${save_file}users
        putlog "Creating users.txt file: $file_path"
        set nickstats_file [open $file_path w]
        puts $nickstats_file ""
        close $nickstats_file

        set new_line "$nick $ident $host $chan $current_time $text"
        set nickstats_file [open $file_path a]
        puts $nickstats_file $new_line
        close $nickstats_file
        return
    } else {
        # Read the file and parse the data
        set nickstats_file [open $file_path r]
        set file_lines [split [read $nickstats_file] "\n"]
        close $nickstats_file

        set updated_lines {}
        set found 0

        foreach line $file_lines {
            if {[string trim $line] eq ""} {
                continue
            }

            # Match the line based on the nickname
            if {[string match "$nick *" $line]} {
                set nick_data [split $line " "]
                set old_chan [lindex $nick_data 3]
                if {$old_chan == $chan} {
                    set found 1
                    #putlog "Found matching line: $line"
                    set old_ident [lindex $nick_data 1]
                    set old_host [lindex $nick_data 2]
                    
                    set old_current_time [lindex $nick_data 4]
                    # Extract the element containing "@msg:"
                    set old_msg [lindex $nick_data 5]              
                    
                    # Update other indices safely
                    if {$ident != $old_ident} {
                        set nick_data [lreplace $nick_data 1 1 $ident]
                    }
                    if {$host != $old_host} {
                        set nick_data [lreplace $nick_data 2 2 $host]
                    }
                    if {$current_time != $old_current_time} {
                        set nick_data [lreplace $nick_data 4 4 $current_time]
                    }
                    if {$text != $old_msg} {
                        set nick_data [lreplace $nick_data 5 5 $text]
                        # putlog "Updated message: [string map {"`@" " "} $text]"
                    }
                }
                lappend updated_lines [join $nick_data " "]
            } else {
                # Append the line as is if it doesn't match the nickname
                lappend updated_lines $line
            }
        }

        # If the nickname was not found, add a new line
        if {!$found} {
            set new_line "$nick $ident $host $chan $current_time ${text}"
            lappend updated_lines $new_line
        }
    }
    
    # Write the updated lines back to the file
    set nickstats_file [open $file_path w]
    puts $nickstats_file [join $updated_lines "\n"]
    close $nickstats_file
}

proc top:add_points {type nick ident chan points} {
    global top save_file current_month_num
    set current_month [expr $current_month_num + 1]

    if {$type == "today"} {
        set file_path "${save_file}daily/[string tolower $chan].txt"
        file mkdir ${save_file}daily
    } elseif {$type == "week"} {
        set file_path "${save_file}weekly/[string tolower $chan].txt"
        file mkdir ${save_file}weekly
    } elseif {$type == "month"} {
        set file_path "${save_file}monthly/[string tolower $chan].txt"
        file mkdir ${save_file}monthly
    } else {
        set file_path "${save_file}yearly/[string tolower $chan].txt"
        file mkdir ${save_file}yearly
    }

    if {![file exists $file_path]} {
        putlog "Creating file $file_path"
        set nickstats_file [open $file_path w]
        puts $nickstats_file ""
        close $nickstats_file

        if {$type == "month"} {
            set new_line "$nick $ident 0 0 0 0 0 0 0 0 0 0 0 0"
            set new_line [lreplace $new_line $current_month $current_month $points]
        } else {
            set new_line "$nick $ident $points"
        }
        set nickstats_file [open $file_path a]
        puts $nickstats_file $new_line
        close $nickstats_file
        return
    } else {
        # Read the file and parse the data
        set nickstats_file [open $file_path r]
        set file_lines [split [read $nickstats_file] "\n"]
        close $nickstats_file

        set updated_lines {}
        set found 0

        foreach line $file_lines {
            if {[string trim $line] eq ""} {
                continue
            }
            if {[string match "$nick *" $line]} {
                set found 1
                set nick_data [split $line " "]
                
                # Update other indices safely
                if {$type == "month"} {
                    set nick_data [lreplace $nick_data $current_month $current_month [expr $points + [lindex $nick_data $current_month]]]
                } else {
                    set nick_data [lreplace $nick_data 2 2 [expr $points + [lindex $nick_data 2]]]
                }
                
                lappend updated_lines [join $nick_data " "]
            } else {
                lappend updated_lines $line
            }
        }

        # If the nickname was not found, add a new line
        if {!$found} {
            if {$type == "month"} {
                set new_line "$nick $ident 0 0 0 0 0 0 0 0 0 0 0 0"
                set new_line [lreplace $new_line $current_month $current_month $points]
            } else {
                set new_line "$nick $ident $points"
            }
            lappend updated_lines $new_line
        }

        # Write the updated lines back to the file
        set nickstats_file [open $file_path w]
        puts $nickstats_file [join $updated_lines "\n"]
        close $nickstats_file
    }
}

proc top:get_top {type chan num} {
    global top save_file current_month_num current_year current_month_name start_of_week end_of_week current_date
    set current_month [expr $current_month_num + 1]

    if {$type == "month"} {
        set file_path "${save_file}monthly/[string tolower $chan].txt"
        set title "𝐓𝐇𝐈𝐒 𝐌𝐎𝐍𝐓𝐇"
    } elseif {$type == "year"} {
        set file_path "${save_file}yearly/[string tolower $chan].txt"
        set title "𝐓𝐇𝐈𝐒 𝐘𝐄𝐀𝐑"
    } elseif {$type == "week"} {
        set file_path "${save_file}weekly/[string tolower $chan].txt"
        set title "𝐓𝐇𝐈𝐒 𝐖𝐄𝐄𝐊"
    } else {
        set file_path "${save_file}daily/[string tolower $chan].txt"
        set title "𝐓𝐎𝐃𝐀𝐘"
    }

    if {![file exists $file_path]} {
        return
    }
	
    # Read the file and parse the data
    set nickstats_file [open $file_path r]
    set file_lines [split [read $nickstats_file] "\n"]
    close $nickstats_file

    set nick_scores {}

    foreach line $file_lines {
        if {[string trim $line] eq ""} {
            continue
        }
        set nick_data [split $line " "]
        set nick [lindex $nick_data 0]
        if {$type == "month"} {
            set points [lindex $nick_data $current_month]
        } else {
            set points [lindex $nick_data 2]
        }

        if {![string equal $points "0"]} {
            lappend nick_scores [list $nick $points]
        }
    }

    # Sort by today's score (descending) and take the top 10
    set sorted_scores [lsort -index 1 -integer -decreasing $nick_scores]
    set top_10 [lrange $sorted_scores 0 [expr $num - 1]]

    # Format the top_10 results into a single string
    set result ""
    set rank 1
    foreach {nick} $top_10 {
        #Split the nick and score
        set split_nick [split $nick " "]
        set nick [lindex $split_nick 0]
        set score [lindex $split_nick 1]

        if {[string length $result] > 0} {
            append result ", "
        }
        if {$chan != "#makati"} {
            append result "[top:suffix $rank] $nick \00307(\003\002[top:commify $score]\002\00307)\003"
        } else {
            append result "[top:suffix $rank] $nick (\002[top:commify $score]\002)"
        }
        incr rank
    }
    set result [string trimright $result ", "]

    # Send the result to the channel
    set result [string map {"{" "" "}" ""} $result]
    # Title
    if {$chan != "#makati"} {
        putserv "PRIVMSG $chan :\002\[\002\00307𝐓𝐎𝐏 $num $title\003\002\]\002"
    } else {
        putserv "PRIVMSG $chan :\002\[\002𝐓𝐎𝐏 $num $title\002\]\002"
    }
    # Result
    putserv "PRIVMSG $chan :$result"
}

proc top:pub_top {nick host hand chan text} {
    global top
    set text [split [string tolower [string trim $text]] " "]
    set type [lindex $text 0]

    if {[channel get $chan "topnick"]} {
        if {$type == "month"} {
            top:get_top month $chan 10
        } elseif {$type == "year"} {
            top:get_top year $chan 10
        } elseif {$type == "week"} {
            top:get_top week $chan 10
        } else {
            top:get_top today $chan 10
        }
    }
}

proc top:pub_stats {nick host hand chan text} {
    global top save_file
    set check_nick [lindex $text 0]

    if {[channel get $chan "topnick"]} {
        if {$check_nick == "me" || $check_nick == ""} {
            top:get_nick_stats $nick $chan
        } else {
            set file_path "${save_file}users/users.txt"
            set nickstats_file [open $file_path r]
            set file_lines [split [read $nickstats_file] "\n"]
            close $nickstats_file

            set found 0
            foreach line $file_lines {
                if {[string match "$check_nick *" $line]} {
                    set nick_data [split $line " "]
                    set old_chan [lindex $nick_data 3]
                    if {$old_chan == $chan} {
                        set found 1
                        break
                    }
                }
            }

            if {$found == 0} {
                putserv "PRIVMSG $chan :$nick, the nick $check_nick doesn't have any records in the users file."
                return
            } else {
                top:get_nick_stats $check_nick $chan
            }
        }
    }
}

proc top:get_nick_stats {nick chan} {
    global top save_file current_month_num current_year current_month_name start_of_week end_of_week current_date
    set current_month [expr $current_month_num + 1]
    # Get the user's stats
    set today_path "${save_file}daily/[string tolower $chan].txt"
    set week_path "${save_file}weekly/[string tolower $chan].txt"
    set month_path "${save_file}monthly/[string tolower $chan].txt"
    set user_path "${save_file}users/users.txt"
    # User data
    set last_msg ""
    set last_seen ""
    set last_host ""

    # Get Rank and Scores
    set today_score [top:rank_score $nick $chan today]
    set week_score [top:rank_score $nick $chan week]
    set month_score [top:rank_score $nick $chan month]

    # Get User's stats
    set user_file [open $user_path r]
    set user_data [split [read $user_file] "\n"]
    close $user_file
    foreach line $user_data {
        if {[string match "$nick *" $line]} {
            set nick_data [split $line " "]
            set old_chan [lindex $nick_data 3]
            if {$old_chan == $chan} {
                # set last_msg [string map {"`@" " "}[lindex $nick_data 5]]
                set last_seen [lindex $nick_data 4]
                set last_host [lindex $nick_data 2]
                break
            }
        }
    }

    # Send the result to the channel
    putserv "PRIVMSG $chan :\002\[STATS\]\002 \002Nick:\002 $nick | \002POINTS Today:\002 $today_score, \002Week:\002 $week_score, \002Month:\002 $month_score"
}

proc top:points_reset {minute hour day month year} {
	global top
	set week_reset 0
	set month_reset 0

	if {[clock format [clock seconds] -format "%w"] == 1} {
		set week_reset 1
	}

	if {[clock format [clock seconds] -format "%e"] == 1} {
		if {![info exists top(month_reseted)]} {
			set month_reset 1
			set top(month_reseted) 1
		}
	} elseif {[info exists top(month_reseted)]} {
		unset top(month_reseted)
	}

    # Check if the day reset is needed
	if {$month_reset == "1"} {
		top:points_reset_now 2
		return
	}
    
    # Check if the week reset is needed
	if {$week_reset == "1"} {
		top:points_reset_now 1
		return
	}
	
    # Check if the day reset is needed
	top:points_reset_now 0
}

proc top:points_reset_now {reset_type} {
    global top save_file

    if {$reset_type == 3} {
        set type_path_name "yearly/"
        set get_top "year"
    } elseif {$reset_type == 2} {
        set type_path_name "monthly/"
        set get_top "month"
    } elseif {$reset_type == 1} {
        set type_path_name "weekly/"
        set get_top "week"
    } else {
        set type_path_name "daily/"
        set get_top "today"
    }

    foreach chan [channels] {
        set file_path "${save_file}${type_path_name}[string tolower $chan].txt"
        if {![file exists $file_path]} {
            continue
        } else {
            set nickstats_file [open $file_path r]
            set file_lines [split [read $nickstats_file] "\n"]
            close $nickstats_file
        }

        if {[channel get $chan "topnick"]} {
            # Show Top 3 for the channel before resetting
            top:get_top $get_top $chan 3
            # Write the updated lines back to the file
            set nickstats_file [open $file_path w]
            puts $nickstats_file ""
            close $nickstats_file

            if {$reset_type == 2} {
                set type_text "The scoreboard has been wiped clean for a new month."
            } elseif {$reset_type == 1} {
                set type_text "The scoreboard has been wiped clean for a new week."
            } else {
                set type_text "All points have been reset for today."
            }
            # Send the result to the channel
            putserv "PRIVMSG $chan :📣 $type_text"
        }
    }
}

proc top:rank_score {nick chan type} {
    global top save_file current_month_num current_year current_month_name start_of_week end_of_week current_date
    set current_month [expr $current_month_num + 1]

    if {$type == "month"} {
        set file_path "${save_file}monthly/[string tolower $chan].txt"
    } elseif {$type == "year"} {
        set file_path "${save_file}yearly/[string tolower $chan].txt"
    } elseif {$type == "week"} {
        set file_path "${save_file}weekly/[string tolower $chan].txt"
    } else {
        set file_path "${save_file}daily/[string tolower $chan].txt"
    }
    # Read the file and parse the data
    set nickstats_file [open $file_path r]
    set file_lines [split [read $nickstats_file] "\n"]
    close $nickstats_file
    # Store nicks and scores
    set nick_scores {}
    set found 0

    foreach line $file_lines {
        if {[string trim $line] eq ""} {
            continue
        }
        set nick_data [split $line " "]
        set nick_name [lindex $nick_data 0]
        if {[string equal $nick_name $nick]} {
            set found 1
        }
        if {$type == "month"} {
            set points [lindex $nick_data $current_month]
        } else {
            set points [lindex $nick_data 2]
        }

        if {![string equal $points "0"]} {
            lappend nick_scores [list $nick_name $points]
        }
    }
    # Sort by today's score (descending)
    set sorted_scores [lsort -index 1 -integer -decreasing $nick_scores]

    # Check if the nick is in the sorted list
    set rank 1
    set result ""
    if {$found == 0} {
        return "n/a"
    } else {
        foreach {searchnick} $sorted_scores {
            # Split the nick and score
            set split_nick [split $searchnick " "]
            set nickname [lindex $split_nick 0]
            set score [lindex $split_nick 1]
            if {[string equal $nickname $nick]} {
                set result "[top:suffix $rank] (\002[top:commify $score]\002)"
                break
            }
            incr rank
        }
        return $result
    }
}

proc top:manual_add_points {nick user host args} {
    global top save_file current_month_num current_year current_month_name start_of_week end_of_week current_date
    set current_month [expr $current_month_num + 1]

    # args = nick chan points
    set args_list [split $args]
    set nickname [string trim [lindex $args_list 0] "{}"]
    set chan [string trim [lindex $args_list 1] "{}"]
    set ident "uid"
    set points [string trim [lindex $args_list 2] "{}"]

    top:add_points week $nickname $ident $chan $points
    top:add_points month $nickname $ident $chan $points
    top:add_points year $nickname $ident $chan $points

    # Send the result after adding points
    putserv "PRIVMSG $nick :Added \002$points\002 points to \002$nickname\002 in \002$chan\002."
}

proc top:suffix {num} {
    set suffix "${num}\u1d57\u02b0"
    if {[expr {$num % 10}] == 1 && $num != 11} { set suffix "🥇${num}\u02e2\u1d57" }
    if {[expr {$num % 10}] == 2 && $num != 12} { set suffix "🥈${num}\u207f\u1d48" }
    if {[expr {$num % 10}] == 3 && $num != 13} { set suffix "🥉${num}\u02b3\u1d48" }
    return $suffix
}

proc top:commify {num} {
    if {[string is integer -strict $num]} {
        if {$num >= 1000000} {
            set num [format "%.1fm" [expr {$num / 1000000.0}]]
        } elseif {$num >= 1000} {
            set num [format "%.1fk" [expr {$num / 1000.0}]]
        }
    }
	return $num
}

# End of the script
putlog "Loading top_v2.tcl script... [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]]"
putlog "Top_v2.tcl script by Ryan / brake^t loaded successfully."
# Author: Ryan / brake^t (bossfrosty@proton.me)
