#!/bin/bash
#
###############################################################################################################################################
#
# ABOUT THIS PROGRAM
#
#	JAMF-Ext-ScreenRec-Perm.sh
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
#   Version: 1.5 - 25/11/2020
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
#   - 13/01/2020 - V1.3 - Updated by Headbolt
#							Now allows for multiple entries by the target app, by filtering first
#								for kTCCServiceScreenCapture and then the App Name
#   - 14/01/2020 - V1.4 - Updated by Headbolt
# 							Added a safeguard against a log Error message as an output.
#								When the plist or plist pair does not exist, the error expected would be.
#								"The domain/default pair of (/var/JAMF/ScreenRecording-Perms.plist, $AppIDstring) does not exist"
#   - 25/11/2020 - V1.5 - Updated by Headbolt
# 							Added a check incase BASH not avaialable (MacOS 10.15.7 and above) and shell drops back to ZSH
#								In Which Case an extra command is needed to utilise the Internal Field Separator
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
AppIDstring=ScreenConnect # Grab the identifier to use when searching the TCC Database.
# Note : this can usually be found by manually allowing on a test machine and then running the below command
# sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db 'select * from access'
#
CurrentAppPerms=$(sudo defaults read /var/JAMF/ScreenRecording-Perms.plist $AppIDstring 2>&1) # Grab last written value
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
				App=$(sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db 'select * from access' | grep -i kTCCServiceScreenCapture | grep -i $AppIDstring) # Find the line for the App
				AccErr=$(sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db 'select * from access' 2>&1 | grep unable) # Check for permissions error
				#
				IFS='|' # Internal Field Seperator Delimiter is set to Pipe (|)
				if [ $ZSH_VERSION ]
					then
						setopt sh_word_split
				fi
				AppStatus=$(echo $App | awk '{ print $4 }')
				unset IFS
				#
				if [[ "$AccErr" == "" ]] # Check if there was a permissions error accessing the TCC.db file
					then
						if [[ $AppStatus -gt "0" ]] # Check if the app has Screen Recording permission enabled
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
				sudo defaults write /var/JAMF/ScreenRecording-Perms.plist $AppIDstring -string "$RESULT" # Write Result into PLIST
				#
			else
				# Now we safeguard against a log Error message as an output.
				# When the plist or plist pair does not exist, the error expected would be.
				# "The domain/default pair of (/var/JAMF/ScreenRecording-Perms.plist, $AppIDstring) does not exist"
				if [[ "$CurrentAppPerms" = *domain/default* ]]
					then
						/bin/echo "<result>NOT PRESENT</result>"
					else 
						/bin/echo "<result>$CurrentAppPerms</result>" # If no User logged in, re-write last known value
				fi
        fi
	else
		RESULT="OS is Lower than Catalina"
		/bin/echo "<result>$RESULT</result>" # Write Result out
fi
