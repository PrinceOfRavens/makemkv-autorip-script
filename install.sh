#!/bin/bash


latestVersion=""

scriptroot="/usr/share/autorip"
userhome=$(eval echo ~"${SUDO_USER:-$USER}")
mountTarget="/tmp/videos"


read -sp 'Please enter sudo password: ' secretPass


echo "$secretPass" | sudo -S apt update
echo "$secretPass" | sudo -S apt upgrade -y


mount_share() {
	echo
	echo '############################'
	echo '##  Mounting Share Drive  ##'
	echo '############################'
	echo
	echo Please enter your mount information
	echo
	read -p 'Mount Source: ' mountSource
	read -p 'Mount Target: ' mountTarget
	read -p 'Mount Username: ' uservar
	read -sp 'Mount Password: ' passvar
	echo

	echo "$secretPass" | sudo -S apt install -y cifs-utils
	echo "$secretPass" | sudo -S mkdir $mountTarget
	echo "username=${uservar}" | sudo tee -a /root/.smb_credentials
	echo "password=${passvar}" | sudo tee -a /root/.smb_credentials
	echo "$secretPass" | sudo -S chmod 400 /root/.smb_credentials
	echo "$secretPass" | sudo -S mount -t cifs -o rw,vers=3.0,credentials=/root/.smb_credentials $mountSource $mountTarget
	echo "${mountSource} ${mountTarget} cifs rw,vers=3.0,credentials=/root/.smb_credentials" | sudo tee -a /etc/fstab
}


install_ffmpeg_makemkv() {
	echo "$secretPass" | sudo -S install-makemkv
#	echo
#	echo '############################################'
#	echo '##  Installing Libraries and Build Tools  ##'
#	echo '############################################'
#	echo
#	echo "$secretPass" | sudo -S apt install -y build-essential pkg-config libc6-dev libssl-dev libexpat1-dev libavcodec-dev libgl1-mesa-dev qtbase5-dev zlib1g-dev nasm libfdk-aac-dev sed wget curl tar setcd libxml2-utils
#	
#	
#	echo
#	echo '#########################'
#	echo '##  Installing FFMPEG  ##'
#	echo '#########################'
#	echo
#
#	rm -f $userhome/ffmpeg
#	mkdir $userhome/ffmpeg
#	cd $userhome/ffmpeg
#	wget https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
#	tar -xvjf ffmpeg-snapshot.tar.bz2
#	cd ffmpeg
#	./configure --prefix=/tmp/ffmpeg --enable-static --disable-shared --enable-pic --enable-libfdk-aac
#	make install
#
#	latestVersion=$(curl "https://forum.makemkv.com/forum/viewtopic.php?f=3&t=224" -s | xmllint --html --nowarning --xpath "//title/text()" - 2>/dev/null | awk '{print $2}')
#	
#	echo
#	echo '################################'
#	echo "##  Installing MakeMKV ${latestVersion}  ##"
#	echo '################################'
#	echo
#
#	latestVersion=$(curl "https://forum.makemkv.com/forum/viewtopic.php?f=3&t=224" -s | xmllint --html --nowarning --xpath "//title/text()" - 2>/dev/null | awk '{print $2}')
#
#	rm -f $userhome/makemkv
#	mkdir $userhome/makemkv
#	cd $userhome/makemkv
#	wget https://www.makemkv.com/download/makemkv-oss-1.16.5.tar.gz
#	tar -xvzf makemkv-oss-1.16.5.tar.gz
#	cd makemkv-oss-1.16.5
#	PKG_CONFIG_PATH=/tmp/ffmpeg/lib/pkgconfig ./configure
#	make
#	echo "$secretPass" | sudo -S make install
#	
#	cd $userhome/makemkv
#	wget https://www.makemkv.com/download/makemkv-bin-1.16.5.tar.gz
#	tar -xvzf makemkv-bin-1.16.5.tar.gz
#	cd makemkv-bin-1.16.5
#	make
#	echo "$secretPass" | sudo -S make install
#	
#	rm -rf /tmp/ffmpeg
#	
#	echo "$secretPass" | sudo -S apt install default-jre
}


autorip_setup() {
	echo
	echo '##########################'
	echo '##  Setting Up Autorip  ##'
	echo '##########################'
	echo

	echo
	read -p 'MakeMKV Key: ' licenseKey
	echo
	
	#echo "$secretPass" | sudo -S /usr/bin/makemkvcon reg $licenseKey

	echo "$secretPass" | sudo -S rm -f $scriptroot/*
	echo "$secretPass" | sudo -S install -d $scriptroot
	echo "$secretPass" | sudo -S install -m 755 -t $scriptroot src/autorip.sh
	echo "$secretPass" | sudo -S install -m 755 -t $scriptroot src/install-makemkv.sh
	echo "$secretPass" | sudo -S install -m 666 -t $scriptroot src/settings.cfg
	echo "$secretPass" | sudo -S ln -s -f $scriptroot/autorip.sh /usr/bin/autorip
	echo "$secretPass" | sudo -S ln -s -f $scriptroot/install-makemkv.sh /usr/bin/install-makemkv

	presetDir="PLACEHOLDER"

	cp src/settings.cfg /tmp
	sed -i "s|$presetDir|$mountTarget|" /tmp/settings.cfg
	sed -i "s|000000000000|$licenseKey|" /tmp/settings.cfg
	echo "$secretPass" | sudo -S install -m 644 -t $scriptroot /tmp/settings.cfg
}

#!#
daemon_service() {
	echo
	echo '###############################'
	echo '##  Creating Autorip Daemon  ##'
	echo '###############################'
	echo
	
	#echo "[Unit]" | sudo tee -a /lib/systemd/system/autorip.service
	#echo "Description=MakeMKV Autorip Script" | sudo tee -a /lib/systemd/system/autorip.service
	#echo "" | sudo tee -a /lib/systemd/system/autorip.service
	#echo "[Service]" | sudo tee -a /lib/systemd/system/autorip.service
	#echo "User=$USER" | sudo tee -a /lib/systemd/system/autorip.service
	#echo "ExecStart=echo \"$secretPass\" | sudo -S $userhome/autorip/wrapper.sh" | sudo tee -a /lib/systemd/system/autorip.service
	#echo "" | sudo tee -a /lib/systemd/system/autorip.service
	#echo "[Install]" | sudo tee -a /lib/systemd/system/autorip.service
	#echo "WantedBy=multi-user.target" | sudo tee -a /lib/systemd/system/autorip.service

	echo "$secretPass" | sudo -S useradd -r -m autorip
	echo "$secretPass" | sudo -S adduser autorip cdrom
	echo "$secretPass" | sudo -S install -m 755 -t /etc/systemd/system src/autorip.service

	echo "$secretPass" | sudo -S systemctl daemon-reload
	echo "$secretPass" | sudo -S systemctl enable autorip.service
	echo "$secretPass" | sudo -S systemctl start autorip.service
}


mount_share
autorip_setup
install_ffmpeg_makemkv
daemon_service