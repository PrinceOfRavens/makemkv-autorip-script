#!/bin/bash


latestVersion=$(curl "https://forum.makemkv.com/forum/viewtopic.php?f=3&t=224" -s | xmllint --html --nowarning --xpath "//title/text()" - 2>/dev/null | awk '{print $2}')
	
echo
echo '################################'
echo "##  Installing MakeMKV ${latestVersion}  ##"
echo '################################'
echo

latestVersion=$(curl "https://forum.makemkv.com/forum/viewtopic.php?f=3&t=224" -s | xmllint --html --nowarning --xpath "//title/text()" - 2>/dev/null | awk '{print $2}')

rm -f $userhome/makemkv
mkdir $userhome/makemkv
cd $userhome/makemkv
wget https://www.makemkv.com/download/makemkv-oss-1.16.5.tar.gz
tar -xvzf makemkv-oss-1.16.5.tar.gz
cd makemkv-oss-1.16.5
PKG_CONFIG_PATH=/tmp/ffmpeg/lib/pkgconfig ./configure
make
echo "$secretPass" | sudo -S make install
	
cd $userhome/makemkv
wget https://www.makemkv.com/download/makemkv-bin-1.16.5.tar.gz
tar -xvzf makemkv-bin-1.16.5.tar.gz
cd makemkv-bin-1.16.5
make
echo "$secretPass" | sudo -S make install
	
rm -rf /tmp/ffmpeg
	
echo "$secretPass" | sudo -S apt install default-jre