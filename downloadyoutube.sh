#!/bin/bash
# bash script to download youtube video and convert to mp3 audio
#
# be sure to have the python library youtube-dl installed and updated
# by default files will be save to $HOME\Downloads\mp3\ DIR
## EDIT HERE
U=felix
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
    C=$(curl -s  -I https://www.youtube.com/watch?v=$id |head -n 1|grep -c 200)
    if [ $C -ne 1 ]; then
     echo "Could not find the URL "https://www.youtube.com/watch?v=$id""
     break;
    fi
    FILENAME=$(youtube-dl --get-filename -o '%(title)s.%(ext)s' --restrict-filenames $id)
    FILENAME=$(echo $FILENAME|awk -F"." '{print $1}'| cut -c 1-30)
    FILENAME="${FILENAME}.mp3"
    echo "Downloading $id NAME: $FILENAME"
    if [ -z "$FILENAME" ]; then
     echo "NAME will be $id"
     FILENAME="${id}.mp3"
    fi
    echo "Downloading $id NAME: $FILENAME"

    if [ -f "${FILENAME}" ]; then
    	echo "Skipping - $FILENAME already exists"
    	continue;
    fi
    
    echo -e "\n\n --> Downloading $id NAME: $FILENAME"
    if [ ! -f "${FILENAME}" ]; then
     #youtube-dl -f bestaudio -o '%(title)s.%(ext)s' --restrict-filenames $id
     youtube-dl -f bestaudio -o $FILENAME --restrict-filenames $id

    fi
    echo -e "\n\n --> Converting $FILENAME to mp3"    
    ffmpeg -hide_banner -i $(find -type f -name "$FILENAME") -vn -stats -ab 128k -ar 44100 -y $MP3
    if [ -f "$FILENAME" ]; then
        FILESIZE=$(du -sh $FILENAME|awk '{ print $1}')
	echo " --> DONE: Audio file is ready at ${DF}${FILENAME} ( $FILESIZE )"
    else
        echo -e "\n\n\n --> ERROR - Something went wrong $FILENAME not found\n\n\n"         
    fi    	
done
chown $U -R $DF
exit 0
