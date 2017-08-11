#!/bin/bash

###############################################################################
# To all DEV around the world :)                                              #
#                                                                             #
# 1.) use the "bash"                                                          #
# chsh -s /bin/bash `whoami`                                                  #
#                                                                             #
# 2.) load the ".config"                                                      #
# ./load_config.sh                                                            #
#                                                                             #
# 3.) clean the sources                                                       #
# ./clean_kernel.sh                                                           #
#                                                                             #
# 4.) now you can build my kernel                                             #
# ./build_kernel.sh                                                           #
#                                                                             #
# Have fun and update me if something nice can be added to my source.         #
###############################################################################

# language
LANG=C;

# location
if [ "${1}" != "" ]; then
	export KERNELDIR=`readlink -f ${1}`;
else
	export KERNELDIR=`readlink -f .`;
fi;

export PARENT_DIR=`readlink -f ${KERNELDIR}/..`;
export INITRAMFS_SOURCE=`readlink -f ${KERNELDIR}/../initramfs3`;
export INITRAMFS_TMP=/tmp/initramfs_source;

# kernel
export ARCH=arm;
export USE_SEC_FIPS_MODE=true;
export KERNEL_CONFIG=dorimanx_defconfig;

# build script
export USER=`whoami`;
export HOST=`uname -n`;
export TMPFILE=`mktemp -t`;

chmod -R 777 /tmp;

# system compiler
# gcc x.x.x
# export CROSS_COMPILE=$PARENT_DIR/toolchain/bin/arm-none-eabi-;

# gcc 4.8.3 (Linaro 2013.x)
export CROSS_COMPILE=$KERNELDIR/android-toolchain/bin/arm-eabi-;

# importing PATCH for GCC depend on GCC version
GCCVERSION=`./scripts/gcc-version.sh ${CROSS_COMPILE}gcc`;

# check xml-config for "STweaks"-app
XML2CHECK="${INITRAMFS_SOURCE}/res/customconfig/customconfig.xml";
xmllint --noout $XML2CHECK;
if [ $? == 1 ]; then
	echo "xml-Error: $XML2CHECK";
	exit 1;
fi;
echo "Detected gcc version";
echo  "a$GCCVERSION";
# compiler detection
if [ "a$GCCVERSION" == "a0409" ]; then
	cp $KERNELDIR/arch/arm/boot/compressed/Makefile_linaro $KERNELDIR/arch/arm/boot/compressed/Makefile;
	echo "GCC 4.9.X Compiler Detected, building";
elif [ "a$GCCVERSION" == "a0504" ]; then
	cp $KERNELDIR/arch/arm/boot/compressed/Makefile_linaro $KERNELDIR/arch/arm/boot/compressed/Makefile;
	echo "GCC 5.4.x Compiler Detected, building";
elif [ "a$GCCVERSION" == "a0601" ]; then
	cp $KERNELDIR/arch/arm/boot/compressed/Makefile_linaro $KERNELDIR/arch/arm/boot/compressed/Makefile;
	echo "GCC 6.1.x Compiler Detected, building";
else
	echo "Compiler not recognized! please fix the 'build_kernel.sh'-script to match your compiler.";
	exit 0;
fi;

# dorimanx detection ;)
if [ $HOST == "dorimanx-virtual-machine" ] || [ $HOST == "dorimanx" ]; then
	NR_CPUS=16;
	echo "Dori power detected!";
else
	NR_CPUS=$(expr `grep processor /proc/cpuinfo | wc -l`);
	if [ "$NR_CPUS" -lt 2 ]; then
		(( NR_CPUS=2 ))
	fi;
	echo "not dorimanx system detected, setting $NR_CPUS build threads"
fi;

# copy config
if [ ! -f $KERNELDIR/.config ]; then
	cp $KERNELDIR/arch/arm/configs/$KERNEL_CONFIG $KERNELDIR/.config;
fi;

# read config
. $KERNELDIR/.config;

# get version from config
GETVER=`grep 'Dorimanx-*-V' .config | sed 's/.*".//g' | sed 's/-N.*//g'`;

# remove previous zImage files
if [ -e $KERNELDIR/zImage ]; then
	rm $KERNELDIR/zImage;
fi;
if [ -e $KERNELDIR/arch/arm/boot/zImage ]; then
	rm $KERNELDIR/arch/arm/boot/zImage;
fi;

