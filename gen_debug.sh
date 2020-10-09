#!/bin/bash

# A script for generating debugging files for Hackintosh running OpenCore
# Originally written by black.dragon74
# Modified to work with OpenCore by hieplpvip
# EFI Mount script by RehabMan

# Declare variables to be used in this script
scriptVersion=1.0.0
homeDir="$(echo $HOME)"
scriptDir="$homeDir/Library/OC-gen-debug"
dbgURL="https://raw.githubusercontent.com/hieplpvip/OC-gen-debug/master/gen_debug.sh"
efiScript="$scriptDir/mount_efi.sh"
pledit=/usr/libexec/PlistBuddy
efiScriptURL="https://raw.githubusercontent.com/hieplpvip/OC-gen-debug/master/mount_efi.sh"
regExplorer=/Applications/IORegistryExplorer.app
regExplorerURL="https://raw.githubusercontent.com/hieplpvip/OC-gen-debug/master/IORegistryExplorer.zip"
patchmaticB="$scriptDir/patchmatic"
patchmaticBURL="https://raw.githubusercontent.com/hieplpvip/OC-gen-debug/master/patchmatic"
maskedVal="XX-MASKED-XX"
checkForConnAhead=0
randomNumber=$(echo $(( ( RANDOM ) + 12 )))
outDir="$homeDir/Desktop/debug_$randomNumber"
zipFileName=debug_$randomNumber.zip
panicDir="$outDir/panic_logs"
efiloc="null"
sysPfl=/usr/sbin/system_profiler
hostName=$(hostname | sed 's/.local//g' | sed 's/-/_/g')
genSysDump="no"
hasOpenCore=""

# Variables used in dumpIOREG
IODelayForThreeSec=3 # Delay for three seconds

# Declare functions to be used in this script.
function printHeader(){
	clear
	echo -e "====================================="
	echo -e "+   macOS DEBUG REPORT GENERATOR    +"
	echo -e "+-----------------------------------+"
	echo -e "+       SCRIPT VERSION $scriptVersion        +"
	echo -e "+         AUTHOR: hieplpvip         +"
	echo -e "====================================="
	echo " "
}

function checkConn(){
	if ping -c 1 google.com &>/dev/null;
		then
		echo "Internet connectivity is all good to go."
	else
		echo "Unable to connect to the internet. Aborted."
		exit
	fi
}

function IOIncrement(){
	IODelayForThreeSec=$(($IODelayForThreeSec + 3))
}

timesIncremented=1
function checkIOREG(){
	if [[ ! -e "$outDir/$hostName.ioreg" ]]; then
		echo "IOREG dump failed. Retrying by increasing delays..."

		# Increment Delays
		IOIncrement

		# Tell user that values have been increased
		timesIncremented=$(($timesIncremented + 1))
		if [[ $timesIncremented -gt 3 ]]; then
			echo "IOREG dump has failed 3 times. Dumping generic IOREG report instead."
			ioreg -f -l &>"$outDir/generic_ioreg.txt"
		else
			echo -e "Increased delay by x$timesIncremented times. Retrying..."

			# Dump again
			dumpIOREG
		fi
	else
		echo "IOREG Verified as $outDir/$hostName.ioreg"
	fi
}

function dumpIOREG(){
	# Credits black-dragon74
	osascript >/dev/null 2>&1 <<-EOF
		quit application "IORegistryExplorer"
		delay "$IODelayForThreeSec"

		activate application "Applications:IORegistryExplorer.app"
		delay "$IODelayForThreeSec"
		tell application "System Events"
			tell process "IORegistryExplorer"
				keystroke "s" using {command down, option down}
				delay "$IODelayForThreeSec"
				keystroke "g" using {command down, shift down}
				delay "$IODelayForThreeSec"
				keystroke "$outDir"
				delay "$IODelayForThreeSec"
				key code 36
				delay "$IODelayForThreeSec"
				keystroke "$hostName"
				delay "$IODelayForThreeSec"
				key code 36
				delay "$IODelayForThreeSec"
			end tell
		end tell

		quit application "IORegistryExplorer"
	EOF

	# Check for successful dump
	checkIOREG
}

