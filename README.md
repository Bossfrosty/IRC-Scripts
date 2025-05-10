# top.tcl 2025    
Author: Ryan / brake^t (bossfrosty@proton.me)

Description:
This script is designed to manage and display user statistics 
for a word counter game on an IRC channel. It includes commands 
for retrieving top scores for different timeframes (today, week, month, year)
and individual statistics using commands like !top and !topstat.
The script also handles point additions and resets on a daily basis 
and maintains user data in specified file paths.

Commands: 
- !top (week, month, year): Retrieves the top scores for the specified timeframe.
- !topstat (me, nick): Retrieves statistics for the specified user.

Script Functions
1. top:pub_msg - Handles incoming messages and updates user statistics.
2. top:users - Updates user data in the users file.
3. top:add_points - Adds points to the specified user for the given timeframe.
4. top:get_top - Retrieves the top scores for the specified timeframe.
5. top:pub_top - Handles the command to retrieve top scores.
6. top:pub_stats - Handles the command to retrieve user statistics.
7. top:get_nick_stats - Retrieves statistics for a specific user.
8. top:points_reset - Resets points at the specified time.
9. top:points_reset_now - Resets points for the specified timeframe.
10. top:rank_score - Retrieves the rank and score for a specific user.
11. top:manual_add_points - Manually adds points to a user.
12. top:suffix - Generates a suffix for the rank.
13. top:commify - Formats numbers with commas for better readability.

To activate, use the command .chanset #channel +topnick
