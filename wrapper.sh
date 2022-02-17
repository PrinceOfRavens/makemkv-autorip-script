#!/bin/bash
if [ "$USER" != root ] && [ "$SUDO_USER" != root ]; then
	echo "This script needs to be executed with sudo!"
	exit 1
fi

scriptroot=$(dirname "$(realpath "$0")")
userhome=$(eval echo ~"${SUDO_USER:-$USER}")


# Update license key from settings.cfg to ~/.MakeMKV/update.conf MANUALLY
newlicense="$(awk '/^license/{print $1}' "$scriptroot/settings.cfg" | cut -d '=' -f2)"
oldlicense="$(awk '/^app_Key/{print $3}' "$userhome/.MakeMKV/update.conf" | cut -d '=' -f2 | xargs)"
sed -i "s/$oldlicense/$newlicense/" "$userhome/.MakeMKV/update.conf"

# Update license key automatically from website to ~/.MakeMKV/update.conf AUTOMATICALLY
#
# newlicense="$(curl -sL https://www.makemkv.com/forum/viewtopic.php?t=1053 | grep -o -P '(?<=\<code\>).*(?=\<\/code\>)')"
# oldlicense="$(awk '/^app_Key/{print $3}' "$userhome/.MakeMKV/update.conf" | cut -d '=' -f2 | xargs)"
# sed -i "s/$oldlicense/$newlicense/" "$userhome/.MakeMKV/update.conf"

# Initial search for drives
mapfile -t drives < <(ls /dev/sr*)
echo "----------------------------"
printf "Found the following devices:\n"
printf '%s\n' "${drives[@]}"
echo "----------------------------"

# Eject all drives to indicate startup
for drive in "${drives[@]}"; do eject "$drive" & done

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
				/bin/bash "$scriptroot/autorip.sh" "$drive";
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

# Start parallelized jobs for every drive found
for drive in "${drives[@]}"; do discstatus "$drive" & done

# Wait for all jobs to be finished (which will never be the case), but this way you can actually stop the script using "CRTL + C"
wait < <(jobs -p)
