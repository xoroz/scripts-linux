#!/bin/bash

# script to download audio from youtube
#
# be sure to have the python library youtube-dl installed and updated
# by default files will be save to $HOME\Downloads\mp3\ DIR

## EDIT HERE
U="felix"
DF="/home/$U/Downloads/mp3"
##

if [ -z $1 ]; then
 echo "Please pass the youtube ID as arg, can use multiple ids too"
 echo "Ex: $(basename "$0" ) o0gJPYglhuQ o0gJPYglhuQ"
 exit 2
fi

if [ ! -d $DF ]; then
 mkdir -p $DF
fi

cd $DF

#Go thru all agruments and try to download and convert
for id in "$@"
do
    #check if viedo exists
    echo "Checking: https://www.youtube.com/watch?v=$id"
    C=$(curl -s  -I "https://www.youtube.com/watch?v=$id" |head -n 1|grep -c 200)
    if [ $C -ne 1 ]; then
     echo "Could not find the URL "https://www.youtube.com/watch?v=$id""
     break;
    fi
    FILENAME=$(youtube-dl --get-filename -o '%(title)s.%(ext)s' --restrict-filenames $id)
    FILENAME=$(echo $FILENAME|awk -F"." '{print $1}'| cut -c 1-30)
    FILENAME="${FILENAME}"
    echo "Downloading $id NAME: $FILENAME"
    if [ -z "$FILENAME" ]; then
     echo "NAME will be $id"
     FILENAME="${id}"
    fi
    echo "Downloading $id NAME: $FILENAME"

    if [ -f "${FILENAME}" ]; then
    	echo "Skipping - $FILENAME already exists"
    	continue;
    fi
    
    echo -e "\n\n --> Downloading $id NAME: $FILENAME"
    if [ ! -f "${FILENAME}" ]; then
     youtube-dl  -x --ffmpeg-location /usr/bin/ffmpeg -o $FILENAME.m.1 --restrict-filenames --no-part --audio-format mp3 --audio-quality 0 $id

#      mv -f $FILENAME.m.mp3 $FILENAME.mp3
    fi
done
chown $U -R $DF
exit 0
