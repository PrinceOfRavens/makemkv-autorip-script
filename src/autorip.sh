#!/bin/bash


# Defining variables for later use
SCRIPTROOT="$(dirname """$(realpath "$0")""")"
LOGROOT="/tmp/autorip"
LICENSEKEY="$(awk '/^license/{print $1}' "$SCRIPTROOT/settings.cfg" | cut -d '=' -f2)"
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
if [ -d "$LOGROOT/logs" ]; then
	:
else
	echo "[ERROR]: Log directory under $LOGROOT/logs is missing! Trying to create it."
	mkdir -p "$LOGROOT/logs"
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
	makemkvcon mkv --messages="${LOGROOT}/logs/${NOWDATE}_$DISKTITLERAW.log" --noscan --robot $ARGS disc:"$SOURCEMMKVDRIVE" all "${OUTPUTDIR}/${DISKTITLE}"
	if [ $? -le 1 ]; then
		echo "[INFO] $drive: Ripping finished (exit code $?), ejecting"
	else
		echo "[ERROR] $drive: RIPPING FAILED (exit code $?), ejecting. Please check the logs under ${LOGROOT}/logs/${NOWDATE}_${DISKTITLERAW}.log"
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
				ripper "$drive";
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
			# What to do when none of the above was the case
			*)
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
fi


makemkvcon reg $LICENSEKEY


# Initial search for drives
mapfile -t drives < <(ls /dev/sr*)
echo "----------------------------"
printf "Found the following devices:\n"
printf '%s\n' "${drives[@]}"
echo "----------------------------"

# Start parallelized jobs for every drive found
for drive in "${drives[@]}"; do discstatus "$drive" & done

# Wait for all jobs to be finished (which will never be the case), but this way you can actually stop the script using "CTRL + C"
wait < <(jobs -p)
