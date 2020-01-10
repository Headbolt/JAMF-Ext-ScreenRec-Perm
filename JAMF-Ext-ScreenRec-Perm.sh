#!/bin/bash
#
###############################################################################################################################################
#
#	JAMF-Ext-ScreenRec-Perm
#	https://github.com/Headbolt/JAMF-Ext-ScreenRec-Perm
#
#   This Script is designed for use in JAMF as an Extension Attribute
#
#   - This script will ...
#       Look at the OS Version, and if Catalina Or Higher
#		Then check the SCC Database to see if the specified Application
#		Is enabled for Screen Recording
#
#	- For this to function Correctly, Config Profiles will be needed to
#		grant JAMF further permissions to access the TCC Database
#		- At present this seems to be sending Apple Events to System Events
#			and Full Disk Access, but this may possibly be able to be reduced a little.
#
###############################################################################################################################################
#
# HISTORY
#
#   Version: 1.2 - 10/01/2020
#
#   - 06/01/2020 - V1.0 - Created by Headbolt
#   - 09/01/2020 - V1.1 - Updated by Headbolt
#							More thorough error checking and notation
#   - 10/01/2020 - V1.2 - Updated by Headbolt
#							Now allows for permissions issues when no user logged in
#								Success now writes the correct value to a PLIST
#								On execution the Value is read in, and if no user is logged in,
#								resulting in and error, the read in Value is Output to keep from
#								having Error values or blank entries written
#
###############################################################################################################################################
#
# DEFINE VARIABLES & READ IN PARAMETERS
#
###############################################################################################################################################
#
User=$(stat -f '%Su' /dev/console) # Grab Current Console User
#
osMajor=$( /usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $1}' )
osMinor=$( /usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $2}' )
osPatch=$( /usr/bin/sw_vers -productVersion | /usr/bin/awk -F. '{print $3}' )
#
AppIDstring=ScreenConnect # Grab the identifier to use when searching the TCC Database from JAMF variable #4 eg ScreenConnect
# Note : this can usually be found by manually allowing on a test machine and then running the below command
# sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db 'select * from access'
#
CurrentAppPerms=$(defaults read /var/JAMF/ScreenRecording-Perms.plist $AppIDstring 2>&1) # Grab last written value
#
###############################################################################################################################################
#
# SCRIPT CONTENTS - DO NOT MODIFY BELOW THIS LINE
#
###############################################################################################################################################
#
if [[ "$osMajor" -lt "11" ]]
	then
		if [[ "$osMajor" -lt "10" ]]
			then
				CATplus="NO"
			else 
				if [[ "$osMinor" -ge "15" ]]
					then
						CATplus="YES"
					else
						CATplus="NO"
				fi
		fi
	else
		CATplus="YES"
fi
#
if [[ "$CATplus" == "YES" ]]
	then
		if [[ $User != "root" ]] # Check if a user is logged in, if not this can result in errors
			then
				App=$(sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db 'select * from access' | grep -i $AppIDstring) # Find the line for the App
				AccErr=$(sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db 'select * from access' 2>&1 | grep unable) # Check for permissions error
				read -ra AppStatusArray <<< "$App" # Read In the Array
				#
				IFS='|' # Internal Field Seperator Delimiter is set to Pipe (|)
				AppStatus=$(echo $AppStatusArray | awk '{ print $4 }')
				unset IFS
				#
				if [[ "$AccErr" == "" ]] # Check if there was a permissions error accessing the TCC.db file
					then 
						if [[ $AppStatus == 1 ]] # Check if the app has Screen Recording permission enabled
							then
								RESULT="SET"
							else
								if [[ $AppStatus == "" ]]
									then
										RESULT="NOT PRESENT"
									else
										RESULT="NOT SET"
								fi
						fi
					else 
						RESULT="PERMISSIONS ERROR"
				fi
				#
				/bin/echo "<result>$RESULT</result>" # Write Result out
				defaults write /var/JAMF/ScreenRecording-Perms.plist $AppIDstring -string "$RESULT" # Write Result into PLIST
				#
			else
				/bin/echo "<result>$CurrentAppPerms</result>" # If no User logged in, re-write last known value
		fi
	else
		RESULT="OS is Lower than Catalina"
		/bin/echo "<result>$RESULT</result>" # Write Result out
fi
