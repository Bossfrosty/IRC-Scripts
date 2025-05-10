# Usage: !flames <name1> <name2>

proc flames {nick user host args} {
    # Check if there are at least two arguments
    set names [split $args " "]
    if {[llength $names] != 2} {
        putserv "PRIVMSG $nick :Usage: !flames <name1> <name2>"
        return
    }

    set name1 [lindex $names 0]
    set name2 [lindex $names 1]

    # Remove spaces and convert to lowercase
    set name1 [string tolower [string trim $name1]]
    set name2 [string tolower [string trim $name2]]

    # Get the current date
    set currentDate [clock seconds]
    set day [clock format $currentDate -format "%d"]

    # Calculate flames based on names and current date
    set flamesResult [calculate_flames $name1 $name2 $day]



    # Send results back
    putserv "PRIVMSG $nick :The result of $name1 and $name2 is: $flamesResult"
}

proc calculate_flames {name1 name2 day} {
    # Count the common letters
    set commonCount 0

    foreach letter [split $name1 ""] {
        if {[string first $letter $name2] != -1} {
            set commonCount [expr {$commonCount + 1}]
            set name1 [string map [list $letter ""] $name1]
            set name2 [string map [list $letter ""] $name2]
        }
    }

    # Determine the remaining letters
    set remainingCount [expr {[string length $name1] + [string length $name2] - 2 * $commonCount}]

    # Combine remaining count with the current day
    set totalPairs [expr {$remainingCount + $day}]

    # FLAMES calculation
    set flames "FLAMES"
    while {[string length $flames] > 1} {
        set index [expr {$totalPairs % [string length $flames]}]
        if {$index == 0} {
            set index [expr {[string length $flames] - 1}]
        } else {
            set index [expr {$index - 1}]
        }
        
        set flames [string replace $flames $index $index ""]
    }

    # Define the final meaning of the result based on remaining character
    switch -exact [string index $flames 0] {
        F { set result "Friends" }
        L { set result "Love" }
        A { set result "Affection" }
        M { set result "Marriage" }
        E { set result "Enemies" }
        S { set result "Sweethearts" }
        default { set result "Unknown" }
    }

    return $result
}

# Hook for the command
bind pub - "!flames" flames
