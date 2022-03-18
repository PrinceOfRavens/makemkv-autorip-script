#!/bin/bash


# Defining variables for later use
SCRIPTROOT="$(dirname """$(realpath "$0")""")"
CACHE="$(awk '/^cache/{print $1}' "$SCRIPTROOT/settings.cfg" | cut -d '=' -f2)"
DEBUG="$(awk '/^debug/{print $1}' "$SCRIPTROOT/settings.cfg" | cut -d '=' -f2)"
MINLENGTH="$(awk '/^minlength/{print $1}' "$SCRIPTROOT/settings.cfg" | cut -d '=' -f2)"
OUTPUTDIR="$(awk '/^outputdir/{print $1}' "$SCRIPTROOT/settings.cfg" | cut -d '=' -f2 | xargs)"
CURRENTVERSION="$(awk '/^version/{print $1}' "$SCRIPTROOT/settings.cfg" | cut -d '=' -f2)"
LATESTVERSION=$(curl "https://forum.makemkv.com/forum/viewtopic.php?f=3&t=224" -s | xmllint --html --nowarning --xpath "//title/text()" - 2>/dev/null | awk '{print $2}')
ARGS=""


# Construct the arguments for later use
if [ -d "$OUTPUTDIR" ]; then
	:
else
	echo "[ERROR]: The output directory specified in settings.conf is invalid!"
	exit 1
fi
if [ -d "$SCRIPTROOT/logs" ]; then
	:
else
	echo "[ERROR]: Log directory under $SCRIPTROOT/logs is missing! Trying to create it."
	mkdir "$SCRIPTROOT/logs"
	exit 1
fi

if [ -z "$CACHE" ]; then
	if [ "$CACHE" = "-1" ]; then
		:
	elif [[ "$CACHE" =~ ^[0-9]+$ ]]; then
		ARGS="--cache=$CACHE"
	fi
fi
if [ "$DEBUG" = "true" ]; then
	ARGS="$ARGS --debug"
fi
if [[ "$MINLENGTH" =~ ^[0-9]+$ ]]; then
	ARGS="$ARGS --minlength=$MINLENGTH"
else
	ARGS="$ARGS --minlength=0"
fi


ripper() {
	# Match unix drive name to Make-MKV drive number and check it
	SOURCEMMKVDRIVE=$(makemkvcon --robot --noscan --cache=1 info disc:9999 | grep "$drive" | grep -o -E '[0-9]+' | head -1)
	if [ -z "$SOURCEMMKVDRIVE" ]; then
		echo "[ERROR] $drive: Make-MKV Source Drive is not defined."
		exit 1
	fi

	echo "[INFO] $drive: Started ripping process"

	#Extract DVD Title from Drive

	DISKTITLERAW=$(blkid -o value -s LABEL "$drive")
	DISKTITLERAW=${DISKTITLERAW// /_}
	NOWDATE=$(date +"%F_%H-%M-%S")
	DISKTITLE="${DISKTITLERAW}_-_$NOWDATE"


	mkdir "$OUTPUTDIR/$DISKTITLE"
	makemkvcon mkv --messages="${SCRIPTROOT}/logs/${NOWDATE}_$DISKTITLERAW.log" --noscan --robot $ARGS disc:"$SOURCEMMKVDRIVE" all "${OUTPUTDIR}/${DISKTITLE}"
	if [ $? -le 1 ]; then
		echo "[INFO] $drive: Ripping finished (exit code $?), ejecting"
	else
		echo "[ERROR] $drive: RIPPING FAILED (exit code $?), ejecting. Please check the logs under ${SCRIPTROOT}/logs/${NOWDATE}_${DISKTITLERAW}.log"
	fi
	eject "$drive"
}


# Create template for forking
discstatus () {
	while true; do
		# Getting the current disc status
		discinfo=$(setcd -i "$drive" 2> /dev/null)

		case "$discinfo" in
			# What to do when the disc is found and ready
			*'Disc found'*)
				echo "[INFO] $drive: disc is ready" >&2;
				unset repeatnodisc;
				unset repeatemptydisc;
				/bin/bash "$SCRIPTROOT/autorip.sh" "$drive";
				sleep 10;
				;;
			# What to do when the disc is found, but not yet ready
			*'not ready'*)
				echo "[INFO] $drive: waiting for drive to be ready" >&2;
				unset repeatemptydisc;
				sleep 5;
				;;
			# What to do when the drive tray is open
			*'is open'*)
				if [[ $repeatemptydisc -lt 3 ]]; then
					echo "[INFO] $drive: drive is open" >&2
					repeatemptydisc=$((repeatemptydisc+1))
				fi;
				sleep 5;
				;;
			# What to do when the drive tray is closed, but no disc was recognized
			*'No disc is inserted'*)
				if [[ $repeatnodisc -lt 3 ]]; then
					echo "[WARN] $drive: drive tray is empty" >&2
					repeatnodisc=$((repeatnodisc+1))
				fi;
				unset repeatemptydisc;
				sleep 15;
				;;
			*)
			# What to do when none of the above was the case
				echo "[ERROR] $drive: Confused by setcd -i, bailing out" >&2;
				unset repeatemptydisc;
				eject "$drive"
		esac
	done
}



# Check for new MakeMKV version
if [ $LATESTVERSION -ne $CURRENTVERSION ]; then
	echo "|@|--------------------------------------|@|"
	echo "|@|@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@|"
	echo "|@|--------------------------------------|@|"
	echo "|@|                                      |@|"
	echo "|@|    Your Version of MakeMKV is Old    |@|"
	echo "|@|                                      |@|"
	echo "|@|--------------------------------------|@|"
	echo "|@|@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@|@|"
	echo "|@|--------------------------------------|@|"
	$SCRIPTROOT/install-makemkv.sh
fi


# Initial search for drives
mapfile -t drives < <(ls /dev/sr*)
echo "----------------------------"
printf "Found the following devices:\n"
printf '%s\n' "${drives[@]}"
echo "----------------------------"



















# Defining variables for later use
SOURCEDRIVE="$1"
SCRIPTROOT="$(dirname """$(realpath "$0")""")"
CACHE="$(awk '/^cache/{print $1}' "$SCRIPTROOT/settings.cfg" | cut -d '=' -f2)"
DEBUG="$(awk '/^debug/{print $1}' "$SCRIPTROOT/settings.cfg" | cut -d '=' -f2)"
MINLENGTH="$(awk '/^minlength/{print $1}' "$SCRIPTROOT/settings.cfg" | cut -d '=' -f2)"
OUTPUTDIR="$(awk '/^outputdir/' "$SCRIPTROOT/settings.cfg" | cut -d '=' -f2 | cut -f1 -d"#" | xargs)"
ARGS=""

# Check if the source drive has actually been set and is available
if [ -z "$SOURCEDRIVE" ]; then
	echo "[ERROR] Source Drive is not defined."
	echo "        When calling this script manually, make sure to pass the drive path as a variable: ./autorip.sh [DRIVE]"
	exit 1
fi
setcd -i "$SOURCEDRIVE" | grep --quiet 'Disc found'
if [ ! $? ]; then
        echo "[ERROR] $SOURCEDRIVE: Source Drive is not available."
        exit 1
fi

# Construct the arguments for later use
if [[ $OUTPUTDIR == ""\~*"" ]]; then
	if [[ $OUTPUTDIR == ""\~/*"" ]]; then
		OUTPUTDIR=$(echo "$(eval echo ~"${SUDO_USER:-$USER}")/${OUTPUTDIR:2}" | sed 's:/*$::')
	else
		OUTPUTDIR="$(eval echo ~"${SUDO_USER:-$USER}")"
	fi
fi
if [ -d "$OUTPUTDIR" ]; then
	:
else
	echo "[ERROR]: The output directory specified in settings.conf is invalid!"
	exit 1
fi
if [ -d "$SCRIPTROOT/logs" ]; then
	:
else
	echo "[ERROR]: Log directory under $SCRIPTROOT/logs is missing! Trying to create it."
	mkdir "$SCRIPTROOT/logs"
	exit 1
fi

if [ -z "$CACHE" ]; then
	if [ "$CACHE" = "-1" ]; then
		:
	elif [[ "$CACHE" =~ ^[0-9]+$ ]]; then
		ARGS="--cache=$CACHE"
	fi
fi
if [ "$DEBUG" = "true" ]; then
	ARGS="$ARGS --debug"
fi
if [[ "$MINLENGTH" =~ ^[0-9]+$ ]]; then
	ARGS="$ARGS --minlength=$MINLENGTH"
else
	ARGS="$ARGS --minlength=0"
fi

# Match unix drive name to Make-MKV drive number and check it
SOURCEMMKVDRIVE=$(makemkvcon --robot --noscan --cache=1 info disc:9999 | grep "$SOURCEDRIVE" | grep -o -E '[0-9]+' | head -1)
if [ -z "$SOURCEMMKVDRIVE" ]; then
	echo "[ERROR] $SOURCEDRIVE: Make-MKV Source Drive is not defined."
	exit 1
fi

echo "[INFO] $SOURCEDRIVE: Started ripping process"

#Extract DVD Title from Drive

DISKTITLERAW=$(blkid -o value -s LABEL "$SOURCEDRIVE")
DISKTITLERAW=${DISKTITLERAW// /_}
NOWDATE=$(date +"%F_%H-%M-%S")
DISKTITLE="${DISKTITLERAW}_-_$NOWDATE"


mkdir "$OUTPUTDIR/$DISKTITLE"
makemkvcon mkv --messages="${SCRIPTROOT}/logs/${NOWDATE}_$DISKTITLERAW.log" --noscan --robot $ARGS disc:"$SOURCEMMKVDRIVE" all "${OUTPUTDIR}/${DISKTITLE}"
if [ $? -le 1 ]; then
	echo "[INFO] $SOURCEDRIVE: Ripping finished (exit code $?), ejecting"
else
	echo "[ERROR] $SOURCEDRIVE: RIPPING FAILED (exit code $?), ejecting. Please check the logs under ${SCRIPTROOT}/logs/${NOWDATE}_${DISKTITLERAW}.log"
fi
eject "$SOURCEDRIVE"