function dumpKernelLog(){
	bt=$(sysctl -n kern.boottime | sed 's/^.*} //')

	bTm=$(echo "$bt" | awk '{print $2}')
	bTd=$(echo "$bt" | awk '{print $3}')
	bTt=$(echo "$bt" | awk '{print $4}')
	bTy=$(echo "$bt" | awk '{print $5}')

	bTm=$(awk -v "month=$bTm" 'BEGIN {months = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec"; print (index(months, month) + 3) / 4}')
	bTm=$(printf %02d $bTm)

	ep=$(/bin/date -jf '%H:%M:%S' $bTt '+%s')

	cs=$((ep - 60 ))

	bTt=$(/bin/date -r $cs '+%H:%M:%S')

	stopTime=$(log show --debug --info --start "$bTy-$bTm-$bTd $bTt" | grep loginwindow | head -1)
	stopTime="${stopTime%      *}"

	echo "Extract boot log from $bTy-$bTm-$bTd $bTt"

	log show --debug --info --start "$bTy-$bTm-$bTd $bTt" | grep -E 'kernel:|loginwindow:' | sed -n -e "/kernel: PMAP: PCID enabled/,/$stopTime/ p"
}

function dumpKextstat(){

	echo -e "Report generated using gen_debug ver$scriptVersion\n"
	echo "ACPIPLAT LOG :-"
	kextstat|grep -y acpiplat
	echo "END ACPIPLAT LOG."
	echo -e " "
	echo -e " "


	echo -e "APPLEINTELCPU LOG:-"
	kextstat|grep -y appleintelcpu
	echo -e "END APPLEINTELCPU LOG."
	echo -e " "
	echo -e " "


	echo -e "APPLE LPC LOG:-"
	kextstat|grep -y applelpc
	echo -e "END APPLE LPC LOG."
	echo -e " "
	echo -e " "


	echo -e "APPLE HDA LOG:-"
	kextstat|grep -y applehda
	echo -e "END APPLE HDA LOG."
	echo -e " "
	echo -e " "


	echo -e "LS FOR APPLEHDA :-"
	ls -l /System/Library/Extensions/AppleHDA.kext/Contents/Resources/*.zml*
	ls -l /System/Library/Extensions/AppleHDA.kext/Contents/Resources/*.xml*
	echo -e "END LS FOR APPLEHDA."
	echo -e " "
	echo -e " "


	echo -e "PMSET DUMP :-"
	pmset -g
	echo -e "END DUMP FOR PMSET"
	echo -e " "
	echo -e " "


	echo -e "PMSET ASSERTIONS DUMP :-"
	pmset -g assertions
	echo -e "END DUMP FOR PMSET ASSERTIONS."
	echo -e " "
	echo -e " "


	echo -e "DUMP FOR TRIM STATUS :-"
	system_profiler SPSerialATADataType|grep TRIM
	echo -e "END DUMP FOR TRIM STATUS."
	echo -e " "
	echo -e " "
}

function dumpAllKextstat(){
	kextstat
}

# Add function to dump system information, requested by Jake
# Make it optional though as a full system report might take 3+ minutes on slow machines
# If user includes a -sysprofile arg then only generate a system report
function genSystemRep(){
	# Generate report in .spx format so that it is easier to debug.
	# If user wishes so, he can generate a report in txt format.
	# To generate a report in .txt format you can use gen_debug -sysprofile txt
	if [[ ! -z $1 ]]; then
		# Check arg
		if [[ "$1" == "txt" ]]; then
			# Generate report in .txt format
			echo "Generating report in txt format as requested."
			$sysPfl > "$outDir/SysDump-$hostName.txt" 2>/dev/null
		else
			echo -e "Ignored invalid arg: $1\nGenerating report in spx format."
			# Generate report in spx format
			$sysPfl -xml > "$outDir/SysDump-$hostName.spx" 2>/dev/null
		fi
	else
		# Generate report in spx format
		$sysPfl -xml > "$outDir/SysDump-$hostName.spx" 2>/dev/null
	fi
}

function dumpBootLog(){
	if [[ -z $(which bdmesg) ]]; then
		echo "BDMESG not found. Unable to dump boot log."
	else
		bdmesg > "$outDir/bootlog.txt" 2>/dev/null
	fi
}

function dumpNVRAM(){
	nvram -x -p
}

function dumpLilu(){
	if [[ ! -z $(ls /var/log | grep -i "lilu") ]]; then
		echo "Dumping LILU logs..."
		mkdir $outDir/lilu_logs
		for f in $(ls /var/log | grep -i "lilu"); do
			cp /var/log/$f $outDir/lilu_logs
		done
	fi
}

function dumpPanicLog(){
	# If panic logs exist, dump them
	if [[ ! -z $(ls /Library/Logs/DiagnosticReports | grep "panic" | grep -i "kernel") ]];
	then
		echo "Dumping kernel panic logs..."
		mkdir $panicDir
		for f in $(ls /Library/Logs/DiagnosticReports | grep "panic" | grep -i "kernel"); do
			cp /Library/Logs/DiagnosticReports/$f $panicDir
		done
	fi
}

function updateIfNew(){
	# This function checks if the script's update is available on the remote
	# If yes, it will update automatically

	if ping -c 1 google.com &>/dev/null; then
		# Get latest version
		cd "$scriptDir"
		curl -o ndbg $dbgURL &>/dev/null
		if [[ -e ./ndbg ]]; then
			chmod a+x ./ndbg
			reVer=$(./ndbg -v)
			if [[ "$reVer" != $scriptVersion ]]; then
				echo "Hey "$(whoami)"! Before we proceed, I found a new version of the script."
				echo "You are running $scriptVersion and new version is $reVer"
				read -p "Shall I update the program now?[y/n]: " updAns
				case $updAns in
					[yY]* )
						# Update
						cp -f ./ndbg $(which gen_debug)
						chmod a+x $(which gen_debug)
						rm ./ndbg &>/dev/null
						echo "Great! Now re run the program..."
						exit
						;;
					* )
						# Don't update
						echo "It is recommended to have the latest version. Still, you rule."
						echo "Proceeding......"
						echo
						rm ./ndbg &>/dev/null
				esac
			fi
			rm ./ndbg &>/dev/null
		fi
	fi
}

if [[ $1 = "-v" ]]; then
	echo $scriptVersion
	exit
fi

# Restrict execution to Darwin
os_name="$(sw_vers -productName 2>/dev/null | awk '{print $1}')"
if [[ $os_name != "Mac" && $os_name != "macOS" ]]; then
	echo "This script is meant for Apple macOS/OSX only." && exit
fi

# Tell them noobs to hold their horses for a while
clear
echo "Please don't touch your computer until the program is finished."
read -p "Do we agree? [Yy/Nn]: " contResp
case $contResp in
	[yY]* )
		# Continue
		;;
	[nN]* )
		# Exit
		echo "Alrighty! See ya sometime soon."
		exit 1
		;;
	* )
		# Exit
		echo "Invalid option selected. Aborting..."
		exit 1
		;;
esac

# Welcome, Here we go!
printHeader

# Update if new version is found on the remote
if [[ $1 != "-u"* ]]; then
	# If script directory is not present then the user is running for the first time, no auto update this time.
	if [[ -e $scriptDir ]]; then
		updateIfNew
	fi
fi

# Check for custom args
arg="$1"
if [[ ! -z $arg ]]; then
	case $arg in
		[-][uU]* )
			echo "Updating your copy of OC-gen-debug"
			checkConn
			cd $(echo $HOME)
			if [[ -e ./tdbg ]]; then
				rm -rf ./tdbg
			fi
			curl -o tdbg $dbgURL &>/dev/null
			if [[ ! -e ./tdbg ]]; then
				echo "Download failed. Try again."
				exit
			fi
			echo "Installing...."
			cp -f ./tdbg $(which gen_debug)
			chmod a+x $(which gen_debug)
			rm ./tdbg &>/dev/null
			exit
			;;
		"-sysprofile" )
			# Set genSysDump to yes
			genSysDump="yes"
			echo "System report will be included in the dump as requested."
			;;
			* )
			echo "Invalid args. Exit."
			exit
			;;
	esac
fi

# Check if script directory exists else create it
if [[ -d $scriptDir ]];
	then
	echo -e "Found script directory at $scriptDir"
else
	echo -e "Script directory not present, creating it."
	mkdir -p "$scriptDir"
fi

# Check for mount EFI script
if [[ -e "$efiScript" ]];
	then
	echo -e "EFI Mount Script (RehabMan) found. No need to download."
	checkForConnAhead=1
else
	echo -e "EFI Mount Script (RehabMan) not found. Need to fetch it."
	echo -e "Checking connectivity.."
	checkConn # If no connection found, script will terminate here.

	# Stuffs to do in case internet connectivity is fine
	echo -e "Downloading EFI Mount script"
	curl -o "$efiScript" $efiScriptURL &>/dev/null

	# Check if the script is actually there
	if [[ -e "$efiScript" ]];
		then
		echo -e "Script downloaded. Verifying."
		if [[ $(echo $(md5 "$efiScript") | sed 's/.*= //g') = 9e104d2f7d1b0e70e36dffd8031de2c8 ]];
			then
			echo -e "Script is verified."
			echo -e "Setting permissions."
			chmod a+x "$efiScript"
		else
			echo -e "Corrupted file is downloaded. Try again."
			rm "$efiScript"
			exit
		fi
	else
		echo -e "Download failed due to some reasons. Try again."
		exit
	fi
fi

# Check for IORegistryExplorer
if [ -e $regExplorer ];
	then
	echo -e "IORegistryExplorer found at $regExplorer"
	echo "Verifying if correct version of IORegistryExplorer is installed."
	if [[ -e $regExplorer/isVerified ]]; then
		echo "Your version of IORegistryExplorer.app passed the check. Good to go!"
		checkForConnAhead=1
	else
		echo "This version of IORegistryExplorer is not recommended."
		echo "Removing conflicting version."
		rm -rf $regExplorer &>/dev/null

		# Check connection only if required
		if [ $checkForConnAhead -eq 1 ];
			then
			echo -e "Checking connectivity.."
			checkConn # If no connection found, script will terminate here.
		fi

		# Stuffs to do in case internet connectivity is fine
		echo -e "Downloading IORegistryExplorer."
		curl -o $scriptDir/IORegistryExplorer.zip $regExplorerURL &>/dev/null

		# Check if the downloaded file exists
		if [[ -e "$scriptDir/IORegistryExplorer.zip" ]];
			then
			echo -e "Downloaded IORegistryExplorer."
			echo -e "Verifying Downloaded file."
			if [[ $(echo $(md5 "$scriptDir/IORegistryExplorer.zip") | sed 's/.*= //g') = dfb90e340024aaf811074fc2e63054f4 ]];
				then
				echo -e "File Verified. Installing."
				unzip -o "$scriptDir/IORegistryExplorer.zip" -d /Applications/ &>/dev/null
				echo -e "Installed IORegistryExplorer at $regExplorer"
				rm -f "$scriptDir/IORegistryExplorer.zip"
				rm -rf /Applications/__MACOSX &>/dev/null
			else
				echo -e "Maybe a corrupted file is downloaded. Try again."
				rm -f "$scriptDir/IORegistryExplorer.zip"
				exit
			fi
		else
			echo -e "Download of IORegistryExplorer failed. Try again."
			exit
		fi
	fi
else
	echo -e "IORegistryExplorer not found at $regExplorer"
	# Check connection only if required
	if [ $checkForConnAhead -eq 1 ];
		then
		echo -e "Checking connectivity.."
		checkConn # If no connection found, script will terminate here.
	fi

	# Stuffs to do in case internet connectivity is fine
	echo -e "Downloading IORegistryExplorer."
	curl -o "$scriptDir/IORegistryExplorer.zip" $regExplorerURL &>/dev/null

	# Check if the downloaded file exists
	if [[ -e $scriptDir/IORegistryExplorer.zip ]];
		then
		echo -e "Downloaded IORegistryExplorer."
		echo -e "Verifying Downloaded file."
		if [[ $(echo $(md5 "$scriptDir/IORegistryExplorer.zip") | sed 's/.*= //g') = dfb90e340024aaf811074fc2e63054f4 ]];
			then
			echo -e "File Verified. Installing."
			unzip -o "$scriptDir/IORegistryExplorer.zip" -d /Applications/ &>/dev/null
			echo -e "Installed IORegistryExplorer at $regExplorer"
			rm -f "$scriptDir/IORegistryExplorer.zip"
			rm -rf /Applications/__MACOSX &>/dev/null
		else
			echo -e "Maybe a corrupted file is downloaded. Try again."
			rm -f "$scriptDir/IORegistryExplorer.zip"
			exit
		fi
	else
		echo -e "Download of IORegistryExplorer failed. Try again."
		exit
	fi

fi

# Check for patchmatic
if [[ $(which patchmatic) = "" ]];
	then
	echo -e "Patchmatic not installed. Checking in script directory."
	if [[ ! -e $patchmaticB ]];
		then
		echo -e "Patchmatic not found in script directory."
		if [ $checkForConnAhead -eq 1 ];
			then
			checkConn &>/dev/null # If no connection found, script will terminate here.
		fi

		# Stuffs to do in case internet connectivity is fine
		echo -e "Downloading Patchmatic."
		curl -o "$patchmaticB" $patchmaticBURL &>/dev/null

		# Check integrity of downloaded file.
		if [[ -e $"patchmaticB" ]];
			then
			echo -e "Downloaded Patchmatic."
			echo -e "Verifying downloaded file."
			if [[ $(echo $(md5 "$patchmaticB") | sed 's/.*= //g') = a295cf066a74191a36395bbec4b5d4a4 ]];
				then
				echo -e "File verified."
				echo -e "It resides at $patchmaticB"
			else
				echo -e "Verification failed. Try again."
				rm -f $"patchmaticB"
				exit
			fi
		fi
	else
		echo -e "Binary found in script directory."
		checkForConnAhead=1
	fi
else
	echo -e "Found patchmatic at $(which patchmatic)"
	patchmaticB=$(which patchmatic)
	checkForConnAhead=1
fi

# Start dumping the data, start by creating dirs
if [[ -e "$outDir" ]];
	then
	rm -rf "$outDir"
else
	mkdir -p "$outDir"
fi

# Now we listen for interrupts and then cleanup in case we need to exit prematurely.
trap '{

read -p "Hey, you pressed Ctrl+C. Quit?[yY/nN]: " quitResp ;
case $quitResp in
	[yY]* )
		echo "Umm.. Okay. Cleaning up and exiting, NOW!"
		rm -rf $outDir
		exit 1
		;;
	* )
		# Continue
		echo "Ah! Okay. Continuing then.."
		;;
esac

}' INT

# Change active directory to $outDir
cd "$outDir"
echo -e "Data will be dumped at $outDir"

# Request root access
isRoot=$(sudo id -u 2>/dev/null)
if [[ $isRoot != 0 ]]; then
	echo "Root access failed. Aborting...."
	rm -rf $outDir
	exit -1
fi

# Extract loaded tables using patchmatic
echo -e "Dumping loaded ACPI tables."
mkdir patchmatic_extraction
cd ./patchmatic_extraction
chmod a+x "$patchmaticB"
"$patchmaticB" -extract
cd ..
echo -e "Dumped loaded ACPI tables."

# Dump opencore files
echo -e "Dumping OpenCore files."
efiloc="$(sudo "$efiScript")"
echo -e "Mounted EFI at $efiloc"
if [[ -e "$efiloc/EFI/OC" ]]; then
	cp -prf "$efiloc/EFI/OC" .
	echo -e "Masking your System IDs"
	$pledit -c "Set PlatformInfo:Generic:MLB $maskedVal" OC/config.plist &>/dev/null
	$pledit -c "Delete PlatformInfo:Generic:ROM" OC/config.plist &>/dev/null
	$pledit -c "Add PlatformInfo:Generic:ROM string $maskedVal" OC/config.plist &>/dev/null
	$pledit -c "Set PlatformInfo:Generic:SystemSerialNumber $maskedVal" OC/config.plist &>/dev/null
	$pledit -c "Set PlatformInfo:Generic:SystemUUID $maskedVal" OC/config.plist &>/dev/null
	echo -e "Dump of OpenCore files completed successfully."
else
	echo "OpenCore not installed. Skipping..."
	hasOpenCore="no"
	touch OpenCoreNotInstalled "$outDir"
fi

echo -e "Unmounted $efiloc"
diskutil unmount $efiloc &>/dev/null

# Dumping system logs
echo -e "Dumping System log."
cp /var/log/system.log .

# Dump kernel panics (if exists)
dumpPanicLog

# Dumping kernel log
echo -e "Dumping kernel log."
dumpKernelLog &> kernel_log.txt

# Dumping kextstat
echo -e "Dumping kextstat."
touch kextstat_log.txt
dumpKextstat &>kextstat_log.txt
dumpAllKextstat &>kextstat_all_log.txt

# Dump LILU logs
dumpLilu

# Dump IOREG
echo -e "Dumping IOREG."
dumpIOREG

# Dump System Profile if user has asked so
if [[ "$genSysDump" == "yes" ]]; then
	echo "Generating system info, this may take a while."
	genSystemRep $2
else
	echo -e "System dump not requested.\nYou may use gen_debug -sysprofile to generate system dump."
	echo -e "For output in TXT format use: \"gen_debug -sysprofile txt\". Default format is SPX"
fi

# Dump boot log
echo "Dumping Boot log"
dumpBootLog

# Dump NVRAM
echo "Dumping NVRAM values..."
dumpNVRAM > nvram.plist

# Zip all the files
cd "$outDir"
echo -e "Zipping all the files"
zip -r $zipFileName * &>/dev/null
echo -e "Zipped files at: $outDir/debug_$randomNumber.zip"

# Ask to open the out directory.
read -p "Dump complete. Open $outDir?(Yy/Nn) " readOut
case $readOut in
	[yY]|[yY][eE][sS] )
		open "$outDir"
		;;
	[nN]|[nN][oO] )
		echo -e "Okay. You can open it manually."
		;;
	* )
		echo -e "Invalid option selected. Open manually."
		;;
esac

# Say Thank You!
echo -e "Thank You! Hope your problem gets sorted out soon."
exit
