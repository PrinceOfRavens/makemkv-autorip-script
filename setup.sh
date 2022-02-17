#!/bin/bash


scriptroot=$(dirname "$(realpath "$0")")
userhome=$(eval echo ~"${SUDO_USER:-$USER}")
mountTarget="~/Videos"


sudo apt update
sudo apt upgrade -y


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

	sudo apt install -y cifs-utils
	sudo mkdir $mountTarget
	echo "username=${uservar}" | sudo tee -a /root/.smb_credentials
	echo "password=${passvar}" | sudo tee -a /root/.smb_credentials
	sudo chmod 400 /root/.smb_credentials
	sudo mount -t cifs -o rw,vers=3.0,credentials=/root/.smb_credentials $mountSource $mountTarget
	echo "${mountSource} ${mountTarget} cifs rw,vers=3.0,credentials=/root/.smb_credentials" | sudo tee -a /etc/fstab
}


install_ffmpeg_makemkv() {
	echo
	echo '############################################'
	echo '##  Installing Libraries and Build Tools  ##'
	echo '############################################'
	echo
	sudo apt install -y build-essential pkg-config libc6-dev libssl-dev libexpat1-dev libavcodec-dev libgl1-mesa-dev qtbase5-dev zlib1g-dev nasm libfdk-aac-dev sed wget curl tar setcd
	
	
	echo
	echo '#########################'
	echo '##  Installing FFMPEG  ##'
	echo '#########################'
	echo
	mkdir $userhome/ffmpeg
	cd $userhome/ffmpeg
	wget https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
	tar -xvjf ffmpeg-snapshot.tar.bz2
	cd ffmpeg
	./configure --prefix=/tmp/ffmpeg --enable-static --disable-shared --enable-pic --enable-libfdk-aac
	make install
	
	echo
	echo '##########################'
	echo '##  Installing MakeMKV  ##'
	echo '##########################'
	echo
	mkdir $userhome/makemkv
	cd $userhome/makemkv
	wget https://www.makemkv.com/download/makemkv-oss-1.16.5.tar.gz
	tar -xvzf makemkv-oss-1.16.5.tar.gz
	cd makemkv-oss-1.16.5
	PKG_CONFIG_PATH=/tmp/ffmpeg/lib/pkgconfig ./configure
	make
	sudo make install
	
	cd $userhome/makemkv
	wget https://www.makemkv.com/download/makemkv-bin-1.16.5.tar.gz
	tar -xvzf makemkv-bin-1.16.5.tar.gz
	cd makemkv-bin-1.16.5
	make
	sudo make install
	
	rm -rf /tmp/ffmpeg
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

	#licenseHolder="000000000000"
	#sed -i "s/$licenseHolder/$licenseKey/" "$scriptroot/settings.cfg"
	
	/usr/bin/makemkvcon reg $licenseKey

	presetDir="~/Videos"
	sed -i "s/$presetDir/$mountTarget/" "$scriptroot/settings.cfg"

	#echo 'apt_Key = "Holder"' | sudo tee -a $userhome/.MakeMKV/update.conf

	chmod +x $scriptroot/wrapper.sh
}


daemon_service() {
	echo
	echo '###############################'
	echo '##  Creating Autorip Daemon  ##'
	echo '###############################'
	echo
	echo "[Unit]" | sudo tee -a /lib/systemd/system/autorip.service
	echo "Description=MakeMKV Autorip Script" | sudo tee -a /lib/systemd/system/autorip.service
	echo "" | sudo tee -a /lib/systemd/system/autorip.service
	echo "[Service]" | sudo tee -a /lib/systemd/system/autorip.service
	echo "User=$USER" | sudo tee -a /lib/systemd/system/autorip.service
	echo "ExecStart=sudo $userhome/autorip/wrapper.sh" | sudo tee -a /lib/systemd/system/autorip.service
	echo "" | sudo tee -a /lib/systemd/system/autorip.service
	echo "[Install]" | sudo tee -a /lib/systemd/system/autorip.service
	echo "WantedBy=multi-user.target" | sudo tee -a /lib/systemd/system/autorip.service

	sudo systemctl daemon-reload
	sudo systemctl enable autorip.service
	sudo systemctl start autorip.service
}


mount_share
install_ffmpeg_makemkv
autorip_setup
daemon_service
