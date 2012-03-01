#!/bin/bash

setup ()
{
    if [ x = "x$ANDROID_BUILD_TOP" ] ; then
        echo "Android build environment must be configured"
        exit 1
    fi
    . "$ANDROID_BUILD_TOP"/build/envsetup.sh

    KERNEL_DIR="$(dirname "$(readlink -f "$0")")"
    BUILD_DIR="$KERNEL_DIR/build"
    #MODULES=("fs/cifs/cifs.ko" "fs/fuse/fuse.ko" "fs/nls/nls_utf8.ko")

    if [ ! -d $BUILD_DIR ]; then
        mkdir -p "$KERNEL_DIR/build"
    fi

    if [ x = "x$NO_CCACHE" ] && ccache -V &>/dev/null ; then
        CCACHE=ccache
        CCACHE_BASEDIR="$KERNEL_DIR"
        CCACHE_COMPRESS=1
        CCACHE_DIR="$BUILD_DIR/.ccache"
        export CCACHE_DIR CCACHE_COMPRESS CCACHE_BASEDIR
    else
        CCACHE=""
    fi

CROSS_PREFIX="$ANDROID_BUILD_TOP/prebuilt/linux-x86/toolchain/arm-eabi-4.4.3/bin/arm-eabi-"
}

build_zImage ()
{
    local target=$1
    echo "Building for $target"
    local target_dir="$BUILD_DIR/$target"
    local module
    mv $ANDROID_BUILD_TOP/kernel/samsung/initramfs/.git ~/DONOTLOOKATME
    mka -C "$KERNEL_DIR" O="$target_dir" ${target}\_cm9_defconfig HOSTCC="$CCACHE gcc"
    mka -C "$KERNEL_DIR" O="$target_dir" HOSTCC="$CCACHE gcc" CROSS_COMPILE="$CCACHE $CROSS_PREFIX" zImage modules
    cp "$target_dir"/arch/arm/boot/zImage $ANDROID_BUILD_TOP/device/samsung/galaxytab/kernel-$target
    mv ~/DONOTLOOKATME $ANDROID_BUILD_TOP/kernel/samsung/initramfs/.git
}

initrd_source_zImage ()
{
    sed -i "s|CONFIG_INITRAMFS_SOURCE=\".*\"|CONFIG_INITRAMFS_SOURCE=\"$ANDROID_BUILD_TOP/kernel/samsung/initramfs\"|" arch/arm/configs/*_cm9_defconfig
}

build_bootimg ()
{
    local target=$1
    echo "Building for $target"
    local target_dir="$BUILD_DIR/$target"
    local module
    rm -fr "$target_dir"
    mkdir -p "$target_dir/usr"
    cp "$KERNEL_DIR/usr/"*.list "$target_dir/usr"
    sed "s|usr/|$KERNEL_DIR/usr/|g" -i "$target_dir/usr/"*.list
    mka -C "$KERNEL_DIR" O="$target_dir" ${target}\_cm9_defconfig HOSTCC="$CCACHE gcc"
    mka -C "$KERNEL_DIR" O="$target_dir" HOSTCC="$CCACHE gcc" CROSS_COMPILE="$CCACHE $CROSS_PREFIX" zImage modules
    cp "$target_dir"/arch/arm/boot/zImage $ANDROID_BUILD_TOP/device/samsung/galaxytab/kernel-$target
}

initrd_source_bootimg ()
{
    sed -i "s|CONFIG_INITRAMFS_SOURCE=\".*\"|CONFIG_INITRAMFS_SOURCE=\"usr/galaxytab_initramfs.list\"|" arch/arm/configs/*_cm9_defconfig
}

setup

if [ "$1" = clean ] ; then
    rm -fr "$BUILD_DIR"/*
    exit 0
fi

targets=("$@")
if [ 0 = "${#targets[@]}" ] ; then
    targets=(p1 p1c p1l p1n)
fi

START=$(date +%s)

for target in "${targets[@]}" ; do
if [ "$1" = bootimg ] ; then
    initrd_source_bootimg
    build_bootimg $target
else
    initrd_source_zImage
    build_zImage $target
fi
done

END=$(date +%s)
ELAPSED=$((END - START))
E_MIN=$((ELAPSED / 60))
E_SEC=$((ELAPSED - E_MIN * 60))
printf "Elapsed: "
[ $E_MIN != 0 ] && printf "%d min(s) " $E_MIN
printf "%d sec(s)\n" $E_SEC
