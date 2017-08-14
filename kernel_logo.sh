#!/bin/bash
GETVER=`grep 'Dorimanx-V' .config | sed 's/.*".//g' | sed 's/-N.*//g'`;
boot_image=/tmp/initramfs_source/res/images/icon_clockwork.png;
convert -font ./Roboto-Regular.ttf -ordered-dither threshold,32,64,32 -pointsize 17 -fill white -gravity center -draw "text 0,380 \"$GETVER [`date "+%H:%M | %d.%m.%Y"| sed -e ' s/\"/\\\"/g' `]\"" $boot_image $boot_image;
#to gain more 100k for kernel stuff uncomment next line, but it's will take time to convert.
#optipng -o7 -quiet $boot_image;
echo "1" > $TMPFILE;