# remove previous initramfs files
if [ -d $INITRAMFS_TMP ]; then
	echo "removing old temp initramfs_source";
	rm -rf $INITRAMFS_TMP;
fi;

# clean initramfs old compile data
rm -f $KERNELDIR/usr/initramfs_data.cpio;
rm -f $KERNELDIR/usr/initramfs_data.o;

# copy new config
cp $KERNELDIR/.config $KERNELDIR/arch/arm/configs/$KERNEL_CONFIG;

# remove all old modules before compile
for i in `find $KERNELDIR/ -name "*.ko"`; do
	rm -f $i;
done;

# copy initramfs files to tmp directory
cp -dxPR $INITRAMFS_SOURCE $INITRAMFS_TMP;

# create new image with version & date
echo "0" > $TMPFILE;
(
	./kernel_logo.sh;
)&

# make modules
mkdir -p $INITRAMFS_TMP/lib/modules;
make -j${NR_CPUS} KALLSYMS_EXTRA_PASS=1 modules || exit 1;

# clear git repository from tmp-initramfs
if [ -d $INITRAMFS_TMP/.git ]; then
	rm -rf $INITRAMFS_TMP/.git;
fi;
rm -f $INITRAMFS_TMP/.gitignore;

# clear mercurial repository from tmp-initramfs
if [ -d $INITRAMFS_TMP/.hg ]; then
	rm -rf $INITRAMFS_TMP/.hg;
fi;

# remove empty directory placeholders from tmp-initramfs
for i in `find $INITRAMFS_TMP -name EMPTY_DIRECTORY`; do
	rm -f $i;
done;

# remove more from from tmp-initramfs ...
rm -f $INITRAMFS_TMP/check_ramdisk_size.sh;
rm -f $INITRAMFS_TMP/update*;

# copy modules into tmp-initramfs
mkdir -p $INITRAMFS_TMP/lib/modules;
for i in `find $KERNELDIR -name '*.ko'`; do
	cp -av $i $INITRAMFS_TMP/lib/modules/;
done;
for i in `find $INITRAMFS_TMP/lib/modules/ -name '*.ko'`; do
	${CROSS_COMPILE}strip --strip-unneeded $i;
done;
for i in `find $INITRAMFS_TMP/lib/modules/ -name '*.ko'`; do
        ${CROSS_COMPILE}strip --strip-debug $i;
done;
chmod 755 $INITRAMFS_TMP/lib/modules/*;

md5sum $INITRAMFS_TMP/res/misc/payload/STweaks.apk | awk '{print $1}' > $INITRAMFS_TMP/res/stweaks_md5;
chmod 644 $INITRAMFS_TMP/res/stweaks_md5;

# wait for the boot-image
while [ $(cat ${TMPFILE}) == 0 ]; do
	sleep 2;
	echo "wait for image ...";
done;

# to check section mismatch add to make this
# CONFIG_DEBUG_SECTION_MISMATCH=y

# make kernel!!!
time make -j $NR_CPUS KALLSYMS_EXTRA_PASS=1 zImage CONFIG_INITRAMFS_SOURCE="$INITRAMFS_TMP";

# restore clean arch/arm/boot/compressed/Makefile_clean till next time
cp $KERNELDIR/arch/arm/boot/compressed/Makefile_clean $KERNELDIR/arch/arm/boot/compressed/Makefile;

if [ -e $KERNELDIR/arch/arm/boot/zImage ]; then
	cp $KERNELDIR/.config $KERNELDIR/arch/arm/configs/$KERNEL_CONFIG;
	cp $KERNELDIR/arch/arm/boot/zImage $KERNELDIR/;

	# clean old files ...
	rm $KERNELDIR/READY/boot/zImage;
	rm $KERNELDIR/READY/Kernel_*;

	# copy all needed to ready kernel folder
	cp $KERNELDIR/.config $KERNELDIR/READY/;
	stat $KERNELDIR/zImage || exit 1;
	cp $KERNELDIR/zImage /$KERNELDIR/READY/boot/;

	# create zip-file for kernel. kernel zip name is based on toolchain used, modify to however you like
	cd $KERNELDIR/READY/ && zip -r Kernel_${GETVER}-`date +"[%H-%M]-[%d-%m]-LOS14.1-SGII-SABER"`.zip .;
else
	# with red-color
	echo -e "\e[1;31mKernel STUCK in BUILD! no zImage exist\e[m"
fi;
