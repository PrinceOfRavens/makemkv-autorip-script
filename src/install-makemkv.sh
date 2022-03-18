#!/bin/bash

TMP_PATH='/tmp/install'



if [ "$USER" != root ] && [ "$SUDO_USER" != root ]; then
	echo "This script needs to be executed with sudo!"
	exit 1
fi


if [-d $TMP_PATH]; then
    rm -rf $TMP_PATH
fi

mkdir $TMP_PATH




echo
echo '#########################'
echo '##  Installing FFMPEG  ##'
echo '#########################'
echo

mkdir $TMP_PATH/ffmpeg
cd $TMP_PATH/ffmpeg
wget https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2
tar -xvjf ffmpeg-snapshot.tar.bz2
cd ffmpeg
./configure --prefix=/tmp/ffmpeg --enable-static --disable-shared --enable-pic --enable-libfdk-aac
make install




latestVersion=$(curl "https://forum.makemkv.com/forum/viewtopic.php?f=3&t=224" -s | xmllint --html --nowarning --xpath "//title/text()" - 2>/dev/null | awk '{print $2}')

echo
echo '################################'
echo "##  Installing MakeMKV ${latestVersion}  ##"
echo '################################'
echo

mkdir $TMP_PATH/makemkv
cd $TMP_PATH/makemkv
wget https://www.makemkv.com/download/makemkv-oss-${latestVersion}.tar.gz
tar -xvzf makemkv-oss-${latestVersion}.tar.gz
cd makemkv-oss-${latestVersion}
PKG_CONFIG_PATH=/tmp/ffmpeg/lib/pkgconfig ./configure
make
make install
	
cd $TMP_PATH/makemkv
wget https://www.makemkv.com/download/makemkv-bin-${latestVersion}.tar.gz
tar -xvzf makemkv-bin-${latestVersion}.tar.gz
cd makemkv-bin-${latestVersion}
make
make install
	
rm -rf /tmp/ffmpeg
rm -rf $TMP_PATH