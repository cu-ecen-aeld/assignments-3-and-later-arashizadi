#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

if ! mkdir -p "${OUTDIR}"; then
    echo "Error: cannot create dir ${OUTDIR}" >&2
    exit 1
fi

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
    make -j"$(nproc)" ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} all
    make -j"$(nproc)" ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} modules
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} dtbs
fi

echo "Adding the Image in outdir"
cp -a "${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image" "${OUTDIR}/Image"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

mkdir -p "${OUTDIR}/rootfs"
cd "${OUTDIR}/rootfs"
for dir in bin dev etc home lib lib64 proc sbin sys tmp usr/bin usr/sbin var/log; do
    mkdir -p "$dir"
done

cd "$OUTDIR"

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    git clone git://busybox.net/busybox.git
    cd busybox
else
    cd busybox
    git fetch --tags origin
fi
git checkout ${BUSYBOX_VERSION}

echo "Applying patch to fix -Werror=format-security in BusyBox build"
# The original line 74 is: printf(usage_array[i].aname);
# changing it to: printf("%s", usage_array[i].aname);
if ! sed -i 's/printf(usage_array\[i\].aname);/printf("%s", usage_array[i].aname);/' applets/usage_pod.c; then
    echo "Failed to apply format-security fix. Skipping..." >&2
fi

make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} distclean
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig
make -j"$(nproc)" ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX="${OUTDIR}/rootfs" install

echo "Library dependencies"

cd "${OUTDIR}/rootfs"
if [ ! -e dev/null ]; then
    sudo mknod -m 666 dev/null c 1 3
fi
if [ ! -e dev/console ]; then
    sudo mknod -m 600 dev/console c 5 1
fi

${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
LIBS=(
    lib/ld-linux-aarch64.so.1
    lib64/libm.so.6
    lib64/libresolv.so.2
    lib64/libc.so.6
)
for lib in "${LIBS[@]}"; do
    src="${SYSROOT}/${lib}"
    dest_dir="${OUTDIR}/rootfs/$(dirname "$lib")"
    if [ ! -e "$src" ]; then
        echo "Missing dependency ${src}." >&2
        exit 1
    fi
    cp -a "$src" "$dest_dir"
done


cd "${FINDER_APP_DIR}"
make clean
make CROSS_COMPILE=${CROSS_COMPILE}

HOME_DIR="${OUTDIR}/rootfs/home"
cp writer "${HOME_DIR}/"
cp finder.sh "${HOME_DIR}/"
cp finder-test.sh "${HOME_DIR}/"
cp autorun-qemu.sh "${HOME_DIR}/"
mkdir -p "${HOME_DIR}/conf"
cp conf/username.txt conf/assignment.txt "${HOME_DIR}/conf/"

sudo chown -R root:root "${OUTDIR}/rootfs"

cd "${OUTDIR}/rootfs"
find . | cpio -H newc -ov --owner root:root > "${OUTDIR}/initramfs.cpio"
gzip -f "${OUTDIR}/initramfs.cpio"
