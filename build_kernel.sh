#!/bin/bash

# Compile the Linux kernel for Ubuntu.

# Supported kernels: 5.4 LTS / 5.10 LTS / 5.13 EOL / 5.14 EOL / 5.15 / 5.16

set -euo pipefail

KERNEL_BASE_VER=${KERNEL_BASE_VER:-"5.16"}
KERNEL_PATCH_VER=${KERNEL_PATCH_VER:-"5.16.1"}
KERNEL_SUB_VER=${KERNEL_SUB_VER:-"051601"}
KERNEL_TYPE=${KERNEL_TYPE:-"idle"} # idle, full, rt
KERNEL_SCHEDULER=${KERNEL_SCHEDULER:-"cfs"} # cfs, cacule
KERNEL_VERSION_LABEL=${KERNEL_VERSION_LABEL:-"custom"}

KERNEL_MAIN_DIR=${KERNEL_MAIN_DIR:-$HOME/kernel_main}
KERNEL_BUILD_DIR=${KERNEL_BUILD_DIR:-${KERNEL_MAIN_DIR}/build}
KERNEL_SOURCES_DIR=${KERNEL_SOURCES_DIR:-${KERNEL_MAIN_DIR}/sources}
COMPILED_KERNELS_DIR=${COMPILED_KERNELS_DIR:-${KERNEL_MAIN_DIR}/compiled}
CONFIG_PATH=${CONFIG_PATH:-${KERNEL_MAIN_DIR}/configs}
PATCH_PATH=${PATCH_PATH:-${KERNEL_MAIN_DIR}/patches}
LUCJAN_PATCH_PATH=${LUCJAN_PATCH_PATH:-${PATCH_PATH}/lucjan-patches}
XANMOD_PATCH_PATH=${XANMOD_PATCH_PATH:-${PATCH_PATH}/xanmod-patches}
CUSTOM_PATCH_PATH=${CUSTOM_PATCH_PATH:-${PATCH_PATH}/custom-patches}
KERNEL_SRC_URI=${KERNEL_SRC_URI:-"https://cdn.kernel.org/pub/linux/kernel/v5.x"}
KERNEL_SRC_EXT=${KERNEL_SRC_EXT:-"tar.xz"}
KERNEL_SRC_NAME=${KERNEL_SRC_NAME:-"linux-${KERNEL_PATCH_VER}"}
KERNEL_SRC_URL=${KERNEL_SRC_URL:-${KERNEL_SRC_URI}/${KERNEL_SRC_NAME}.${KERNEL_SRC_EXT}}

echo "*** Creating kernel workspace if it doesn't already exist... ✓";
mkdir -pv ${KERNEL_MAIN_DIR};

echo "*** Creating sources directory if it doesn't already exist... ✓";
mkdir -pv ${KERNEL_SOURCES_DIR};

echo "*** Creating patches directory if it doesn't already exist... ✓";
mkdir -pv ${CUSTOM_PATCH_PATH};

echo "*** Creating configs directory if it doesn't already exist... ✓";
mkdir -pv ${CONFIG_PATH};

# Set the relative path so we can run the script from any directory
# i.e. instead of $ cd build-ubuntu-kernel && ./build_kernel.sh
# We can now do ./build-ubuntu-kernel/build_kernel.sh, for example
PARENT_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P)
cd ${PARENT_PATH};

if [ ${PARENT_PATH} != ${KERNEL_MAIN_DIR} ]; then
    # Handle the case where we allow for building a modified build script
    # in $KERNEL_MAIN_DIR (~/kernel_main) as opposed to the location where
    # we cloned the repo.
    #
    # For the code below, if we are running this script in ~/kernel_main,
    # $PARENT_PATH will equal $KERNEL_MAIN_DIR, so we can just safely ignore it.
    #
    # Lastly, for making changes to this original script, you can make them in
    # ~/kernel_main/build_kernel.sh, and ignore the build_kernel.sh from the
    # directory where repo was cloned, as it's technically only needed the
    # first time you run the script to set things up. But can also be repeatedly
    # run from the cloned directory or ~/kernel_main.
    #
    # Another option is to ignore ~/kernel_main/build_kernel.sh, and just make your
    # changes in the directory where you cloned the repo, but first stashing
    # your changes with "git stash", then pulling the latest script with
    # "git pull origin master", and then apply back your changes with "git stash apply".
    # Probably the easiest way to stay updated while applying your own special sauce.

    cp --no-clobber --recursive ./configs/* ${CONFIG_PATH};
    cp --update --recursive ./patches/* ${CUSTOM_PATCH_PATH};

    SCRIPT_NAME=${SCRIPT_NAME:-"build_kernel"}
    BACKUP_SCRIPT_NAME=${BACKUP_SCRIPT_NAME:-"${SCRIPT_NAME}-backup"}
    SCRIPT_EXT=${SCRIPT_EXT:-"sh"}
    SCRIPT_FILE=${KERNEL_MAIN_DIR}/${SCRIPT_NAME}.${SCRIPT_EXT}
    BACKUP_SCRIPT_FILE=${KERNEL_MAIN_DIR}/${BACKUP_SCRIPT_NAME}.${SCRIPT_EXT}
    SHOW_BACKUP_PROMPT=${SHOW_BACKUP_PROMPT:-"yes"}
    if [ ${SHOW_BACKUP_PROMPT} == "yes" ]; then
        if [ -f ${SCRIPT_FILE} ]; then
            echo -n "Found existing build script. Overwrite? [y/N]: ";
            read yno;
            case $yno in
                [yY] | [yY][Ee][Ss] )
                    if [ -f ${BACKUP_SCRIPT_FILE} ]; then
                        echo "Removing the old backup ${SCRIPT_NAME} script... ✓";
                        rm -f ${BACKUP_SCRIPT_FILE};
                    fi
                    echo "*** Backing up the current ${SCRIPT_NAME} script... ✓";
                    cp ${SCRIPT_FILE} ${BACKUP_SCRIPT_FILE};
                    echo "*** Copying over the updated ${SCRIPT_NAME} script... ✓";
                    cp --update ./${SCRIPT_NAME}.${SCRIPT_EXT} ${KERNEL_MAIN_DIR};
                    ;;
                [nN] | [n|N][O|o] )
                    ;&
                *)
                    echo "*** Keeping existing ${SCRIPT_NAME} script.";
                    ;;
            esac
        else
            echo "*** Copying ${SCRIPT_NAME}.${SCRIPT_EXT} to ${KERNEL_MAIN_DIR}"
            echo " to allow for custom editing... ✓";
            cp ./${SCRIPT_NAME}.${SCRIPT_EXT} ${KERNEL_MAIN_DIR};
        fi
    fi
fi

echo "*** Removing previous build directory if it exists... ✓";
rm -rf ${KERNEL_BUILD_DIR};
mkdir -pv ${KERNEL_BUILD_DIR};
cd ${KERNEL_BUILD_DIR};

if ! [ -f ${KERNEL_SOURCES_DIR}/${KERNEL_SRC_NAME}.${KERNEL_SRC_EXT} ]; then
    echo "*** No tarball found for ${KERNEL_SRC_NAME}, fetching... ✓";
    wget ${KERNEL_SRC_URL} -P ${KERNEL_SOURCES_DIR};
fi

echo "*** Copying over the source tarball... ✓";
cp -v ${KERNEL_SOURCES_DIR}/${KERNEL_SRC_NAME}.${KERNEL_SRC_EXT} .;

TAR_VERBOSE=${TAR_VERBOSE:-"no"}
echo "*** Extracting the kernel source tarball. Please wait... ";
[ ${TAR_VERBOSE} == "no" ] && TAR_FLAGS=${TAR_FLAGS:-"xf"} || TAR_FLAGS=${TAR_FLAGS:-"xvf"};
tar ${TAR_FLAGS} ${KERNEL_SRC_NAME}.${KERNEL_SRC_EXT};
echo "*** Finished extracting source tarball. ✓";
rm -f ${KERNEL_SRC_NAME}.${KERNEL_SRC_EXT};
cd ${KERNEL_SRC_NAME};

if [ -d ${PATCH_PATH}/lucjan-patches ]; then
    echo "*** Found lucjan-patches, pulling latest... ✓";
    git -C ${PATCH_PATH}/lucjan-patches pull https://github.com/sirlucjan/kernel-patches.git;
else
    echo "*** Fetching lucjan patches... ✓";
    git clone https://github.com/sirlucjan/kernel-patches.git ${PATCH_PATH}/lucjan-patches;
fi

if [ -d ${PATCH_PATH}/xanmod-patches ]; then
    echo "*** Found xanmod-patches, pulling latest... ✓";
    git -C ${PATCH_PATH}/xanmod-patches pull https://github.com/xanmod/linux-patches.git;
else
    echo "*** Fetching xanmod patches... ✓";
    git clone https://github.com/xanmod/linux-patches.git ${PATCH_PATH}/xanmod-patches;
fi

UBUNTU_PATCHES=${UBUNTU_PATCHES:-"yes"}
if [ ${UBUNTU_PATCHES} == "yes" ]; then
    # Deprecated as of 5.4.45 but can still be applied
    # See https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.4.45/
    echo "*** Copying and applying Ubuntu patches... 1/4 ✓";
    [ ${KERNEL_BASE_VER} == "5.4" ] && KERNEL_BASE_VER_OVERRIDE=5.4 || KERNEL_BASE_VER_OVERRIDE=5.7+;
    cp -v ${CUSTOM_PATCH_PATH}/ubuntu-${KERNEL_BASE_VER_OVERRIDE}/*.patch .;
    patch -p1 < ./0001-base-packaging.patch;
    patch -p1 < ./0002-UBUNTU-SAUCE-add-vmlinux.strip-to-BOOT_TARGETS1-on-p.patch;
    patch -p1 < ./0003-UBUNTU-SAUCE-tools-hv-lsvmbus-add-manual-page.patch;

    echo "*** Updating version number in changelog... 2/4 ✓";
    # Update the version in the changelog to latest version since the patches
    # are no longer maintained and because we want to keep our kernel as Ubuntu-like
    # as possible (with ABI and all)
    if [ ${KERNEL_BASE_VER} == "5.4" ]; then
        sed -i "s/5.4.45-050445/${KERNEL_PATCH_VER}-${KERNEL_SUB_VER}/g" ./0004-debian-changelog.patch;
    else # for all kernels > 5.4. The 5.7.1 kernel was last to supply patches
        sed -i "s/5.7.1-050701/${KERNEL_PATCH_VER}-${KERNEL_SUB_VER}/g" ./0004-debian-changelog.patch;
    fi
    patch -p1 < ./0004-debian-changelog.patch;

    echo "*** Updating patch version number... 3/4 ✓";
    [ ${KERNEL_BASE_VER} == "5.4" ] && KERNEL_PATCH_SUB_VER=5.4.0-26.30 || KERNEL_PATCH_SUB_VER=5.7.0-6.7;
    patch -p1 < ./0005-configs-based-on-Ubuntu-${KERNEL_PATCH_SUB_VER}.patch;

    echo "*** Update debian compat level from 9 to 10... 4/4 ✓";
    # Solves the following:
    # dh_installdeb: warning: Compatibility levels before 10 are deprecated (level 9 in use)
    sed -i "s/9/10/g" ./debian/compat;
    echo "*** Successfully applied all Ubuntu patches. ✓";
fi

# Allow support for rt (real-time) kernels
# https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt
if [ ${KERNEL_TYPE} == "rt" ]; then
    echo "*** Copying and applying rt patches... ✓";
    if [ ${KERNEL_BASE_VER} == "5.16" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/rt/${KERNEL_BASE_VER}/patch-5.16-rt14.patch .;
        patch -p1 < ./patch-5.16-rt14.patch;
    elif [ ${KERNEL_BASE_VER} == "5.15" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/rt/${KERNEL_BASE_VER}/patch-5.15.14-rt27.patch .;
        patch -p1 < ./patch-5.15.14-rt27.patch;
    elif [ ${KERNEL_BASE_VER} == "5.14" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/rt/${KERNEL_BASE_VER}/patch-5.14.2-rt21.patch .;
        patch -p1 < ./patch-5.14.2-rt21.patch;
    elif [ ${KERNEL_BASE_VER} == "5.13" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/rt/${KERNEL_BASE_VER}/patch-5.13-rt1.patch .;
        patch -p1 < ./patch-5.13-rt1.patch;
    elif [ ${KERNEL_BASE_VER} == "5.10" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/rt/${KERNEL_BASE_VER}/patch-5.10.90-rt61-rc1.patch .;
        patch -p1 < ./patch-5.10.90-rt61-rc1.patch;
    elif [ ${KERNEL_BASE_VER} == "5.4" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/rt/${KERNEL_BASE_VER}/patch-5.4.170-rt68.patch .;
        patch -p1 < ./patch-5.4.170-rt68.patch;
    fi
fi

if [ ${KERNEL_BASE_VER} == "5.16" ]; then   # Latest mainline
    echo "*** Copying and applying amd64 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/amd64-patches/*.patch .;
    patch -p1 < ./0001-amd64-patches.patch;
    echo "*** Copying and applying arch patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/arch-patches/*.patch .;
    patch -p1 < ./0001-arch-patches.patch;
    echo "*** Copying and applying aufs patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/aufs-patches/*.patch .;
    patch -p1 < ./0001-aufs-20220117.patch;
    echo "*** Copying and applying bbr2 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/bbr2-patches-v2/*.patch .;
    patch -p1 < ./0001-bbr2-patches.patch;
    echo "*** Copying and applying blk patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/blk-patches/*.patch .;
    patch -p1 < ./0001-blk-patches.patch;
    echo "*** Copying and applying block patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/block-patches/*.patch .;
    patch -p1 < ./0001-block-patches.patch;
    echo "*** Copying and applying btrfs patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/btrfs-patches/*.patch .;
    patch -p1 < ./0001-btrfs-patches.patch;
    echo "*** Copying and applying clearlinux patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/clearlinux-patches-sep/*.patch .;
    patch -p1 < ./0001-i8042-decrease-debug-message-level-to-info.patch;
    patch -p1 < ./0002-increase-the-ext4-default-commit-age.patch;
    patch -p1 < ./0003-silence-rapl.patch;
    patch -p1 < ./0004-pci-pme-wakeups.patch;
    patch -p1 < ./0005-ksm-wakeups.patch;
    patch -p1 < ./0006-intel_idle-tweak-cpuidle-cstates.patch;
    patch -p1 < ./0007-port-print-fsync-count-for-bootchart.patch;
    patch -p1 < ./0008-bootstats-add-printk-s-to-measure-boot-time-in-more-.patch;
    patch -p1 < ./0009-smpboot-reuse-timer-calibration.patch;
    patch -p1 < ./0010-port-initialize-ata-before-graphics.patch;
    patch -p1 < ./0011-give-rdrand-some-credit.patch;
    patch -p1 < ./0012-ipv4-tcp-allow-the-memory-tuning-for-tcp-to-go-a-lit.patch;
    patch -p1 < ./0013-init-wait-for-partition-and-retry-scan.patch;
    patch -p1 < ./0014-add-boot-option-to-allow-unsigned-modules.patch;
    patch -p1 < ./0015-enable-stateless-firmware-loading.patch;
    patch -p1 < ./0016-migrate-some-systemd-defaults-to-the-kernel-defaults.patch;
    patch -p1 < ./0017-xattr-allow-setting-user.-attributes-on-symlinks-by-.patch;
    patch -p1 < ./0018-use-lfence-instead-of-rep-and-nop.patch;
    patch -p1 < ./0019-do-accept-in-LIFO-order-for-cache-efficiency.patch;
    patch -p1 < ./0020-port-locking-rwsem-spin-faster.patch;
    patch -p1 < ./0021-ata-libahci-ignore-staggered-spin-up.patch;
    patch -p1 < ./0022-print-CPU-that-faults.patch;
    patch -p1 < ./0024-nvme-workaround.patch;
    patch -p1 < ./0025-don-t-report-an-error-if-PowerClamp-run-on-other-CPU.patch;
    patch -p1 < ./0026-Port-microcode-patches.patch;
    patch -p1 < ./0027-clearlinux-${KERNEL_BASE_VER}-backport-patches-from-clearlinux-rep.patch;
    echo "*** Copying an applying cpu graysky patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/cpu-patches-sep/*.patch .;
    patch -p1 < ./0001-cpu-${KERNEL_BASE_VER}-merge-graysky-s-patchset.patch;
    patch -p1 < ./0002-init-Kconfig-enable-O3-for-all-arches.patch;
    patch -p1 < ./0003-init-Kconfig-add-O1-flag.patch;
    patch -p1 < ./0004-Makefile-Turn-off-loop-vectorization-for-GCC-O3-opti.patch;
    echo "*** Copying and applying cpufreq patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/cpufreq-patches/*.patch .;
    patch -p1 < ./0001-cpufreq-patches.patch;
    echo "*** Copying and applying f2fs patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/f2fs-patches-sep/*.patch .;
    patch -p1 < ./0001-f2fs-compress-reduce-one-page-array-alloc-and-free-w.patch;
    patch -p1 < ./0002-f2fs-rework-write-preallocations.patch;
    patch -p1 < ./0003-f2fs-reduce-indentation-in-f2fs_file_write_iter.patch;
    patch -p1 < ./0004-f2fs-do-not-expose-unwritten-blocks-to-user-by-DIO.patch;
    patch -p1 < ./0005-f2fs-fix-the-f2fs_file_write_iter-tracepoint.patch;
    patch -p1 < ./0006-f2fs-implement-iomap-operations.patch;
    patch -p1 < ./0007-f2fs-use-iomap-for-direct-I-O.patch;
    patch -p1 < ./0008-f2fs-show-more-DIO-information-in-tracepoint.patch;
    patch -p1 < ./0009-f2fs-fix-remove-page-failed-in-invalidate-compress-p.patch;
    patch -p1 < ./0010-f2fs-support-POSIX_FADV_DONTNEED-drop-compressed-pag.patch;
    patch -p1 < ./0011-f2fs-show-number-of-pending-discard-commands.patch;
    patch -p1 < ./0012-f2fs-avoid-duplicate-call-of-mark_inode_dirty.patch;
    patch -p1 < ./0013-f2fs-fix-to-do-sanity-check-on-inode-type-during-gar.patch;
    patch -p1 < ./0014-f2fs-fix-to-avoid-panic-in-is_alive-if-metadata-is-i.patch;
    patch -p1 < ./0015-f2fs-fix-to-do-sanity-check-in-is_alive.patch;
    patch -p1 < ./0016-f2fs-add-gc_urgent_high_remaining-sysfs-node.patch;
    patch -p1 < ./0017-f2fs-avoid-EINVAL-by-SBI_NEED_FSCK-when-pinning-a-fi.patch;
    patch -p1 < ./0018-f2fs-compress-fix-potential-deadlock-of-compress-fil.patch;
    patch -p1 < ./0019-f2fs-avoid-down_write-on-nat_tree_lock-during-checkp.patch;
    patch -p1 < ./0020-f2fs-do-not-bother-checkpoint-by-f2fs_get_node_info.patch;
    patch -p1 < ./0021-f2fs-fix-to-do-sanity-check-on-last-xattr-entry-in-_.patch;
    patch -p1 < ./0022-f2fs-clean-up-__find_inline_xattr-with-__find_xattr.patch;
    patch -p1 < ./0023-f2fs-support-fault-injection-to-f2fs_trylock_op.patch;
    patch -p1 < ./0024-f2fs-fix-to-check-available-space-of-CP-area-correct.patch;
    patch -p1 < ./0025-f2fs-fix-to-reserve-space-for-IO-align-feature.patch;
    patch -p1 < ./0026-f2fs-don-t-drop-compressed-page-cache-in-.-invalidat.patch;
    patch -p1 < ./0027-f2fs-Simplify-bool-conversion.patch;
    patch -p1 < ./0028-f2fs-remove-redunant-invalidate-compress-pages.patch;
    patch -p1 < ./0029-f2fs-move-f2fs-to-use-reader-unfair-rwsems.patch;
    patch -p1 < ./0030-f2fs-do-not-allow-partial-truncation-on-pinned-file.patch;
    patch -p1 < ./0031-fs-f2fs-data.c-fix-mess.patch;
    patch -p1 < ./0032-fix-mess-2.patch;
    echo "*** Copying and applying fixes misc patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/fixes-miscellaneous-sep/*.patch .;
    patch -p1 < ./0001-net-sched-allow-configuring-cake-qdisc-as-default.patch;
    patch -p1 < ./0002-infiniband-Fix-__read_overflow2-error-with-O3-inlini.patch;
    patch -p1 < ./0003-pci-Enable-overrides-for-missing-ACS-capabilities.patch;
    patch -p1 < ./0004-scsi-sd-Optimal-I-O-size-should-be-a-multiple-of-rep.patch;
    patch -p1 < ./0005-iomap-avoid-deadlock-if-memory-reclaim-is-triggered-.patch;
    patch -p1 < ./0007-i2c-busses-Add-SMBus-capability-to-work-with-OpenRGB.patch;
    patch -p1 < ./0008-fm-5.16-port-mm-kswapd-patches.patch;
    patch -p1 < ./0009-Disable-stack-conservation-for-GCC.patch;
    patch -p1 < ./0010-x86-csum-rewrite-csum_partial.patch;
    patch -p1 < ./0011-x86-csum-Fix-compilation-error-for-UM.patch;
    patch -p1 < ./0012-x86-csum-Fix-initial-seed-for-odd-buffers.patch;
    patch -p1 < ./0013-xfs-check-sb_meta_uuid-for-dabuf-buffer-recovery.patch;
    echo "*** Copying an applying hwmon patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/hwmon-patches-v4/*.patch .;
    patch -p1 < ./0001-hwmon-patches.patch;
    echo "*** Copying and applying lqx patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lqx-patches/*.patch .;
    patch -p1 < ./0001-lqx-patches.patch;
    echo "*** Copying and applying lrng patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lrng-patches/*.patch .;
    patch -p1 < ./0001-lrng-patches.patch;
    echo "*** Copying and applying net patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/net-patches-v3/*.patch .;
    patch -p1 < ./0001-net-patches.patch;
    echo "*** Copying and applying pf patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/pf-patches/*.patch .;
    patch -p1 < ./0001-pf-patches.patch;
    echo "*** Copying and applying spadfs patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/spadfs-patches/*.patch .;
    patch -p1 < ./0001-spadfs-5.16-merge-v1.0.15.patch;
    echo "*** Copying and applying v4l2loopback patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/v4l2loopback-patches/*.patch .;
    patch -p1 < ./0001-v4l2loopback-5.16-merge-v0.12.5.patch;
    echo "*** Copying and applying lucjan's xanmod patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/xanmod-patches/*.patch .;
    patch -p1 < ./0001-xanmod-patches.patch;
    echo "*** Copying and applying lucjan's zen patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/zen-patches/*.patch .;
    patch -p1 < ./0001-zen-patches.patch;
    echo "*** Copying and applying zstd patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/zstd-patches/*.patch .;
    patch -p1 < ./0001-zstd-patches.patch;
    echo "*** Copying and applying misc xanmod tweaks.. ✓";
    cp -v ${XANMOD_PATCH_PATH}/linux-${KERNEL_BASE_VER}.y-xanmod/xanmod/*.patch .;
    patch -p1 < ./0001-XANMOD-fair-Remove-all-energy-efficiency-functions.patch;
    patch -p1 < ./0002-XANMOD-block-mq-deadline-Disable-front_merges-by-def.patch;
    patch -p1 < ./0007-XANMOD-mm-vmscan-vm_swappiness-30-decreases-the-amou.patch;
    patch -p1 < ./0008-XANMOD-cpufreq-tunes-ondemand-and-conservative-gover.patch;
    patch -p1 < ./0009-XANMOD-scripts-disable-the-localversion-tag-of-a-git.patch;
    patch -p1 < ./0010-XANMOD-lib-kconfig.debug-disable-default-CONFIG_SYMB.patch;
    echo "*** Copying and applying disable memory compaction patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/5.13-disable-compaction-on-unevictable-pages.patch .;
    patch -p1 < ./5.13-disable-compaction-on-unevictable-pages.patch;
    echo "*** Copying and applying increase writeback threshold patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/increase-default-writeback-thresholds.patch .;
    patch -p1 < ./increase-default-writeback-thresholds.patch;
    echo "*** Copying and applying enable background reclaim hugepages patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/enable-background-reclaim-hugepages.patch .;
    patch -p1 < ./enable-background-reclaim-hugepages.patch;
    echo "*** Copying and applying pkill on warn.. (requires pkill_on_warn=1) ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/pkill-on-warn.patch .;
    patch -p1 < ./pkill-on-warn.patch;
    echo "*** Copying and applying misc scheduler patch for AMD processors.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/amd-use_weight*.patch .;
    patch -p1 < ./amd-use_weight_of_sd_numa_domain_in_find_busiest_group-0001.patch;
    patch -p1 < ./amd-use_weight_of_sd_numa_domain_in_find_busiest_group-0002.patch;
    echo "*** Copying and applying lucjan custom patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/ll-patches/*.patch .;
    patch -p1 < ./0001-LL-kconfig-add-500Hz-timer-interrupt-kernel-config-o.patch;
    sed -i 's/sched_nr_migrate = 32/sched_nr_migrate = 256/g' ./kernel/sched/core.c;
    patch -p1 < ./0004-mm-set-8-megabytes-for-address_space-level-file-read.patch;
    if [ ${KERNEL_TYPE} != "rt" ]; then
        echo "*** Copying and applying lru patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lru-patches-pf/*.patch .;
        patch -p1 < ./0001-lru-patches.patch;
    fi
elif [ ${KERNEL_BASE_VER} == "5.15" ]; then # Latest stable
    echo "*** Copying and applying amd64 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/amd64-patches-v2/*.patch .;
    patch -p1 < ./0001-amd64-patches.patch;
    echo "*** Copying and applying aufs patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/aufs-patches/*.patch .;
    patch -p1 < ./0001-aufs-20211222.patch;
    echo "*** Copying and applying bbr2 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/bbr2-patches/*.patch .;
    patch -p1 < ./0001-bbr2-${KERNEL_BASE_VER}-introduce-BBRv2.patch;
    echo "*** Copying and applying block patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/block-patches-v2/*.patch .;
    patch -p1 < ./0001-block-patches.patch;
    echo "*** Copying and applying btrfs patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/btrfs-patches-v11/*.patch .;
    patch -p1 < ./0001-btrfs-patches.patch;
    echo "*** Copying and applying clearlinux patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/clearlinux-patches-v2-sep/*.patch .;
    patch -p1 < ./0001-i8042-decrease-debug-message-level-to-info.patch;
    patch -p1 < ./0002-increase-the-ext4-default-commit-age.patch;
    patch -p1 < ./0003-silence-rapl.patch;
    patch -p1 < ./0004-pci-pme-wakeups.patch;
    patch -p1 < ./0005-ksm-wakeups.patch;
    patch -p1 < ./0006-intel_idle-tweak-cpuidle-cstates.patch;
    patch -p1 < ./0007-port-print-fsync-count-for-bootchart.patch;
    patch -p1 < ./0008-bootstats-add-printk-s-to-measure-boot-time-in-more-.patch;
    patch -p1 < ./0009-smpboot-reuse-timer-calibration.patch;
    patch -p1 < ./0010-port-initialize-ata-before-graphics.patch;
    patch -p1 < ./0011-give-rdrand-some-credit.patch;
    patch -p1 < ./0012-ipv4-tcp-allow-the-memory-tuning-for-tcp-to-go-a-lit.patch;
    patch -p1 < ./0013-init-wait-for-partition-and-retry-scan.patch;
    patch -p1 < ./0014-add-boot-option-to-allow-unsigned-modules.patch;
    patch -p1 < ./0015-enable-stateless-firmware-loading.patch;
    patch -p1 < ./0016-migrate-some-systemd-defaults-to-the-kernel-defaults.patch;
    patch -p1 < ./0017-xattr-allow-setting-user.-attributes-on-symlinks-by-.patch;
    patch -p1 < ./0018-use-lfence-instead-of-rep-and-nop.patch;
    patch -p1 < ./0019-do-accept-in-LIFO-order-for-cache-efficiency.patch;
    patch -p1 < ./0020-locking-rwsem-spin-faster.patch;
    patch -p1 < ./0021-ata-libahci-ignore-staggered-spin-up.patch;
    patch -p1 < ./0022-print-CPU-that-faults.patch;
    patch -p1 < ./0024-nvme-workaround.patch;
    patch -p1 < ./0025-don-t-report-an-error-if-PowerClamp-run-on-other-CPU.patch;
    patch -p1 < ./0026-Port-microcode-patches.patch;
    patch -p1 < ./0027-clearlinux-5.15-backport-patches-from-clearlinux-rep.patch;
    echo "*** Copying and applying cpufreq patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/cpufreq-patches-v7/*.patch .;
    patch -p1 < ./0001-cpufreq-patches.patch;
    echo "*** Copying an applying graysky patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/cpu-patches-v2-sep/*.patch .;
    patch -p1 < ./0001-cpu-5.15-merge-graysky-s-patchset.patch;
    patch -p1 < ./0002-init-Kconfig-enable-O3-for-all-arches.patch;
    patch -p1 < ./0003-init-Kconfig-add-O1-flag.patch;
    patch -p1 < ./0004-Makefile-Turn-off-loop-vectorization-for-GCC-O3-opti.patch;
    echo "*** Copying and applying fixes misc patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/fixes-miscellaneous-v9-sep/*.patch .;
    patch -p1 < ./0001-net-sched-allow-configuring-cake-qdisc-as-default.patch;
    patch -p1 < ./0002-infiniband-Fix-__read_overflow2-error-with-O3-inlini.patch;
    patch -p1 < ./0003-pci-Enable-overrides-for-missing-ACS-capabilities.patch;
    patch -p1 < ./0004-scsi-sd-Optimal-I-O-size-should-be-a-multiple-of-rep.patch;
    patch -p1 < ./0005-iomap-avoid-deadlock-if-memory-reclaim-is-triggered-.patch;
    patch -p1 < ./0007-i2c-busses-Add-SMBus-capability-to-work-with-OpenRGB.patch;
    patch -p1 < ./0008-nvme-don-t-memset-the-normal-read-write-command.patch;
    patch -p1 < ./0009-mm-Stop-kswapd-early-when-nothing-s-waiting-for-it-t.patch;
    patch -p1 < ./0010-mm-Fully-disable-watermark-boosting-when-it-isn-t-us.patch;
    patch -p1 < ./0011-mm-Don-t-stop-kswapd-on-a-per-node-basis-when-there-.patch;
    patch -p1 < ./0012-mm-Disable-watermark-boosting-by-default.patch;
    patch -p1 < ./0013-Disable-stack-conservation-for-GCC.patch;
    patch -p1 < ./0014-vfs-keep-inodes-with-page-cache-off-the-inode-shrink.patch;
    patch -p1 < ./0015-x86-csum-rewrite-csum_partial.patch;
    patch -p1 < ./0016-x86-csum-Fix-compilation-error-for-UM.patch;
    patch -p1 < ./0017-x86-csum-Fix-initial-seed-for-odd-buffers.patch;
    patch -p1 < ./0018-xfs-check-sb_meta_uuid-for-dabuf-buffer-recovery.patch;
    echo "*** Copying and applying futex (Valve fsync) patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/futex-zen-patches/*.patch .;
    patch -p1 < ./0001-futex-resync-from-gitlab.collabora.com.patch;
    echo "*** Copying and applying futex2 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/futex2-zen-patches/*.patch .;
    patch -p1 < ./0001-futex2-resync-from-gitlab.collabora.com.patch;
    echo "*** Copying and applying hwmon patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/hwmon-patches-v9/*.patch .;
    patch -p1 < ./0001-hwmon-patches.patch;
    echo "*** Copying and applying intel patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/intel-patches-sep/*.patch .;
    patch -p1 < ./0001-x86-sched-Decrease-further-the-priorities-of-SMT-sib.patch;
    patch -p1 < ./0002-sched-topology-Introduce-sched_group-flags.patch;
    patch -p1 < ./0003-sched-fair-Optimize-checking-for-group_asym_packing.patch;
    patch -p1 < ./0004-sched-fair-Provide-update_sg_lb_stats-with-sched-dom.patch;
    patch -p1 < ./0005-sched-fair-Carve-out-logic-to-mark-a-group-for-asymm.patch;
    patch -p1 < ./0006-sched-fair-Consider-SMT-in-ASYM_PACKING-load-balance.patch;
    echo "*** Copying and applying lqx patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lqx-patches-v5-sep/*.patch .;
    patch -p1 < ./0001-zen-Allow-MSR-writes-by-default.patch;
    patch -p1 < ./0002-PCI-Add-Intel-remapped-NVMe-device-support.patch;
    patch -p1 < ./0003-Input-evdev-use-call_rcu-when-detaching-client.patch;
    echo "*** Copying and applying net patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/net-patches-v2/*.patch .;
    patch -p1 < ./0001-net-patches.patch;
    echo "*** Copying and applying ntfs3 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/ntfs3-patches-v2/*.patch .;
    patch -p1 < ./0001-ntfs3-patches.patch;
    echo "*** Copying and applying pf patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/pf-patches-v4/*.patch .;
    patch -p1 < ./0001-pf-patches.patch;
    echo "*** Copying and applying sbitmap patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/sbitmap-patches-v3/*.patch .;
    patch -p1 < ./0001-sbitmap-patches.patch;
    echo "*** Copying and applying spectre patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/spectre-patches/*.patch .;
    patch -p1 < ./0001-spectre-patches.patch;
    echo "*** Copying and applying v4l2loopback patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/v4l2loopback-patches-v2/*.patch .;
    patch -p1 < ./0001-v4l2loopback-patches.patch;
    echo "*** Copying and applying lucjan's xanmod patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/xanmod-patches-v5-sep/*.patch .;
    patch -p1 < ./0002-netfilter-Add-full-cone-NAT-support.patch;
    patch -p1 < ./0003-drm-i915-Add-workaround-numbers-to-GEN7_COMMON_SLICE.patch;
    patch -p1 < ./0004-Revert-netfilter-Add-full-cone-NAT-support.patch;
    patch -p1 < ./0005-Revert-drm-i915-Add-workaround-numbers-to-GEN7_COMMO.patch;
    patch -p1 < ./0006-netfilter-Add-full-cone-NAT-support.patch;
    patch -p1 < ./0007-wait-Add-EXPORT_SYMBOL-for-__wake_up_pollfree.patch;
    echo "*** Copying and applying lucjan's zen patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/zen-patches-sep/*.patch .;
    patch -p1 < ./0001-ZEN-Add-VHBA-driver.patch;
    patch -p1 < ./0002-ZEN-intel-pstate-Implement-enable-parameter.patch;
    patch -p1 < ./0003-ZEN-Update-VHBA-driver.patch;
    echo "*** Copying and applying zstd patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/zstd-patches-v2/*.patch .;
    patch -p1 < ./0001-zstd-patches.patch;
    echo "*** Copying and applying zstd upstream patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/zstd-upstream-patches-v4/*.patch .;
    patch -p1 < ./0001-zstd-upstream-patches.patch;
    echo "*** Copying and applying misc xanmod tweaks.. ✓";
    cp -v ${XANMOD_PATCH_PATH}/linux-${KERNEL_BASE_VER}.y-xanmod/xanmod/*.patch .;
    patch -p1 < ./0004-XANMOD-dcache-cache_pressure-50-decreases-the-rate-a.patch;
    patch -p1 < ./0005-XANMOD-sched-autogroup-Add-kernel-parameter-and-conf.patch;
    patch -p1 < ./0006-XANMOD-mm-vmscan-vm_swappiness-30-decreases-the-amou.patch;
    patch -p1 < ./0007-XANMOD-cpufreq-tunes-ondemand-and-conservative-gover.patch;
    patch -p1 < ./0008-XANMOD-scripts-disable-the-localversion-tag-of-a-git.patch;
    patch -p1 < ./0009-XANMOD-lib-kconfig.debug-disable-default-CONFIG_SYMB.patch;
    patch -p1 < ./0012-XANMOD-fair-Remove-all-energy-efficiency-functions.patch;
    echo "*** Copying and applying cfs zen tweaks patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/${KERNEL_SCHEDULER}-zen-tweaks.patch .;
    patch -p1 < ./${KERNEL_SCHEDULER}-zen-tweaks.patch;
    echo "*** Copying and applying disable memory compaction patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/5.13-disable-compaction-on-unevictable-pages.patch .;
    patch -p1 < ./5.13-disable-compaction-on-unevictable-pages.patch;
    echo "*** Copying and applying increase writeback threshold patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/increase-default-writeback-thresholds.patch .;
    patch -p1 < ./increase-default-writeback-thresholds.patch;
    echo "*** Copying and applying enable background reclaim hugepages patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/enable-background-reclaim-hugepages.patch .;
    patch -p1 < ./enable-background-reclaim-hugepages.patch;
    echo "*** Copying and applying pkill on warn.. (requires pkill_on_warn=1) ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/pkill-on-warn.patch .;
    patch -p1 < ./pkill-on-warn.patch;
    echo "*** Copying and applying misc scheduler patch for AMD processors.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/amd-use_weight*.patch .;
    patch -p1 < ./amd-use_weight_of_sd_numa_domain_in_find_busiest_group-0001.patch;
    patch -p1 < ./amd-use_weight_of_sd_numa_domain_in_find_busiest_group-0002.patch;
    echo "*** Copying and applying lucjan custom patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/ll-patches/*.patch .;
    patch -p1 < ./0001-LL-kconfig-add-500Hz-timer-interrupt-kernel-config-o.patch;
    sed -i 's/sched_nr_migrate = 32/sched_nr_migrate = 256/g' ./kernel/sched/core.c;
    patch -p1 < ./0004-mm-set-8-megabytes-for-address_space-level-file-read.patch;
    if [ ${KERNEL_TYPE} == "rt" ]; then
        echo "*** Copying and applying arch patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/arch-rt-patches-v3-sep/*.patch .;
        patch -p1 < ./0001-ZEN-Add-sysctl-and-CONFIG-to-disallow-unprivileged-C.patch;
        patch -p1 < ./0003-PCI-Add-more-NVIDIA-controllers-to-the-MSI-masking-q.patch;
        patch -p1 < ./0004-iommu-intel-do-deep-dma-unmapping-to-avoid-kernel-fl.patch;
        patch -p1 < ./0005-cpufreq-intel_pstate-ITMT-support-for-overclocked-sy.patch;
        patch -p1 < ./0006-Bluetooth-btintel-Fix-bdaddress-comparison-with-garb.patch;
        patch -p1 < ./0007-lg-laptop-Recognize-more-models.patch;
    else
        echo "*** Copying and applying arch patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/arch-patches-v11/*.patch .;
        patch -p1 < ./0001-arch-patches.patch;
        echo "*** Copying and applying damon patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/damon-patches-v10/*.patch .;
        patch -p1 < ./0001-damon-patches.patch;
        echo "*** Copying and applying ksmbd patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/ksmbd-patches-v15/*.patch .;
        patch -p1 < ./0001-ksmbd-patches.patch;
        echo "*** Copying and applying lrng patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lrng-patches-v3/*.patch .;
        patch -p1 < ./0001-lrng-patches.patch;
        echo "*** Copying and applying lru patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lru-patches-pf-v4/*.patch .;
        patch -p1 < ./0001-lru-patches.patch;
    fi
elif [ ${KERNEL_BASE_VER} == "5.14" ]; then # EOL (End of Life, 5.14.21, 11/21/21)
    echo "*** Copying and applying pkill on warn.. (requires pkill_on_warn=1) ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/pkill-on-warn.patch .;
    patch -p1 < ./pkill-on-warn.patch;
    echo "*** Copying and applying arch patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/arch-patches-v11-sep/*.patch .;
    patch -p1 < ./0001-ZEN-Add-sysctl-and-CONFIG-to-disallow-unprivileged-C.patch;
    patch -p1 < ./0002-Bluetooth-btusb-Add-support-for-IMC-Networks-Mediate.patch;
    patch -p1 < ./0003-Bluetooth-btusb-Add-support-for-Foxconn-Mediatek-Chi.patch;
    patch -p1 < ./0004-ALSA-pci-rme-Set-up-buffer-type-properly.patch;
    echo "*** Copying and applying aufs patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/aufs-patches/*.patch .;
    patch -p1 < ./0001-aufs-20211018.patch;
    echo "*** Copying and applying bbr2 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/bbr2-patches/*.patch .;
    patch -p1 < ./0001-bbr2-5.14-introduce-BBRv2.patch;
    echo "*** Copying and applying bcachefs patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/bcachefs-patches/*.patch .;
    patch -p1 < ./0001-bcachefs-5.14-introduce-bcachefs-patchset.patch;
    echo "*** Copying and applying bfq patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/bfq-patches-v2-sep/*.patch .;
    patch -p1 < ./0002-block-bfq-cleanup-the-repeated-declaration.patch;
    echo "*** Copying and applying block patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/block-patches-v2-sep/*.patch .;
    patch -p1 < ./0001-block-Kconfig.iosched-set-default-value-of-IOSCHED_B.patch;
    patch -p1 < ./0002-block-Fix-depends-for-BLK_DEV_ZONED.patch;
    patch -p1 < ./0003-block-set-rq_affinity-2-for-full-multithreading-I-O.patch;
    patch -p1 < ./0004-block-fix-trivial-typos-in-comments.patch;
    patch -p1 < ./0005-block-Add-CONFIG-to-rename-the-mq-deadline-scheduler.patch;
    patch -p1 < ./0006-block-remove-plug-based-merging.patch;
    echo "*** Copying and applying btrfs patches.. ✓";
    if [ ${KERNEL_TYPE} == "rt" ]; then
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/btrfs-patches-v2/*.patch .;
    else
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/btrfs-patches-v9/*.patch .;
    fi
    patch -p1 < ./0001-btrfs-patches.patch;
    echo "*** Copying and applying clearlinux patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/clearlinux-patches/*.patch .;
    patch -p1 < ./0001-clearlinux-patches.patch;
    echo "*** Copying and applying cpufreq patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/cpufreq-patches-v2/*.patch .;
    patch -p1 < ./0001-cpufreq-patches.patch;
    echo "*** Copying and applying cpu graysky patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/cpu-patches/*.patch .;
    patch -p1 < ./0001-cpu-patches.patch;
    echo "*** Copying and applying fixes misc patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/fixes-miscellaneous-v8-sep/*.patch .;
    patch -p1 < ./0001-net-sched-allow-configuring-cake-qdisc-as-default.patch;
    patch -p1 < ./0002-infiniband-Fix-__read_overflow2-error-with-O3-inlini.patch;
    patch -p1 < ./0003-kbuild-add-fcf-protection-none-to-retpoline-flags.patch;
    patch -p1 < ./0004-mm-Stop-kswapd-early-when-nothing-s-waiting-for-it-t.patch;
    patch -p1 < ./0005-mm-Fully-disable-watermark-boosting-when-it-isn-t-us.patch;
    patch -p1 < ./0006-mm-Don-t-stop-kswapd-on-a-per-node-basis-when-there-.patch;
    patch -p1 < ./0007-kbuild-Disable-stack-conservation-for-GCC.patch;
    patch -p1 < ./0008-pci-Enable-overrides-for-missing-ACS-capabilities.patch;
    patch -p1 < ./0009-ZEN-Add-OpenRGB-patches.patch;
    patch -p1 < ./0010-scsi-sd-Optimal-I-O-size-should-be-a-multiple-of-rep.patch;
    patch -p1 < ./0011-iomap-avoid-deadlock-if-memory-reclaim-is-triggered-.patch;
    patch -p1 < ./0013-fs-add-a-filemap_fdatawrite_wbc-helper.patch;
    patch -p1 < ./0014-NFS-Always-provide-aligned-buffers-to-the-RPC-read-l.patch;
    patch -p1 < ./0015-SUNRPC-Simplify-socket-shutdown-when-not-reusing-TCP.patch;
    patch -p1 < ./0016-SUNRPC-Tweak-TCP-socket-shutdown-in-the-RPC-client.patch;
    patch -p1 < ./0017-Revert-ZEN-Add-OpenRGB-patches.patch;
    patch -p1 < ./0018-i2c-busses-Add-SMBus-capability-to-work-with-OpenRGB.patch;
    if [ ${KERNEL_TYPE} != "rt" ]; then
        patch -p1 < ./0019-nvme-don-t-memset-the-normal-read-write-command.patch;
    fi
    echo "*** Copying and applying hwmon patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/hwmon-patches-v7/*.patch .;
    patch -p1 < ./0001-hwmon-patches.patch;
    echo "*** Copying and applying ksmbd patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/ksmbd-patches-v21/*.patch .;
    patch -p1 < ./0001-ksmbd-patches.patch;
    echo "*** Copying and applying lqx patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lqx-patches-sep/*.patch .;
    patch -p1 < ./0001-zen-Allow-MSR-writes-by-default.patch;
    patch -p1 < ./0002-PCI-Add-Intel-remapped-NVMe-device-support.patch;
    echo "*** Copying and applying lrng patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lrng-patches-v3/*.patch .;
    patch -p1 < ./0001-lrng-patches.patch;
    echo "*** Copying and applying ntfs3 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/ntfs3-patches-v14/*.patch .;
    patch -p1 < ./0001-ntfs3-patches.patch;
    echo "*** Copying and applying pf patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/pf-patches-v8-sep/*.patch .;
    patch -p1 < ./0001-mm-compaction-optimize-proactive-compaction-deferral.patch;
    patch -p1 < ./0002-mm-compaction-support-triggering-of-proactive-compac.patch;
    patch -p1 < ./0003-genirq-i2c-Provide-and-use-generic_dispatch_irq.patch;
    patch -p1 < ./0004-mac80211-minstrel_ht-force-ampdu_len-to-be-0.patch;
    patch -p1 < ./0005-net-replace-WARN_ONCE-with-pr_warn_once.patch;
    patch -p1 < ./0006-x86-ACPI-State-Optimize-C3-entry-on-AMD-CPUs.patch;
    patch -p1 < ./0007-namei-add-mapping-aware-lookup-helper.patch;
    patch -p1 < ./0008-mac80211-rate-replace-WARN_ON-with-pr_warn.patch;
    patch -p1 < ./0009-mac80211-airtime-replace-WARN_ON_ONCE-with-pr_warn_o.patch;
    patch -p1 < ./0010-mac80211-rate-replace-WARN_ON_ONCE-with-pr_warn_once.patch;
    echo "*** Copying and applying security patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/security-patches-sep/*.patch .;
    patch -p1 < ./0001-security-Add-LSM-hook-at-the-point-where-a-task-gets.patch;
    patch -p1 < ./0002-security-brute-Define-a-LSM-and-add-sysctl-attribute.patch;
    patch -p1 < ./0003-security-brute-Detect-a-brute-force-attack.patch;
    patch -p1 < ./0004-security-brute-Mitigate-a-brute-force-attack.patch;
    patch -p1 < ./0005-security-brute-Notify-to-userspace-task-killed.patch;
    patch -p1 < ./0006-selftests-brute-Add-tests-for-the-Brute-LSM.patch;
    patch -p1 < ./0007-Documentation-Add-documentation-for-the-Brute-LSM.patch;
    patch -p1 < ./0008-MAINTAINERS-Add-a-new-entry-for-the-Brute-LSM.patch;
    echo "*** Copying and applying spadfs patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/spadfs-patches/*.patch .;
    patch -p1 < ./0001-spadfs-5.13-merge-v1.0.14.patch;
    echo "*** Copying and applying spectre patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/spectre-patches-sep/*.patch .;
    patch -p1 < ./0001-x86-change-default-to-spec_store_bypass_disable-prct.patch;
    patch -p1 < ./0002-x86-deduplicate-the-spectre_v2_user-documentation.patch;
    echo "*** Copying and applying v4l2loopback patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/v4l2loopback-patches/*.patch .;
    patch -p1 < ./0001-v4l2loopback-5.14-merge-v0.12.5.patch;
    echo "*** Copying and applying writeback patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/writeback-patches/*.patch .;
    patch -p1 < ./0001-writeback-patches.patch;
    echo "*** Copying and applying xanmod patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/xanmod-patches-v2-sep/*.patch .;
    patch -p1 < ./0001-sched-autogroup-Add-kernel-parameter-and-config-opti.patch;
    patch -p1 < ./0002-netfilter-Add-full-cone-NAT-support.patch;
    echo "*** Copying and applying zen patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/zen-patches-v2-sep/*.patch .;
    patch -p1 < ./0001-ZEN-Add-VHBA-driver.patch;
    echo "*** Copying and applying zstd patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/zstd-patches-v2/*.patch .;
    patch -p1 < ./0001-zstd-patches.patch;
    echo "*** Copying and applying zstd upstream patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/zstd-upstream-patches-v7/*.patch .;
    patch -p1 < ./0001-zstd-upstream-patches.patch;
    # Misc / Tweaks
    sed -i 's/sched_nr_migrate = 32/sched_nr_migrate = 256/g' ./kernel/sched/core.c;
    echo "*** Copying and applying cjktty 5.13 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/5.13/cjktty-patches/*.patch .;
    patch -p1 < ./0001-cjktty-5.13-initial-import-from-https-github.com-zhm.patch;
    echo "*** Copying and applying cfs xanmod tweaks patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/5.13-cfs-xanmod-tweaks.patch .;
    patch -p1 < ./5.13-cfs-xanmod-tweaks.patch;
    echo "*** Copying and applying cfs zen tweaks patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/${KERNEL_SCHEDULER}-zen-tweaks.patch .;
    patch -p1 < ./${KERNEL_SCHEDULER}-zen-tweaks.patch;
    echo "*** Copying and applying misc xanmod tweaks patch.. ✓";
    cp -v ${XANMOD_PATCH_PATH}/linux-5.14.y-xanmod/xanmod/*.patch .;
    patch -p1 < ./0005-XANMOD-kconfig-set-PREEMPT-and-RCU_BOOST-without-del.patch;
    patch -p1 < ./0006-XANMOD-dcache-cache_pressure-50-decreases-the-rate-a.patch;
    patch -p1 < ./0008-XANMOD-mm-vmscan-vm_swappiness-30-decreases-the-amou.patch;
    patch -p1 < ./0009-XANMOD-cpufreq-tunes-ondemand-and-conservative-gover.patch;
    patch -p1 < ./0011-XANMOD-lib-kconfig.debug-disable-default-CONFIG_SYMB.patch;
    echo "*** Copying and applying disable memory compaction patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/5.13-disable-compaction-on-unevictable-pages.patch .;
    patch -p1 < ./5.13-disable-compaction-on-unevictable-pages.patch;
    echo "*** Copying and applying force irq threads patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/force-irq-threads.patch .;
    patch -p1 < ./force-irq-threads.patch;
    echo "*** Copying and applying increase writeback threshold patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/increase-default-writeback-thresholds.patch .;
    patch -p1 < ./increase-default-writeback-thresholds.patch;
    echo "*** Copying and applying enable background reclaim hugepages patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/enable-background-reclaim-hugepages.patch .;
    patch -p1 < ./enable-background-reclaim-hugepages.patch;
    echo "*** Copying and applying ll patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/ll-patches/*.patch .;
    patch -p1 < ./0001-LL-kconfig-add-500Hz-timer-interrupt-kernel-config-o.patch;
    patch -p1 < ./0004-mm-set-8-megabytes-for-address_space-level-file-read.patch;
    if [ ${KERNEL_TYPE} != "rt" ]; then
        echo "*** Copying and applying Valve fsync patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/futex-zen-patches-v2/*.patch .;
        patch -p1 < ./0001-futex-resync-from-gitlab.collabora.com.patch;
        echo "*** Copying and applying lru patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lru-zen-patches-v4/*.patch .;
        patch -p1 < ./0001-lru-zen-patches.patch;
        echo "*** Copying and applying ksm patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/ksm-patches-sep/*.patch .;
        patch -p1 < ./0001-mm-ksm-introduce-ksm_madvise_merge-helper.patch;
        patch -p1 < ./0002-mm-ksm-introduce-ksm_madvise_unmerge-helper.patch;
        patch -p1 < ./0003-mm-ksm-proc-introduce-remote-merge.patch;
        patch -p1 < ./0004-mm-ksm-proc-add-remote-KSM-documentation.patch;
        echo "*** Copying and applying block io_uring tweaks by Jens Axboe.. ✓";
        cp -v ${CUSTOM_PATCH_PATH}/tweaks/000*-block-io_uring.patch .;
        patch -p1 < ./0001-block-io_uring.patch;
        patch -p1 < ./0002-block-io_uring.patch;
    fi
elif [ ${KERNEL_BASE_VER} == "5.13" ]; then # EOL (End of Life, 5.13.19, 09/18/21)
    echo "*** Copying and applying hwmon patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/5.14/hwmon-patches/*.patch .;
    patch -p1 < ./0001-hwmon-patches.patch;
    echo "*** Copying and applying pkill on warn.. (requires pkill_on_warn=1) ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/pkill-on-warn.patch .;
    patch -p1 < ./pkill-on-warn.patch;
    echo "*** Copying and applying alsa patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/alsa-patches-v2/*.patch .;
    patch -p1 < ./0001-alsa-patches.patch;
    echo "*** Copying and applying arch patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/arch-patches-v6/*.patch .;
    patch -p1 < ./0001-ZEN-Add-sysctl-and-CONFIG-to-disallow-unprivileged-C.patch;
    echo "*** Copying and applying bbr2 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/bbr2-patches-v2/*.patch .;
    patch -p1 < ./0001-bbr2-patches.patch;
    echo "*** Copying and applying bfq patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/bfq-patches-v7-sep/*.patch .;
    patch -p1 < ./0001-block-bfq-let-also-stably-merged-queues-enjoy-weight.patch;
    if [ ${KERNEL_TYPE} != "rt" ]; then
        patch -p1 < ./0002-block-bfq-consider-also-creation-time-in-delayed-sta.patch;
        patch -p1 < ./0003-block-bfq-boost-throughput-by-extending-queue-mergin.patch;
        patch -p1 < ./0012-Revert-block-return-ELEVATOR_DISCARD_MERGE-if-possib.patch;
    fi
    patch -p1 < ./0004-block-bfq-check-waker-only-for-queues-with-no-in-fli.patch;
    patch -p1 < ./0005-block-Do-not-pull-requests-from-the-scheduler-when-w.patch;
    patch -p1 < ./0006-block-Remove-unnecessary-elevator-operation-checks.patch;
    patch -p1 < ./0007-bfq-Remove-merged-request-already-in-bfq_requests_me.patch;
    patch -p1 < ./0008-blk-Fix-lock-inversion-between-ioc-lock-and-bfqd-loc.patch;
    patch -p1 < ./0009-block-bfq-remove-the-repeated-declaration.patch;
    patch -p1 < ./0013-block-return-ELEVATOR_DISCARD_MERGE-if-possible.patch;
    patch -p1 < ./0014-Revert-block-bfq-remove-the-repeated-declaration.patch;
    patch -p1 < ./0015-block-bfq-cleanup-the-repeated-declaration.patch;
    echo "*** Copying and applying block patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/block-patches-v3/*.patch .;
    patch -p1 < ./0001-block-patches.patch;
    echo "*** Copying and applying cjktty patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/cjktty-patches/*.patch .;
    patch -p1 < ./0001-cjktty-5.13-initial-import-from-https-github.com-zhm.patch;
    echo "*** Copying and applying clearlinux patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/clearlinux-patches-v2-sep/*.patch .;
    patch -p1 < ./0001-i8042-decrease-debug-message-level-to-info.patch;
    patch -p1 < ./0002-increase-the-ext4-default-commit-age.patch;
    patch -p1 < ./0003-silence-rapl.patch;
    patch -p1 < ./0004-pci-pme-wakeups.patch;
    patch -p1 < ./0005-ksm-wakeups.patch;
    patch -p1 < ./0006-intel_idle-tweak-cpuidle-cstates.patch;
    patch -p1 < ./0007-bootstats-add-printk-s-to-measure-boot-time-in-more-.patch;
    patch -p1 < ./0008-smpboot-reuse-timer-calibration.patch;
    patch -p1 < ./0009-initialize-ata-before-graphics.patch;
    patch -p1 < ./0010-give-rdrand-some-credit.patch;
    patch -p1 < ./0011-ipv4-tcp-allow-the-memory-tuning-for-tcp-to-go-a-lit.patch;
    patch -p1 < ./0012-init-wait-for-partition-and-retry-scan.patch;
    patch -p1 < ./0013-print-fsync-count-for-bootchart.patch;
    patch -p1 < ./0014-add-boot-option-to-allow-unsigned-modules.patch;
    patch -p1 < ./0015-enable-stateless-firmware-loading.patch;
    patch -p1 < ./0016-migrate-some-systemd-defaults-to-the-kernel-defaults.patch;
    patch -p1 < ./0017-xattr-allow-setting-user.-attributes-on-symlinks-by-.patch;
    patch -p1 < ./0018-use-lfence-instead-of-rep-and-nop.patch;
    if [ ${KERNEL_TYPE} == "rt" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/clearlinux/0019-do-accept-in-LIFO-order-for-cache-efficiency-rt.patch .;
        patch -p1 < ./0019-do-accept-in-LIFO-order-for-cache-efficiency-rt.patch;
    else
        patch -p1 < ./0019-do-accept-in-LIFO-order-for-cache-efficiency.patch;
    fi
    patch -p1 < ./0020-locking-rwsem-spin-faster.patch;
    patch -p1 < ./0021-ata-libahci-ignore-staggered-spin-up.patch;
    patch -p1 < ./0022-print-CPU-that-faults.patch;
    patch -p1 < ./0023-fix-bug-in-ucode-force-reload-revision-check.patch;
    patch -p1 < ./0024-nvme-workaround.patch;
    patch -p1 < ./0025-don-t-report-an-error-if-PowerClamp-run-on-other-CPU.patch;
    patch -p1 < ./0026-Port-microcode-patches.patch;
    echo "*** Copying and applying cpu graysky patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/cpu-patches-v2/*.patch .;
    patch -p1 < ./0001-cpu-patches.patch;
    echo "*** Copying and applying fixes misc patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/fixes/${KERNEL_BASE_VER}/5.13-fixes-miscellaneous-all-in-one.patch .;
    patch -p1 < ./5.13-fixes-miscellaneous-all-in-one.patch;
    echo "*** Copying and applying ksmbd patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/ksmbd-patches-v3/*.patch .;
    patch -p1 < ./0001-ksmbd-patches.patch;
    echo "*** Copying and applying lrng patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lrng-patches/*.patch .;
    patch -p1 < ./0001-lrng-patches.patch;
    echo "*** Copying and applying lru-mm patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lru-patches-v8/*.patch .;
    patch -p1 < ./0001-lru-patches.patch;
    echo "*** Copying and applying ntfs3 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/ntfs3-patches-v3/*.patch .;
    patch -p1 < ./0001-ntfs3-patches.patch;
    echo "*** Copying and applying pf patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/pf-patches-v12-sep/*.patch .;
    patch -p1 < ./0001-genirq-i2c-Provide-and-use-generic_dispatch_irq.patch;
    patch -p1 < ./0002-mac80211-minstrel_ht-force-ampdu_len-to-be-0.patch;
    patch -p1 < ./0003-net-replace-WARN_ONCE-with-pr_warn_once.patch;
    patch -p1 < ./0004-Revert-Revert-mm-shmem-fix-shmem_swapin-race-with-sw.patch;
    patch -p1 < ./0005-Revert-Revert-swap-fix-do_swap_page-race-with-swapof.patch;
    patch -p1 < ./0006-mm-compaction-optimize-proactive-compaction-deferral.patch;
    patch -p1 < ./0007-mm-compaction-support-triggering-of-proactive-compac.patch;
    patch -p1 < ./0008-x86-ACPI-State-Optimize-C3-entry-on-AMD-CPUs.patch;
    echo "*** Copying and applying spadfs patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/spadfs-patches/*.patch .;
    patch -p1 < ./0001-spadfs-5.13-merge-v1.0.14.patch;
    echo "*** Copying and applying swap patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/swap-patches/*.patch .;
    patch -p1 < ./0001-swap-patches.patch;
    echo "*** Copying and applying v4l2loopback-patches patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/v4l2loopback-patches-v2/*.patch .;
    patch -p1 < ./0001-v4l2loopback-patches.patch;
    echo "*** Copying and applying writeback patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/writeback-patches/*.patch .;
    patch -p1 < ./0001-writeback-patches.patch;
    echo "*** Copying and applying xanmod patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/xanmod-patches-v4/*.patch .;
    patch -p1 < ./0001-xanmod-patches.patch;
    echo "*** Copying and applying le9ec mm patch.. ✓";
    cp -v ${XANMOD_PATCH_PATH}/eol/linux-${KERNEL_BASE_VER}.y-xanmod/mm/*.patch .;
    patch -p1 < ./0001-mm-vmscan-add-sysctl-knobs-for-protecting-the-workin.patch;
    echo "*** Copying and applying zstd patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/zstd-patches-v5/*.patch .;
    patch -p1 < ./0001-zstd-patches.patch;
    echo "*** Copying and applying zen patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/zen-patches-sep/*.patch .;
    patch -p1 < ./0001-ZEN-Add-VHBA-driver.patch;
    patch -p1 < ./0002-ZEN-intel-pstate-Implement-enable-parameter.patch;
    patch -p1 < ./0003-ZEN-vhba-Update-to-20210418.patch;
    echo "*** Copying and applying ll patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/ll-patches/*.patch .;
    patch -p1 < ./0001-LL-kconfig-add-500Hz-timer-interrupt-kernel-config-o.patch;
    patch -p1 < ./0004-mm-set-8-megabytes-for-address_space-level-file-read.patch;
    echo "*** Copying and applying lqx patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lqx-patches-v2-sep/*.patch .;
    patch -p1 < ./0001-zen-Allow-MSR-writes-by-default.patch;
    patch -p1 < ./0002-PCI-Add-Intel-remapped-NVMe-device-support.patch;
    echo "*** Copying and applying cfs xanmod tweaks patch.. ✓";
    #https://github.com/xanmod/linux-patches/tree/master/eol/linux-5.13.y-xanmod
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/5.13-cfs-xanmod-tweaks.patch .;
    patch -p1 < ./5.13-cfs-xanmod-tweaks.patch;
    echo "*** Copying and applying misc xanmod tweaks patch.. ✓";
    cp -v ${XANMOD_PATCH_PATH}/eol/linux-5.13.y-xanmod/xanmod/*.patch .;
    patch -p1 < ./0005-XANMOD-kconfig-set-PREEMPT-and-RCU_BOOST-without-del.patch;
    patch -p1 < ./0006-XANMOD-dcache-cache_pressure-50-decreases-the-rate-a.patch;
    patch -p1 < ./0008-XANMOD-mm-vmscan-vm_swappiness-30-decreases-the-amou.patch;
    patch -p1 < ./0009-XANMOD-cpufreq-tunes-ondemand-and-conservative-gover.patch;
    patch -p1 < ./0011-XANMOD-lib-kconfig.debug-disable-default-CONFIG_SYMB.patch;
    echo "*** Copying and applying cfs zen tweaks patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/${KERNEL_SCHEDULER}-zen-tweaks.patch .;
    patch -p1 < ./${KERNEL_SCHEDULER}-zen-tweaks.patch;
    echo "*** Copying and applying disable memory compaction patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/5.13-disable-compaction-on-unevictable-pages.patch .;
    patch -p1 < ./5.13-disable-compaction-on-unevictable-pages.patch;
    echo "*** Copying and applying force irq threads patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/force-irq-threads.patch .;
    patch -p1 < ./force-irq-threads.patch;
    echo "*** Copying and applying increase writeback threshold patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/increase-default-writeback-thresholds.patch .;
    patch -p1 < ./increase-default-writeback-thresholds.patch;
    echo "*** Copying and applying enable background reclaim hugepages patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/enable-background-reclaim-hugepages.patch .;
    patch -p1 < ./enable-background-reclaim-hugepages.patch;
    if [ ${KERNEL_TYPE} == "rt" ]; then
        sed -i 's/sched_nr_migrate = 32/sched_nr_migrate = 256/g' ./kernel/sched/core.c;
        echo "*** Copying and applying Valve fsync patches.. ✓";
        cp -v ${CUSTOM_PATCH_PATH}/rt/${KERNEL_BASE_VER}/5-13-futex-rt.patch .;
        patch -p1 < ./5-13-futex-rt.patch;
        echo "*** Copying and applying Valve fsync fix patches.. ✓";
        cp -v ${CUSTOM_PATCH_PATH}/rt/${KERNEL_BASE_VER}/futex-rt-fix.patch .;
        patch -p1 < ./futex-rt-fix.patch;
    else
        echo "*** Copying and applying Valve fsync patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/futex-patches/*.patch .;
        patch -p1 < ./0001-futex-resync-from-gitlab.collabora.com.patch;
        echo "*** Copying and applying futex2 zen patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/futex2-zen-patches-v2/*.patch .;
        patch -p1 < ./0001-futex2-resync-from-gitlab.collabora.com.patch;
        patch -p1 < ./0003-sched-core-nr_migrate-256-increases-number-of-tasks-.patch;
        echo "*** Copying and applying ksm patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/ksm-patches/*.patch .;
        patch -p1 < ./0001-ksm-patches.patch;
    fi
elif [ ${KERNEL_BASE_VER} == "5.10" ]; then # LTS kernel, supported until 2026
    echo "*** Copying and applying pkill on warn.. (requires pkill_on_warn=1) ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/pkill-on-warn.patch .;
    patch -p1 < ./pkill-on-warn.patch;
    echo "*** Copying and applying arch patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/arch-patches-v14/*.patch .;
    patch -p1 < ./0001-arch-patches.patch;
    echo "*** Copying and applying bbr2 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/bbr2-patches-v3/*.patch .;
    patch -p1 < ./0001-bbr2-5.10-introduce-BBRv2.patch;
    echo "*** Copying and applying bfq patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/bfq-patches-v5-sep/*.patch .;
    patch -p1 < ./0001-block-bfq-use-half-slice_idle-as-a-threshold-to-chec.patch;
    patch -p1 < ./0002-block-bfq-set-next_rq-to-waker_bfqq-next_rq-in-waker.patch;
    patch -p1 < ./0003-block-bfq-increase-time-window-for-waker-detection.patch;
    patch -p1 < ./0004-block-bfq-do-not-raise-non-default-weights.patch;
    patch -p1 < ./0005-block-bfq-avoid-spurious-switches-to-soft_rt-of-inte.patch;
    patch -p1 < ./0006-block-bfq-do-not-expire-a-queue-when-it-is-the-only-.patch;
    patch -p1 < ./0007-block-bfq-replace-mechanism-for-evaluating-I-O-inten.patch;
    patch -p1 < ./0008-block-bfq-re-evaluate-convenience-of-I-O-plugging-on.patch;
    patch -p1 < ./0009-block-bfq-fix-switch-back-from-soft-rt-weitgh-raisin.patch;
    patch -p1 < ./0010-block-bfq-save-also-weight-raised-service-on-queue-m.patch;
    patch -p1 < ./0011-block-bfq-save-also-injection-state-on-queue-merging.patch;
    patch -p1 < ./0012-block-bfq-make-waker-queue-detection-more-robust.patch;
    patch -p1 < ./0013-bfq-bfq_check_waker-should-be-static.patch;
    patch -p1 < ./0014-block-bfq-always-inject-I-O-of-queues-blocked-by-wak.patch;
    patch -p1 < ./0015-block-bfq-put-reqs-of-waker-and-woken-in-dispatch-li.patch;
    patch -p1 < ./0016-block-bfq-make-shared-queues-inherit-wakers.patch;
    patch -p1 < ./0017-block-bfq-fix-weight-raising-resume-with-low_latency.patch;
    patch -p1 < ./0018-block-bfq-keep-shared-queues-out-of-the-waker-mechan.patch;
    patch -p1 < ./0020-bfq-don-t-duplicate-code-for-different-paths.patch;
    patch -p1 < ./0022-bfq-Use-ttime-local-variable.patch;
    patch -p1 < ./0023-bfq-Use-only-idle-IO-periods-for-think-time-calculat.patch;
    patch -p1 < ./0024-bfq-Remove-stale-comment.patch;
    patch -p1 < ./0025-Revert-bfq-Remove-stale-comment.patch;
    echo "*** Copying and applying block patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/block-patches-v3/*.patch .;
    patch -p1 < ./0001-block-patches.patch;
    echo "*** Copying and applying btrfs patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/btrfs-patches-v14-sep/*.patch .;
    patch -p1 < ./0001-btrfs-add-a-force_chunk_alloc-to-space_info-s-sysfs.patch;
    patch -p1 < ./0002-btrfs-restart-snapshot-delete-if-we-have-to-end-the-.patch;
    patch -p1 < ./0003-btrfs-do-not-evaluate-the-expression-with-CONFIG_BTR.patch;
    patch -p1 < ./0004-btrfs-remove-unnecessary-attempt-do-drop-extent-maps.patch;
    patch -p1 < ./0005-btrfs-stop-incrementing-log-batch-when-joining-log-t.patch;
    patch -p1 < ./0007-btrfs-fix-race-that-results-in-logging-old-extents-d.patch;
    patch -p1 < ./0008-btrfs-fix-race-that-causes-unnecessary-logging-of-an.patch;
    patch -p1 < ./0009-btrfs-fix-race-that-makes-inode-logging-fallback-to-.patch;
    patch -p1 < ./0010-btrfs-fix-race-leading-to-unnecessary-transaction-co.patch;
    patch -p1 < ./0011-btrfs-do-not-block-inode-logging-for-so-long-during-.patch;
    patch -p1 < ./0012-btrfs-return-bool-from-should_end_transaction.patch;
    patch -p1 < ./0013-btrfs-return-bool-from-btrfs_should_end_transaction.patch;
    patch -p1 < ./0014-btrfs-do-not-block-on-deleted-bgs-mutex-in-the-clean.patch;
    patch -p1 < ./0015-btrfs-only-let-one-thread-pre-flush-delayed-refs-in-.patch;
    patch -p1 < ./0016-btrfs-delayed-refs-pre-flushing-should-only-run-the-.patch;
    patch -p1 < ./0017-btrfs-only-run-delayed-refs-once-before-committing.patch;
    patch -p1 < ./0018-btrfs-move-delayed-ref-flushing-for-qgroup-into-qgro.patch;
    patch -p1 < ./0019-btrfs-remove-bogus-BUG_ON-in-alloc_reserved_tree_blo.patch;
    patch -p1 < ./0020-btrfs-stop-running-all-delayed-refs-during-snapshot.patch;
    patch -p1 < ./0021-btrfs-run-delayed-refs-less-often-in-commit_cowonly_.patch;
    patch -p1 < ./0022-btrfs-make-flush_space-take-a-enum-btrfs_flush_state.patch;
    patch -p1 < ./0023-btrfs-add-a-trace-point-for-reserve-tickets.patch;
    patch -p1 < ./0024-btrfs-track-ordered-bytes-instead-of-just-dio-ordere.patch;
    patch -p1 < ./0025-btrfs-introduce-a-FORCE_COMMIT_TRANS-flush-operation.patch;
    patch -p1 < ./0026-btrfs-improve-preemptive-background-space-flushing.patch;
    patch -p1 < ./0027-btrfs-rename-need_do_async_reclaim.patch;
    patch -p1 < ./0028-btrfs-check-reclaim_size-in-need_preemptive_reclaim.patch;
    patch -p1 < ./0029-btrfs-rework-btrfs_calc_reclaim_metadata_size.patch;
    patch -p1 < ./0030-btrfs-simplify-the-logic-in-need_preemptive_flushing.patch;
    patch -p1 < ./0031-btrfs-implement-space-clamping-for-preemptive-flushi.patch;
    patch -p1 < ./0032-btrfs-adjust-the-flush-trace-point-to-include-the-so.patch;
    patch -p1 < ./0033-btrfs-add-a-trace-class-for-dumping-the-current-ENOS.patch;
    patch -p1 < ./0036-btrfs-remove-unnecessary-directory-inode-item-update.patch;
    patch -p1 < ./0037-btrfs-stop-setting-nbytes-when-filling-inode-item-fo.patch;
    patch -p1 < ./0038-btrfs-avoid-logging-new-ancestor-inodes-when-logging.patch;
    patch -p1 < ./0039-btrfs-skip-logging-directories-already-logged-when-l.patch;
    patch -p1 < ./0040-btrfs-skip-logging-inodes-already-logged-when-loggin.patch;
    patch -p1 < ./0041-btrfs-remove-unnecessary-check_parent_dirs_for_sync.patch;
    patch -p1 < ./0042-btrfs-make-concurrent-fsyncs-wait-less-when-waiting-.patch;
    echo "*** Copying and applying clearlinux patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/clearlinux-patches-sep/*.patch .;
    patch -p1 < ./0001-i8042-decrease-debug-message-level-to-info.patch;
    patch -p1 < ./0002-Increase-the-ext4-default-commit-age.patch;
    patch -p1 < ./0003-silence-rapl.patch;
    patch -p1 < ./0004-pci-pme-wakeups.patch;
    patch -p1 < ./0005-ksm-wakeups.patch;
    patch -p1 < ./0006-intel_idle-tweak-cpuidle-cstates.patch;
    patch -p1 < ./0007-bootstats-add-printk-s-to-measure-boot-time-in-more-.patch;
    patch -p1 < ./0008-smpboot-reuse-timer-calibration.patch;
    patch -p1 < ./0009-Initialize-ata-before-graphics.patch;
    patch -p1 < ./0010-give-rdrand-some-credit.patch;
    patch -p1 < ./0011-ipv4-tcp-allow-the-memory-tuning-for-tcp-to-go-a-lit.patch;
    patch -p1 < ./0012-kernel-time-reduce-ntp-wakeups.patch;
    patch -p1 < ./0013-init-wait-for-partition-and-retry-scan.patch;
    patch -p1 < ./0014-print-fsync-count-for-bootchart.patch;
    patch -p1 < ./0015-Add-boot-option-to-allow-unsigned-modules.patch;
    patch -p1 < ./0016-Enable-stateless-firmware-loading.patch;
    patch -p1 < ./0017-Migrate-some-systemd-defaults-to-the-kernel-defaults.patch;
    patch -p1 < ./0018-xattr-allow-setting-user.-attributes-on-symlinks-by-.patch;
    patch -p1 < ./0019-use-lfence-instead-of-rep-and-nop.patch;
    patch -p1 < ./0021-locking-rwsem-spin-faster.patch;
    patch -p1 < ./0022-ata-libahci-ignore-staggered-spin-up.patch;
    patch -p1 < ./0023-print-CPU-that-faults.patch;
    patch -p1 < ./0025-nvme-workaround.patch;
    patch -p1 < ./0026-Don-t-report-an-error-if-PowerClamp-run-on-other-CPU.patch;
    patch -p1 < ./0028-clearlinux-Add-pageflip-patches.patch;
    echo "*** Copying and applying cpu graysky patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/cpu-patches-v2/*.patch .;
    patch -p1 < ./0001-cpu-patches.patch;
    echo "*** Copying and applying fixes misc patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/fixes-miscellaneous-v11-sep/*.patch .;
    patch -p1 < ./0001-net-sched-allow-configuring-cake-qdisc-as-default.patch;
    patch -p1 < ./0002-infiniband-Fix-__read_overflow2-error-with-O3-inlini.patch;
    patch -p1 < ./0003-kbuild-add-fcf-protection-none-to-retpoline-flags.patch;
    patch -p1 < ./0004-mm-Disable-watermark-boosting-by-default.patch;
    patch -p1 < ./0005-mm-Stop-kswapd-early-when-nothing-s-waiting-for-it-t.patch;
    patch -p1 < ./0006-mm-Fully-disable-watermark-boosting-when-it-isn-t-us.patch;
    patch -p1 < ./0007-mm-Don-t-stop-kswapd-on-a-per-node-basis-when-there-.patch;
    patch -p1 < ./0008-kbuild-Disable-stack-conservation-for-GCC.patch;
    patch -p1 < ./0009-pci-Enable-overrides-for-missing-ACS-capabilities.patch;
    patch -p1 < ./0010-ZEN-Add-OpenRGB-patches.patch;
    patch -p1 < ./0012-scsi-sd-Optimal-I-O-size-should-be-a-multiple-of-rep.patch;
    patch -p1 < ./0014-fs-Break-generic_file_buffered_read-up-into-multiple.patch;
    patch -p1 < ./0015-fs-generic_file_buffered_read-now-uses-find_get_page.patch;
    patch -p1 < ./0016-iomap-avoid-deadlock-if-memory-reclaim-is-triggered-.patch;
    patch -p1 < ./0017-mm-Add-become_kswapd-and-restore_kswapd.patch;
    patch -p1 < ./0018-xfs-fix-an-ABBA-deadlock-in-xfs_rename.patch;
    patch -p1 < ./0019-xfs-use-memalloc_nofs_-save-restore-in-xfs-transacti.patch;
    patch -p1 < ./0020-xfs-refactor-the-usage-around-xfs_trans_context_-set.patch;
    patch -p1 < ./0021-xfs-use-current-journal_info-to-avoid-transaction-re.patch;
    patch -p1 < ./0022-xfs-set-inode-size-after-creating-symlink.patch;
    patch -p1 < ./0023-xfs-restore-shutdown-check-in-mapped-write-fault-pat.patch;
    echo "*** Copying and applying futex misc patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/futex-patches/*.patch .;
    patch -p1 < ./0001-futex-patches.patch;
    echo "*** Copying and applying hwmon patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/5.14/hwmon-patches/*.patch .;
    patch -p1 < ./0001-hwmon-patches.patch;
    echo "*** Copying and applying lqx patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/lqx-patches-v4/*.patch .;
    patch -p1 < ./0001-lqx-patches.patch;
    echo "*** Copying and applying mm patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/mm-patches-v4/*.patch .;
    patch -p1 < ./0001-mm-patches.patch;
    echo "*** Copying and applying ntfs3 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/ntfs3-patches-v7/*.patch .;
    patch -p1 < ./0001-ntfs3-patches.patch;
    echo "*** Copying and applying pf patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/pf-patches-v9-sep/*.patch .;
    patch -p1 < ./0001-genirq-i2c-Provide-and-use-generic_dispatch_irq.patch;
    patch -p1 < ./0002-genirq-i2c-export-generic_dispatch_irq.patch;
    echo "*** Copying and applying rapl patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/rapl-patches/*.patch .;
    patch -p1 < ./0001-rapl-patches.patch;
    echo "*** Copying and applying v4l2loopback patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/v4l2loopback-patches-v2/*.patch .;
    patch -p1 < ./0001-v4l2loopback-patches.patch;
    echo "*** Copying and applying xanmod patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/xanmod-patches/*.patch .;
    patch -p1 < ./0001-sched-autogroup-Add-kernel-parameter-and-config-opti.patch;
    echo "*** Copying and applying zstd patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/zstd-patches-v3/*.patch .;
    patch -p1 < ./0001-init-add-support-for-zstd-compressed-modules.patch;
    echo "*** Copying and applying zstd upstream patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/${KERNEL_BASE_VER}/zstd-upstream-patches/*.patch .;
    patch -p1 < ./0001-zstd-upstream-patches.patch;
    echo "*** Copying and applying ll patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/ll-patches/*.patch .;
    patch -p1 < ./0001-LL-kconfig-add-500Hz-timer-interrupt-kernel-config-o.patch;
    patch -p1 < ./0004-mm-set-8-megabytes-for-address_space-level-file-read.patch;
    echo "*** Copying and applying misc xanmod tweaks patch.. ✓";
    cp -v ${XANMOD_PATCH_PATH}/linux-5.10.y-xanmod/xanmod/*.patch .;
    if [ ${KERNEL_TYPE} != "rt" ]; then
        patch -p1 < ./0005-kconfig-set-PREEMPT-and-RCU_BOOST-without-delay-by-d.patch;
    fi
    patch -p1 < ./0006-dcache-cache_pressure-50-decreases-the-rate-at-which.patch;
    patch -p1 < ./0008-mm-vmscan-vm_swappiness-30-decreases-the-amount-of-s.patch;
    patch -p1 < ./0009-cpufreq-tunes-ondemand-and-conservative-governor-for.patch;
    patch -p1 < ./0011-lib-kconfig.debug-disable-default-CONFIG_SYMBOLIC_ER.patch;
    patch -p1 < ./0013-XANMOD-fair-Remove-all-energy-efficiency-functions.patch;
    patch -p1 < ./0014-XANMOD-Makefile-Turn-off-loop-vectorization-for-GCC-.patch;
    echo "*** Copying and applying disable memory compaction patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/5.13-disable-compaction-on-unevictable-pages.patch .;
    patch -p1 < ./5.13-disable-compaction-on-unevictable-pages.patch;
    echo "*** Copying and applying force irq threads patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/force-irq-threads.patch .;
    patch -p1 < ./force-irq-threads.patch;
    echo "*** Copying and applying increase writeback threshold patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/increase-default-writeback-thresholds.patch .;
    patch -p1 < ./increase-default-writeback-thresholds.patch;
    echo "*** Copying and applying enable background reclaim hugepages patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/enable-background-reclaim-hugepages.patch .;
    patch -p1 < ./enable-background-reclaim-hugepages.patch;
    if [ ${KERNEL_TYPE} == "rt" ]; then
        sed -i 's/sched_nr_migrate = 32/sched_nr_migrate = 256/g' ./kernel/sched/core.c;
    else
        patch -p1 < ./0003-sched-core-nr_migrate-256-increases-number-of-tasks-.patch;
    fi
    if [ ${KERNEL_SCHEDULER} != "cacule" ]; then
        echo "*** Copying and applying cfs zen tweaks patch.. ✓";
        cp -v ${CUSTOM_PATCH_PATH}/tweaks/cfs-zen-tweaks.patch .;
        patch -p1 < ./cfs-zen-tweaks.patch;
    fi
elif [ ${KERNEL_BASE_VER} == "5.4" ]; then  # LTS kernel, supported until 2025
    echo "*** Copying and applying freesync patches from 5.10.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/amdgpu/freesync-refresh/*.patch .;
    patch -p1 < ./01_freesync_refresh.patch;
    patch -p1 < ./02_freesync_refresh.patch;
    patch -p1 < ./03_freesync_refresh.patch;
    patch -p1 < ./04_freesync_refresh.patch;
    patch -p1 < ./05_freesync_refresh.patch;
    patch -p1 < ./06_freesync_refresh.patch;
    echo "*** Copying and applying fsgsbase patches.. ✓";
    #https://lkml.org/lkml/2019/10/4/725 - v9 is for 5.4 and earlier
    cp -v ${CUSTOM_PATCH_PATH}/fsgsbase/v9/v9*.patch .;
    for i in {1..17}; do
        patch -p1 < ./v9-${i}.patch;
    done
    echo "*** Copying and applying block 5.4 patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/${KERNEL_BASE_VER}/block-patches-v2-sep/*.patch .;
    patch -p1 < ./0001-block-Kconfig.iosched-set-default-value-of-IOSCHED_B.patch;
    patch -p1 < ./0002-block-Fix-depends-for-BLK_DEV_ZONED.patch;
    patch -p1 < ./0003-block-set-rq_affinity-2-for-full-multithreading-I-O-.patch;
    echo "*** Copying and applying block 5.6 patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/5.6/block-patches-v3-sep/*.patch .;
    patch -p1 < ./0004-blk-mq-remove-the-bio-argument-to-prepare_request.patch;
    patch -p1 < ./0005-block-Flag-elevators-suitable-for-single-queue.patch;
    echo "*** Copying and applying block 5.7 patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/5.7/block-patches-v5-sep/*.patch .;
    patch -p1 < ./0006-block-bfq-iosched-fix-duplicated-word.patch;
    patch -p1 < ./0007-block-bio-delete-duplicated-words.patch;
    patch -p1 < ./0008-block-elevator-delete-duplicated-word-and-fix-typos.patch;
    patch -p1 < ./0009-block-blk-timeout-delete-duplicated-word.patch;
    echo "*** Copying and applying block 5.8 patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/5.8/block-patches-v6-sep/*.patch .;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-block-5.8-0011-block-Convert-to-use-the-preferred-fallthrough-macro*.patch .;
    patch -p1 < ./5.4-block-5.8-0011-block-Convert-to-use-the-preferred-fallthrough-macro-part1.patch;
    patch -p1 < ./5.4-block-5.8-0011-block-Convert-to-use-the-preferred-fallthrough-macro-part2.patch;
    patch -p1 < ./0012-block-bfq-Disable-low_latency-when-blk_iolatency-is-.patch;
    echo "*** Copying and applying block 5.10 patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-block-5.10-elevator-mq-aware.patch .;
    patch -p1 <./5.4-block-5.10-elevator-mq-aware.patch;
    echo "*** Copying and applying block 5.12 patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-block-5.12-0008-block-Remove-unnecessary-elevator-operation-checks*.patch .;
    patch -p1 < ./5.4-block-5.12-0008-block-Remove-unnecessary-elevator-operation-checks.patch;
    patch -p1 < ./5.4-block-5.12-0008-block-Remove-unnecessary-elevator-operation-checks-part2.patch;
    echo "*** Copying and applying BFQ 5.4 patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/${KERNEL_BASE_VER}/bfq-patches-sep/*.patch .;
    patch -p1 < ./0001-blkcg-Make-bfq-disable-iocost-when-enabled.patch;
    patch -p1 < ./0002-block-bfq-present-a-double-cgroups-interface.patch;
    patch -p1 < ./0003-block-bfq-Skip-tracing-hooks-if-possible.patch;
    echo "*** Copying and applying BFQ 5.7 patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/5.7/bfq-patches-v5-sep/*.patch .;
    patch -p1 < ./0001-bfq-Fix-check-detecting-whether-waker-queue-should-b.patch;
    patch -p1 < ./0002-bfq-Allow-short_ttime-queues-to-have-waker.patch;
    echo "*** Copying and applying BFQ 5.10 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/5.10/bfq-patches-v5-sep/*.patch .;
    patch -p1 < ./0003-block-bfq-increase-time-window-for-waker-detection.patch;
    patch -p1 < ./0004-block-bfq-do-not-raise-non-default-weights.patch;
    patch -p1 < ./0005-block-bfq-avoid-spurious-switches-to-soft_rt-of-inte.patch;
    patch -p1 < ./0006-block-bfq-do-not-expire-a-queue-when-it-is-the-only-.patch;
    patch -p1 < ./0008-block-bfq-re-evaluate-convenience-of-I-O-plugging-on.patch;
    patch -p1 < ./0009-block-bfq-fix-switch-back-from-soft-rt-weitgh-raisin.patch;
    patch -p1 < ./0010-block-bfq-save-also-weight-raised-service-on-queue-m.patch;
    patch -p1 < ./0011-block-bfq-save-also-injection-state-on-queue-merging.patch;
    patch -p1 < ./0014-block-bfq-always-inject-I-O-of-queues-blocked-by-wak.patch;
    patch -p1 < ./0015-block-bfq-put-reqs-of-waker-and-woken-in-dispatch-li.patch;
    patch -p1 < ./0018-block-bfq-keep-shared-queues-out-of-the-waker-mechan.patch;
    patch -p1 < ./0020-bfq-don-t-duplicate-code-for-different-paths.patch;
    patch -p1 < ./0022-bfq-Use-ttime-local-variable.patch;
    patch -p1 < ./0023-bfq-Use-only-idle-IO-periods-for-think-time-calculat.patch;
    patch -p1 < ./0024-bfq-Remove-stale-comment.patch;
    patch -p1 < ./0025-Revert-bfq-Remove-stale-comment.patch;
    echo "*** Copying and applying BFQ 5.11 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/5.11/bfq-patches-v7-sep/*.patch .;
    patch -p1 < ./0023-block-bfq-update-comments-and-default-value-in-docs-.patch;
    patch -p1 < ./0028-Revert-block-bfq-put-reqs-of-waker-and-woken-in-disp.patch;
    patch -p1 < ./0029-Revert-block-bfq-always-inject-I-O-of-queues-blocked.patch;
    patch -p1 < ./0030-block-bfq-always-inject-I-O-of-queues-blocked-by-wak.patch;
    patch -p1 < ./0031-block-bfq-put-reqs-of-waker-and-woken-in-dispatch-li.patch;
    patch -p1 < ./0037-block-bfq-fix-the-timeout-calculation-in-bfq_bfqq_ch.patch;
    patch -p1 < ./0038-blk-mq-bypass-IO-scheduler-s-limit_depth-for-passthr.patch;
    patch -p1 < ./0039-bfq-mq-deadline-remove-redundant-check-for-passthrou.patch;
    echo "*** Copying and applying BFQ 5.12 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/5.12/bfq-patches-v15-sep/*.patch .;
    patch -p1 < ./0024-block-bfq-remove-the-repeated-declaration.patch;
    echo "*** Copying and applying BFQ 5.13 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/5.13/bfq-patches-v7-sep/*.patch .;
    patch -p1 < ./0007-bfq-Remove-merged-request-already-in-bfq_requests_me.patch;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/0008-blk-Fix-lock-inversion-between-ioc-lock-and-bfqd-loc.patch .;
    patch -p1 < ./0008-blk-Fix-lock-inversion-between-ioc-lock-and-bfqd-loc.patch;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-from-5.13-0008-blk-Fix-lock-inversion-merge-fix*.patch .;
    patch -p1 < ./5.4-from-5.13-0008-blk-Fix-lock-inversion-merge-fix-part1.patch;
    patch -p1 < ./5.4-from-5.13-0008-blk-Fix-lock-inversion-merge-fix-part2.patch;
    patch -p1 < ./0014-Revert-block-bfq-remove-the-repeated-declaration.patch;
    patch -p1 < ./0015-block-bfq-cleanup-the-repeated-declaration.patch;
    echo "*** Copying and applying Valve fsync/futex patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/5.10/futex-patches/0001-futex-patches.patch .;
    patch -p1 < ./0001-futex-patches.patch;
    echo "*** Copying and applying misc fixes patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/${KERNEL_BASE_VER}/fixes-miscellaneous-v5/*.patch .;
    patch -p1 < ./0001-fixes-miscellaneous.patch;
    echo "*** Copying and applying misc fixes 5.14 patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/0004-mm-Stop-kswapd-early-when-nothing-s-waiting-for-it-t.patch .;
    patch -p1 < ./0004-mm-Stop-kswapd-early-when-nothing-s-waiting-for-it-t.patch;
    cp -v ${LUCJAN_PATCH_PATH}/5.14/fixes-miscellaneous-sep/*.patch .;
    patch -p1 < ./0005-mm-Fully-disable-watermark-boosting-when-it-isn-t-us.patch;
    patch -p1 < ./0007-kbuild-Disable-stack-conservation-for-GCC.patch;
    patch -p1 < ./0008-pci-Enable-overrides-for-missing-ACS-capabilities.patch;
    patch -p1 < ./0009-ZEN-Add-OpenRGB-patches.patch;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/0010-scsi-sd-Optimal-I-O-size-should-be-a-multiple-of-rep.patch .;
    patch -p1 < ./0010-scsi-sd-Optimal-I-O-size-should-be-a-multiple-of-rep.patch;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-from-5.14-0010-scsi-sd-Optimal-I-O-size-merge-fix.patch .;
    patch -p1 < ./5.4-from-5.14-0010-scsi-sd-Optimal-I-O-size-merge-fix.patch;
    echo "*** Copying and applying cve patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/${KERNEL_BASE_VER}/cve-patches-v8-sep/*.patch .;
    patch -p1 < ./0001-consolemap-Fix-a-memory-leaking-bug-in-drivers-tty-v.patch;
    echo "*** Copying and applying exfat patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/${KERNEL_BASE_VER}/exfat-patches/*.patch .;
    patch -p1 < ./0001-exfat-patches.patch;
    echo "*** Copying and applying SCSI patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/${KERNEL_BASE_VER}/scsi-patches/*.patch .;
    patch -p1 < ./0001-scsi-patches.patch;
    echo "*** Copying and applying ll patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/ll-patches/*.patch .;
    patch -p1 < ./0001-LL-kconfig-add-500Hz-timer-interrupt-kernel-config-o.patch;
    patch -p1 < ./0002-LL-elevator-set-default-scheduler-to-bfq-for-blk-mq.patch;
    patch -p1 < ./mm-set-8MB.patch;
    echo "*** Copying and applying xanmod patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/0001-sched-autogroup-Add-kernel-parameter-and-config-opti.patch .;
    patch -p1 < ./0001-sched-autogroup-Add-kernel-parameter-and-config-opti.patch;
    echo "*** Copying and applying cfs xanmod energy tweaks patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/5.4-cfs-xanmod-tweaks.patch .;
    patch -p1 < ./5.4-cfs-xanmod-tweaks.patch;
    echo "*** Copying and applying intel_cpufreq patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/5.6/0001-cpufreq*.patch .;
    patch -p1 < ./0001-cpufreq-intel_pstate-Set-default-cpufreq_driver-to-i.patch;
    # https://github.com/zen-kernel/zen-kernel/commit/7de2596b35ac1dbf55fb384f3d668a7315635c0b
    echo "*** Copying and applying cfs zen tweaks patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/cfs-zen-tweaks.patch .;
    patch -p1 < ./cfs-zen-tweaks.patch;
    echo "*** Copying and applying force irq threads patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/force-irq-threads.patch .;
    patch -p1 < ./force-irq-threads.patch;
    echo "*** Copying and applying increase writeback threshold patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/increase-default-writeback-thresholds.patch .;
    patch -p1 < ./increase-default-writeback-thresholds.patch;
    echo "*** Copying and applying enable background reclaim hugepages patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/enable-background-reclaim-hugepages.patch .;
    patch -p1 < ./enable-background-reclaim-hugepages.patch;
    echo "*** Copying and applying graysky's GCC patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/graysky/graysky-gcc-4.19-through-5.4.patch .;
    patch -p1 < ./graysky-gcc-4.19-through-5.4.patch;
    echo "*** Copying and applying O3 patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/O3-optimization/O3-v5.4+.patch .;
    patch -p1 < ./O3-v5.4+.patch;
    echo "*** Copying and applying O3 fix patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/O3-optimization/0004-Makefile-Turn-off-loop-vectorization-for-GCC-O3-opti.patch .;
    patch -p1 < ./0004-Makefile-Turn-off-loop-vectorization-for-GCC-O3-opti.patch;
    echo "*** Copying and applying arch 5.7 patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/5.7/arch-patches-v9-sep/*.patch .;
    patch -p1 < ./0004-virt-vbox-Add-support-for-the-new-VBG_IOCTL_ACQUIRE_.patch;
    echo "*** Copying and applying arch 5.9 patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/5.9/arch-patches-v9-sep/*.patch .;
    patch -p1 < ./0004-HID-quirks-Add-Apple-Magic-Trackpad-2-to-hid_have_sp.patch;
    echo "*** Copying and applying arch 5.12 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/5.12/arch-patches-v7-sep/*.patch .;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-from-5.12-arch-0002-x86-setup-Consolidate-early-memory-reservations.patch .;
    patch -p1 < ./5.4-from-5.12-arch-0002-x86-setup-Consolidate-early-memory-reservations.patch;
    patch -p1 < ./0003-x86-setup-Merge-several-reservations-of-start-of-mem.patch;
    patch -p1 < ./0004-x86-setup-Move-trim_snb_memory-later-in-setup_arch-t.patch;
    patch -p1 < ./0005-x86-setup-always-reserve-the-first-1M-of-RAM.patch;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-from-5.12-arch-reserve_bios_regions.patch .;
    patch -p1 < ./5.4-from-5.12-arch-reserve_bios_regions.patch;
    patch -p1 < ./0007-x86-crash-remove-crash_reserve_low_1M.patch;
    echo "*** Copying and applying Clear Linux patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/lucjan/${KERNEL_BASE_VER}/clearlinux-patches-v6-sep/*.patch .;
    patch -p1 < ./0006-intel_idle-tweak-cpuidle-cstates.patch;
    patch -p1 < ./0009-raid6-add-Kconfig-option-to-skip-raid6-benchmarking.patch;
    patch -p1 < ./0016-Add-boot-option-to-allow-unsigned-modules.patch;
    patch -p1 < ./0020-use-lfence-instead-of-rep-and-nop.patch;
    echo "*** Copying and applying Clear Linux patches from 5.10.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/clearlinux/*.patch .;
    patch -p1 < ./0001-i8042-decrease-debug-message-level-to-info.patch;
    patch -p1 < ./0002-Increase-the-ext4-default-commit-age.patch;
    patch -p1 < ./0003-silence-rapl.patch;
    patch -p1 < ./0004-pci-pme-wakeups.patch;
    patch -p1 < ./0005-ksm-wakeups.patch;
    patch -p1 < ./0007-bootstats-add-printk-s-to-measure-boot-time-in-more-.patch;
    patch -p1 < ./0008-smpboot-reuse-timer-calibration.patch;
    patch -p1 < ./0009-Initialize-ata-before-graphics.patch;
    patch -p1 < ./0010-give-rdrand-some-credit.patch;
    patch -p1 < ./0011-ipv4-tcp-allow-the-memory-tuning-for-tcp-to-go-a-lit.patch;
    patch -p1 < ./0012-kernel-time-reduce-ntp-wakeups.patch;
    patch -p1 < ./0013-init-wait-for-partition-and-retry-scan.patch;
    patch -p1 < ./0014-print-fsync-count-for-bootchart.patch;
    patch -p1 < ./0016-Enable-stateless-firmware-loading.patch;
    patch -p1 < ./0017-Migrate-some-systemd-defaults-to-the-kernel-defaults.patch;
    patch -p1 < ./0018-xattr-allow-setting-user.-attributes-on-symlinks-by-.patch;
    patch -p1 < ./0020-do-accept-in-LIFO-order-for-cache-efficiency.patch;
    patch -p1 < ./include-linux-wait-h-merge-fix.patch;
    patch -p1 < ./0021-locking-rwsem-spin-faster.patch;
    patch -p1 < ./0022-ata-libahci-ignore-staggered-spin-up.patch;
    patch -p1 < ./0023-print-CPU-that-faults.patch;
    patch -p1 < ./0025-nvme-workaround.patch;
    patch -p1 < ./0026-Don-t-report-an-error-if-PowerClamp-run-on-other-CPU.patch;
    if [ ${KERNEL_TYPE} == "rt" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/lucjan/${KERNEL_BASE_VER}/arch-patches-rt-v3-sep/*.patch .;
        patch -p1 < ./0001-ZEN-Add-sysctl-and-CONFIG-to-disallow-unprivileged-C.patch;
        patch -p1 < ./0007-iwlwifi-pcie-restore-support-for-Killer-Qu-C0-NICs.patch;
        patch -p1 < ./0008-drm-i915-save-AUD_FREQ_CNTRL-state-at-audio-domain-s.patch;
        patch -p1 < ./0010-drm-i915-Fix-audio-power-up-sequence-for-gen10-displ.patch;
        patch -p1 < ./0011-drm-i915-extend-audio-CDCLK-2-BCLK-constraint-to-mor.patch;
        patch -p1 < ./0012-drm-i915-Limit-audio-CDCLK-2-BCLK-constraint-back-to.patch;
        patch -p1 < ./0016-drm-amdgpu-Add-DC-feature-mask-to-disable-fractional.patch;
        sed -i 's/sched_nr_migrate = 32/sched_nr_migrate = 256/g' ./kernel/sched/core.c;
        echo "*** Copying and applying arch-rt 5.4 patches.. ✓";
    else
        patch -p1 < ./0003-sched-core-nr_migrate-256-increases-number-of-tasks-.patch;
        echo "*** Copying and applying arch 5.4 patches.. ✓";
        cp -v ${CUSTOM_PATCH_PATH}/lucjan/${KERNEL_BASE_VER}/arch-patches-v25-sep/*.patch .;
        patch -p1 < ./0001-ZEN-Add-sysctl-and-CONFIG-to-disallow-unprivileged-C.patch;
        patch -p1 < ./0005-iwlwifi-pcie-restore-support-for-Killer-Qu-C0-NICs.patch;
        patch -p1 < ./0006-drm-i915-save-AUD_FREQ_CNTRL-state-at-audio-domain-s.patch;
        patch -p1 < ./0007-drm-i915-Fix-audio-power-up-sequence-for-gen10-displ.patch;
        patch -p1 < ./0008-drm-i915-extend-audio-CDCLK-2-BCLK-constraint-to-mor.patch;
        patch -p1 < ./0009-drm-i915-Limit-audio-CDCLK-2-BCLK-constraint-back-to.patch;
        patch -p1 < ./0010-drm-amdgpu-Add-DC-feature-mask-to-disable-fractional.patch;
    fi
    echo "*** Copying and applying swap patches.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-from-5.13-swap-*.patch .;
    patch -p1 < ./5.4-from-5.13-swap-0001-swap-patches.patch;
    patch -p1 < ./5.4-from-5.13-swap-merge-fix-new.patch;
    echo "*** Copying and applying ck-hrtimer patches.. ✓";
    cp -v ${XANMOD_PATCH_PATH}/linux-5.10.y-xanmod/ck-hrtimer/*.patch .;
    patch -p1 < ./0001-Create-highres-timeout-variants-of-schedule_timeout-.patch;
    patch -p1 < ./0002-Special-case-calls-of-schedule_timeout-1-to-use-the-.patch;
    patch -p1 < ./0003-Convert-msleep-to-use-hrtimers-when-active.patch;
    patch -p1 < ./0005-Replace-all-calls-to-schedule_timeout_interruptible-.patch;
    patch -p1 < ./0006-Replace-all-calls-to-schedule_timeout_uninterruptibl.patch;
    patch -p1 < ./0007-Don-t-use-hrtimer-overlay-when-pm_freezing-since-som.patch;
    patch -p1 < ./0008-clockevents-hrtimer-Make-hrtimer-granularity-and-min.patch;
    echo "*** Copying and applying modules patches.. ✓";
    cp -v ${XANMOD_PATCH_PATH}/linux-5.10.y-xanmod/modules/*.patch .;
    patch -p1 < ./0001-modules-disinherit-taint-proprietary-module.patch;
    echo "*** Copying and applying misc xanmod tweaks.. ✓";
    cp -v ${XANMOD_PATCH_PATH}/linux-5.10.y-xanmod/xanmod/*.patch .;
    if [ ${KERNEL_TYPE} != "rt" ]; then
        patch -p1 < ./0005-kconfig-set-PREEMPT-and-RCU_BOOST-without-delay-by-d.patch;
    fi
    patch -p1 < ./0006-dcache-cache_pressure-50-decreases-the-rate-at-which.patch;
    patch -p1 < ./0009-cpufreq-tunes-ondemand-and-conservative-governor-for.patch;
    patch -p1 < ./0010-scripts-disable-the-localversion-tag-of-a-git-repo.patch;
fi

# CacULE scheduler disabled by default and for real-time kernels
# To enable, pass KERNEL_SCHEDULER=cacule to the script
if [ ${KERNEL_SCHEDULER} == "cacule" ] && [ "${KERNEL_TYPE}" != "rt" ]; then
    if [ "${KERNEL_BASE_VER}" = "5.14" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/cacule-sched/5.14/cacule-5.14*.patch .;
        patch -p1 < ./cacule-5.14-d03c116.patch;
    elif [ "${KERNEL_BASE_VER}" = "5.13" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/cacule-sched/5.13/cacule-5.13*.patch .;
        patch -p1 < ./cacule-5.13-bb77376.patch;
    elif [ "${KERNEL_BASE_VER}" = "5.10" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/cacule-sched/5.10/cacule-5.10*.patch .;
        patch -p1 < ./cacule-5.10-bb77376.patch;
    elif [ "${KERNEL_BASE_VER}" = "5.4" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/cacule-sched/5.4/cacule-5.4*.patch .;
        patch -p1 < ./cacule-5.4.patch;
        for i in {1..16}; do
            patch -p1 < ./cacule-5.4-merge-fixes-part${i}.patch;
        done
    fi
    echo "*** Copying and applying CacULE kernel scheduler patch.. ✓";
fi

# Examples:
# 5.16.1-051601+customidle-generic
# 5.16.1-051601+customfull-generic
# 5.16.1-051601+customrt-generic
# Note: A hyphen between label and type (e.g. customidle -> custom-idle) causes problems with some parsers
# Because the final version name becomes: 5.16.1-051601+custom-idle-generic, so just keep it combined
echo "*** Updating version in changelog (necessary for Ubuntu)... ✓";
sed -i "s/${KERNEL_SUB_VER}/${KERNEL_SUB_VER}+${KERNEL_VERSION_LABEL}${KERNEL_TYPE}/g" ./debian.master/changelog;

ZFS_SUPPORT=${ZFS_SUPPORT:-"no"}
if [ ${ZFS_SUPPORT} == "no" ]; then
    echo "*** Disabling zfs by default (can cause issues during compilation)... ✓";
    sed -i 's/do_zfs/#do_zfs/g' ./debian.master/rules.d/amd64.mk;
fi

DKMS_VBOX=${DKMS_VBOX:-"no"}
if [ ${DKMS_VBOX} == "no" ]; then
    echo "*** Disabling dkms for vbox... ✓";
    sed -i 's/do_dkms_vbox    = true/do_dkms_vbox    = false/g' ./debian.master/rules.d/amd64.mk;
fi

DKMS_NVIDIA=${DKMS_NVIDIA:-"no"}
if [ ${DKMS_NVIDIA} == "no" ]; then
    echo "*** Disabling dkms for nvidia... ✓";
    sed -i 's/do_dkms_nvidia  = true/do_dkms_nvidia  = false/g' ./debian.master/rules.d/amd64.mk;
fi

DKMS_WIREGUARD=${DKMS_WIREGUARD:-"no"}
if [ ${DKMS_WIREGUARD} == "no" ]; then
    echo "*** Disabling dkms for wireguard... ✓";
    sed -i 's/do_dkms_wireguard = true/do_dkms_wireguard = false/g' ./debian.master/rules.d/amd64.mk;
fi

BUILD_ARCHS=${BUILD_ARCHS:-"amd64"}
echo "*** Removing unnecessary arch's and building for ${BUILD_ARCHS}... ✓";
sed -i "s/archs=\"amd64 i386 armhf arm64 ppc64el s390x\"/archs=\"${BUILD_ARCHS}\"/g" ./debian.master/etc/kernelconfig;

echo "*** Making scripts executable... ✓";
chmod a+x debian/rules;
chmod a+x debian/scripts/*;
chmod a+x debian/scripts/misc/*;

echo "*** Create symlink for kernel ABI... ✓";
[ ${KERNEL_BASE_VER} == "5.4" ] && ABI_VERSION=5.4.0-25.29 || ABI_VERSION=5.7.0-5.6;
ln -rsv ./debian.master/abi/${ABI_VERSION} ./debian.master/abi/${KERNEL_PATCH_VER}-0.0;

echo "*** Running fakeroot debian/rules clean... ✓";
fakeroot debian/rules clean;

echo "*** Copying over our custom configs... ✓";
cp -fv ${CONFIG_PATH}/ubuntu-${KERNEL_BASE_VER}/ubuntu-${KERNEL_BASE_VER}-${KERNEL_TYPE}/config.common.amd64 ./debian.master/config/amd64;
cp -fv ${CONFIG_PATH}/ubuntu-${KERNEL_BASE_VER}/ubuntu-${KERNEL_BASE_VER}-${KERNEL_TYPE}/config.flavour.generic ./debian.master/config/amd64;
cp -fv ${CONFIG_PATH}/ubuntu-${KERNEL_BASE_VER}/ubuntu-${KERNEL_BASE_VER}-${KERNEL_TYPE}/config.flavour.lowlatency ./debian.master/config/amd64;
cp -fv ${CONFIG_PATH}/ubuntu-${KERNEL_BASE_VER}/ubuntu-${KERNEL_BASE_VER}-${KERNEL_TYPE}/config.common.ubuntu ./debian.master/config;

AMDGPU_BUILTIN=${AMDGPU_BUILTIN:-"no"}
if [ ${AMDGPU_BUILTIN} == "yes" ]; then
    # Supports all AMD gpu chips (can be found in /lib/firmware/amdgpu)
    #
    # Bonaire, Carrizo, Dimgrey Cavefish, Fiji, Green Sardine, Hainan, Hawaii, Kabini, Kaveri,
    # Mullins, Navi, Oland, Picasso, Polaris, Raven, Renoir, Sienna Chichlid, Stoney, Tahiti,
    # Tonga, Topaz, Vega, Verde
    echo "*** Updating config to build-in amdgpu into the kernel... ✓";
    sed -i 's/CONFIG_EXTRA_FIRMWARE=""/CONFIG_EXTRA_FIRMWARE="amdgpu\/bonaire_ce.bin amdgpu\/bonaire_k_smc.bin amdgpu\/bonaire_mc.bin amdgpu\/bonaire_me.bin amdgpu\/bonaire_mec.bin amdgpu\/bonaire_pfp.bin amdgpu\/bonaire_rlc.bin amdgpu\/bonaire_sdma1.bin amdgpu\/bonaire_sdma.bin amdgpu\/bonaire_smc.bin amdgpu\/bonaire_uvd.bin amdgpu\/bonaire_vce.bin amdgpu\/banks_k_2_smc.bin amdgpu\/carrizo_ce.bin amdgpu\/carrizo_me.bin amdgpu\/carrizo_mec2.bin amdgpu\/carrizo_mec.bin amdgpu\/carrizo_pfp.bin amdgpu\/carrizo_rlc.bin amdgpu\/carrizo_sdma1.bin amdgpu\/carrizo_sdma.bin amdgpu\/carrizo_uvd.bin amdgpu\/carrizo_vce.bin amdgpu\/dimgrey_cavefish_ce.bin amdgpu\/dimgrey_cavefish_dmcub.bin amdgpu\/dimgrey_cavefish_me.bin amdgpu\/dimgrey_cavefish_mec2.bin amdgpu\/dimgrey_cavefish_mec.bin amdgpu\/dimgrey_cavefish_pfp.bin amdgpu\/dimgrey_cavefish_rlc.bin amdgpu\/dimgrey_cavefish_sdma.bin amdgpu\/dimgrey_cavefish_smc.bin amdgpu\/dimgrey_cavefish_sos.bin amdgpu\/dimgrey_cavefish_ta.bin amdgpu\/dimgrey_cavefish_vcn.bin amdgpu\/fiji_ce.bin amdgpu\/fiji_mc.bin amdgpu\/fiji_me.bin amdgpu\/fiji_mec2.bin amdgpu\/fiji_mec.bin amdgpu\/fiji_pfp.bin amdgpu\/fiji_rlc.bin amdgpu\/fiji_sdma1.bin amdgpu\/fiji_sdma.bin amdgpu\/fiji_smc.bin amdgpu\/fiji_uvd.bin amdgpu\/fiji_vce.bin amdgpu\/green_sardine_asd.bin amdgpu\/green_sardine_ce.bin amdgpu\/green_sardine_dmcub.bin amdgpu\/green_sardine_me.bin amdgpu\/green_sardine_mec2.bin amdgpu\/green_sardine_mec.bin amdgpu\/green_sardine_pfp.bin amdgpu\/green_sardine_rlc.bin amdgpu\/green_sardine_sdma.bin amdgpu\/green_sardine_ta.bin amdgpu\/green_sardine_vcn.bin amdgpu\/hainan_ce.bin amdgpu\/hainan_k_smc.bin amdgpu\/hainan_mc.bin amdgpu\/hainan_me.bin amdgpu\/hainan_pfp.bin amdgpu\/hainan_rlc.bin amdgpu\/hainan_smc.bin amdgpu\/hawaii_ce.bin amdgpu\/hawaii_k_smc.bin amdgpu\/hawaii_mc.bin amdgpu\/hawaii_me.bin amdgpu\/hawaii_mec.bin amdgpu\/hawaii_pfp.bin amdgpu\/hawaii_rlc.bin amdgpu\/hawaii_sdma1.bin amdgpu\/hawaii_sdma.bin amdgpu\/hawaii_smc.bin amdgpu\/hawaii_uvd.bin amdgpu\/hawaii_vce.bin amdgpu\/kabini_ce.bin amdgpu\/kabini_me.bin amdgpu\/kabini_mec.bin amdgpu\/kabini_pfp.bin amdgpu\/kabini_rlc.bin amdgpu\/kabini_sdma1.bin amdgpu\/kabini_sdma.bin amdgpu\/kabini_uvd.bin amdgpu\/kabini_vce.bin amdgpu\/kaveri_ce.bin amdgpu\/kaveri_me.bin amdgpu\/kaveri_mec2.bin amdgpu\/kaveri_mec.bin amdgpu\/kaveri_pfp.bin amdgpu\/kaveri_rlc.bin amdgpu\/kaveri_sdma1.bin amdgpu\/kaveri_sdma.bin amdgpu\/kaveri_uvd.bin amdgpu\/kaveri_vce.bin amdgpu\/mullins_ce.bin amdgpu\/mullins_me.bin amdgpu\/mullins_mec.bin amdgpu\/mullins_pfp.bin amdgpu\/mullins_rlc.bin amdgpu\/mullins_sdma1.bin amdgpu\/mullins_sdma.bin amdgpu\/mullins_uvd.bin amdgpu\/mullins_vce.bin amdgpu\/navi10_asd.bin amdgpu\/navi10_ce.bin amdgpu\/navi10_gpu_info.bin amdgpu\/navi10_me.bin amdgpu\/navi10_mec2.bin amdgpu\/navi10_mec.bin amdgpu\/navi10_pfp.bin amdgpu\/navi10_rlc.bin amdgpu\/navi10_sdma1.bin amdgpu\/navi10_sdma.bin amdgpu\/navi10_smc.bin amdgpu\/navi10_sos.bin amdgpu\/navi10_ta.bin amdgpu\/navi10_vcn.bin amdgpu\/navi14_asd.bin amdgpu\/navi14_ce.bin amdgpu\/navi14_ce_wks.bin amdgpu\/navi14_gpu_info.bin amdgpu\/navi14_me.bin amdgpu\/navi14_mec2.bin amdgpu\/navi14_mec2_wks.bin amdgpu\/navi14_mec.bin amdgpu\/navi14_mec_wks.bin amdgpu\/navi14_me_wks.bin amdgpu\/navi14_pfp.bin amdgpu\/navi14_pfp_wks.bin amdgpu\/navi14_rlc.bin amdgpu\/navi14_sdma1.bin amdgpu\/navi14_sdma.bin amdgpu\/navi14_smc.bin amdgpu\/navi14_sos.bin amdgpu\/navi14_ta.bin amdgpu\/navi14_vcn.bin amdgpu\/oland_ce.bin amdgpu\/oland_k_smc.bin amdgpu\/oland_mc.bin amdgpu\/oland_me.bin amdgpu\/oland_pfp.bin amdgpu\/oland_rlc.bin amdgpu\/oland_smc.bin amdgpu\/picasso_asd.bin amdgpu\/picasso_ce.bin amdgpu\/picasso_gpu_info.bin amdgpu\/picasso_me.bin amdgpu\/picasso_mec2.bin amdgpu\/picasso_mec.bin amdgpu\/picasso_pfp.bin amdgpu\/picasso_rlc_am4.bin amdgpu\/picasso_rlc.bin amdgpu\/picasso_sdma.bin amdgpu\/picasso_ta.bin amdgpu\/picasso_vcn.bin amdgpu\/pitcairn_ce.bin amdgpu\/pitcairn_k_smc.bin amdgpu\/pitcairn_mc.bin amdgpu\/pitcairn_me.bin amdgpu\/pitcairn_pfp.bin amdgpu\/pitcairn_rlc.bin amdgpu\/pitcairn_smc.bin amdgpu\/polaris10_ce_2.bin amdgpu\/polaris10_ce.bin amdgpu\/polaris10_k2_smc.bin amdgpu\/polaris10_k_mc.bin amdgpu\/polaris10_k_smc.bin amdgpu\/polaris10_mc.bin amdgpu\/polaris10_me_2.bin amdgpu\/polaris10_me.bin amdgpu\/polaris10_mec2_2.bin amdgpu\/polaris10_mec_2.bin amdgpu\/polaris10_mec2.bin amdgpu\/polaris10_mec.bin amdgpu\/polaris10_pfp_2.bin amdgpu\/polaris10_pfp.bin amdgpu\/polaris10_rlc.bin amdgpu\/polaris10_sdma1.bin amdgpu\/polaris10_sdma.bin amdgpu\/polaris10_smc.bin amdgpu\/polaris10_smc_sk.bin amdgpu\/polaris10_uvd.bin amdgpu\/polaris10_vce.bin amdgpu\/polaris11_ce_2.bin amdgpu\/polaris11_ce.bin amdgpu\/polaris11_k2_smc.bin amdgpu\/polaris11_k_mc.bin amdgpu\/polaris11_k_smc.bin amdgpu\/polaris11_mc.bin amdgpu\/polaris11_me_2.bin amdgpu\/polaris11_me.bin amdgpu\/polaris11_mec2_2.bin amdgpu\/polaris11_mec_2.bin amdgpu\/polaris11_mec2.bin amdgpu\/polaris11_mec.bin amdgpu\/polaris11_pfp_2.bin amdgpu\/polaris11_pfp.bin amdgpu\/polaris11_rlc.bin amdgpu\/polaris11_sdma1.bin amdgpu\/polaris11_sdma.bin amdgpu\/polaris11_smc.bin amdgpu\/polaris11_smc_sk.bin amdgpu\/polaris11_uvd.bin amdgpu\/polaris11_vce.bin amdgpu\/polaris12_32_mc.bin amdgpu\/polaris12_ce_2.bin amdgpu\/polaris12_ce.bin amdgpu\/polaris12_k_mc.bin amdgpu\/polaris12_k_smc.bin amdgpu\/polaris12_mc.bin amdgpu\/polaris12_me_2.bin amdgpu\/polaris12_me.bin amdgpu\/polaris12_mec2_2.bin amdgpu\/polaris12_mec_2.bin amdgpu\/polaris12_mec2.bin amdgpu\/polaris12_mec.bin amdgpu\/polaris12_pfp_2.bin amdgpu\/polaris12_pfp.bin amdgpu\/polaris12_rlc.bin amdgpu\/polaris12_sdma1.bin amdgpu\/polaris12_sdma.bin amdgpu\/polaris12_smc.bin amdgpu\/polaris12_uvd.bin amdgpu\/polaris12_vce.bin amdgpu\/raven2_asd.bin amdgpu\/raven2_ce.bin amdgpu\/raven2_gpu_info.bin amdgpu\/raven2_me.bin amdgpu\/raven2_mec2.bin amdgpu\/raven2_mec.bin amdgpu\/raven2_pfp.bin amdgpu\/raven2_rlc.bin amdgpu\/raven2_sdma.bin amdgpu\/raven2_ta.bin amdgpu\/raven2_vcn.bin amdgpu\/raven_asd.bin amdgpu\/raven_ce.bin amdgpu\/raven_dmcu.bin amdgpu\/raven_gpu_info.bin amdgpu\/raven_kicker_rlc.bin amdgpu\/raven_me.bin amdgpu\/raven_mec2.bin amdgpu\/raven_mec.bin amdgpu\/raven_pfp.bin amdgpu\/raven_rlc.bin amdgpu\/raven_sdma.bin amdgpu\/raven_ta.bin amdgpu\/raven_vcn.bin amdgpu\/renoir_asd.bin amdgpu\/renoir_ce.bin amdgpu\/renoir_dmcub.bin amdgpu\/renoir_gpu_info.bin amdgpu\/renoir_me.bin amdgpu\/renoir_mec2.bin amdgpu\/renoir_mec.bin amdgpu\/renoir_pfp.bin amdgpu\/renoir_rlc.bin amdgpu\/renoir_sdma.bin amdgpu\/renoir_vcn.bin amdgpu\/si58_mc.bin amdgpu\/sienna_cichlid_ce.bin amdgpu\/sienna_cichlid_dmcub.bin amdgpu\/sienna_cichlid_me.bin amdgpu\/sienna_cichlid_mec2.bin amdgpu\/sienna_cichlid_mec.bin amdgpu\/sienna_cichlid_pfp.bin amdgpu\/sienna_cichlid_rlc.bin amdgpu\/sienna_cichlid_sdma.bin amdgpu\/sienna_cichlid_smc.bin amdgpu\/sienna_cichlid_sos.bin amdgpu\/sienna_cichlid_ta.bin amdgpu\/sienna_cichlid_vcn.bin amdgpu\/stoney_ce.bin amdgpu\/stoney_me.bin amdgpu\/stoney_mec.bin amdgpu\/stoney_pfp.bin amdgpu\/stoney_rlc.bin amdgpu\/stoney_sdma.bin amdgpu\/stoney_uvd.bin amdgpu\/stoney_vce.bin amdgpu\/tahiti_ce.bin amdgpu\/tahiti_k_smc.bin amdgpu\/tahiti_mc.bin amdgpu\/tahiti_me.bin amdgpu\/tahiti_pfp.bin amdgpu\/tahiti_rlc.bin amdgpu\/tahiti_smc.bin amdgpu\/tonga_ce.bin amdgpu\/tonga_k_smc.bin amdgpu\/tonga_mc.bin amdgpu\/tonga_me.bin amdgpu\/tonga_mec2.bin amdgpu\/tonga_mec.bin amdgpu\/tonga_pfp.bin amdgpu\/tonga_rlc.bin amdgpu\/tonga_sdma1.bin amdgpu\/tonga_sdma.bin amdgpu\/tonga_smc.bin amdgpu\/tonga_uvd.bin amdgpu\/tonga_vce.bin amdgpu\/topaz_ce.bin amdgpu\/topaz_k_smc.bin amdgpu\/topaz_mc.bin amdgpu\/topaz_me.bin amdgpu\/topaz_mec2.bin amdgpu\/topaz_mec.bin amdgpu\/topaz_pfp.bin amdgpu\/topaz_rlc.bin amdgpu\/topaz_sdma1.bin amdgpu\/topaz_sdma.bin amdgpu\/topaz_smc.bin amdgpu\/vega10_acg_smc.bin amdgpu\/vega10_asd.bin amdgpu\/vega10_ce.bin amdgpu\/vega10_gpu_info.bin amdgpu\/vega10_me.bin amdgpu\/vega10_mec2.bin amdgpu\/vega10_mec.bin amdgpu\/vega10_pfp.bin amdgpu\/vega10_rlc.bin amdgpu\/vega10_sdma1.bin amdgpu\/vega10_sdma.bin amdgpu\/vega10_smc.bin amdgpu\/vega10_sos.bin amdgpu\/vega10_uvd.bin amdgpu\/vega10_vce.bin amdgpu\/vega12_asd.bin amdgpu\/vega12_ce.bin amdgpu\/vega12_gpu_info.bin amdgpu\/vega12_me.bin amdgpu\/vega12_mec2.bin amdgpu\/vega12_mec.bin amdgpu\/vega12_pfp.bin amdgpu\/vega12_rlc.bin amdgpu\/vega12_sdma1.bin amdgpu\/vega12_sdma.bin amdgpu\/vega12_smc.bin amdgpu\/vega12_sos.bin amdgpu\/vega12_uvd.bin amdgpu\/vega12_vce.bin amdgpu\/vega20_asd.bin amdgpu\/vega20_ce.bin amdgpu\/vega20_me.bin amdgpu\/vega20_mec2.bin amdgpu\/vega20_mec.bin amdgpu\/vega20_pfp.bin amdgpu\/vega20_rlc.bin amdgpu\/vega20_sdma1.bin amdgpu\/vega20_sdma.bin amdgpu\/vega20_smc.bin amdgpu\/vega20_sos.bin amdgpu\/vega20_ta.bin amdgpu\/vega20_uvd.bin amdgpu\/vega20_vce.bin amdgpu\/vegam_ce.bin amdgpu\/vegam_me.bin amdgpu\/vegam_mec2.bin amdgpu\/vegam_mec.bin amdgpu\/vegam_pfp.bin amdgpu\/vegam_rlc.bin amdgpu\/vegam_sdma1.bin amdgpu\/vegam_sdma.bin amdgpu\/vegam_smc.bin amdgpu\/vegam_uvd.bin amdgpu\/vegam_vce.bin amdgpu\/verde_ce.bin amdgpu\/verde_k_smc.bin amdgpu\/verde_mc.bin amdgpu\/verde_me.bin amdgpu\/verde_pfp.bin amdgpu\/verde_rlc.bin amdgpu\/verde_smc.bin"/g' ./debian.master/config/config.common.ubuntu;
else
    # If AMDGPU_BUILTIN=no (or if it's not passed into the build script, the default) remove it from the config if it
    # was previously set. If it was never set to begin with, sed will quietly error since it didn't find a string match
    echo "*** Updating config to build amdgpu as a module... ✓";
    sed -i 's/CONFIG_EXTRA_FIRMWARE="amdgpu\/bonaire_ce.bin amdgpu\/bonaire_k_smc.bin amdgpu\/bonaire_mc.bin amdgpu\/bonaire_me.bin amdgpu\/bonaire_mec.bin amdgpu\/bonaire_pfp.bin amdgpu\/bonaire_rlc.bin amdgpu\/bonaire_sdma1.bin amdgpu\/bonaire_sdma.bin amdgpu\/bonaire_smc.bin amdgpu\/bonaire_uvd.bin amdgpu\/bonaire_vce.bin amdgpu\/banks_k_2_smc.bin amdgpu\/carrizo_ce.bin amdgpu\/carrizo_me.bin amdgpu\/carrizo_mec2.bin amdgpu\/carrizo_mec.bin amdgpu\/carrizo_pfp.bin amdgpu\/carrizo_rlc.bin amdgpu\/carrizo_sdma1.bin amdgpu\/carrizo_sdma.bin amdgpu\/carrizo_uvd.bin amdgpu\/carrizo_vce.bin amdgpu\/dimgrey_cavefish_ce.bin amdgpu\/dimgrey_cavefish_dmcub.bin amdgpu\/dimgrey_cavefish_me.bin amdgpu\/dimgrey_cavefish_mec2.bin amdgpu\/dimgrey_cavefish_mec.bin amdgpu\/dimgrey_cavefish_pfp.bin amdgpu\/dimgrey_cavefish_rlc.bin amdgpu\/dimgrey_cavefish_sdma.bin amdgpu\/dimgrey_cavefish_smc.bin amdgpu\/dimgrey_cavefish_sos.bin amdgpu\/dimgrey_cavefish_ta.bin amdgpu\/dimgrey_cavefish_vcn.bin amdgpu\/fiji_ce.bin amdgpu\/fiji_mc.bin amdgpu\/fiji_me.bin amdgpu\/fiji_mec2.bin amdgpu\/fiji_mec.bin amdgpu\/fiji_pfp.bin amdgpu\/fiji_rlc.bin amdgpu\/fiji_sdma1.bin amdgpu\/fiji_sdma.bin amdgpu\/fiji_smc.bin amdgpu\/fiji_uvd.bin amdgpu\/fiji_vce.bin amdgpu\/green_sardine_asd.bin amdgpu\/green_sardine_ce.bin amdgpu\/green_sardine_dmcub.bin amdgpu\/green_sardine_me.bin amdgpu\/green_sardine_mec2.bin amdgpu\/green_sardine_mec.bin amdgpu\/green_sardine_pfp.bin amdgpu\/green_sardine_rlc.bin amdgpu\/green_sardine_sdma.bin amdgpu\/green_sardine_ta.bin amdgpu\/green_sardine_vcn.bin amdgpu\/hainan_ce.bin amdgpu\/hainan_k_smc.bin amdgpu\/hainan_mc.bin amdgpu\/hainan_me.bin amdgpu\/hainan_pfp.bin amdgpu\/hainan_rlc.bin amdgpu\/hainan_smc.bin amdgpu\/hawaii_ce.bin amdgpu\/hawaii_k_smc.bin amdgpu\/hawaii_mc.bin amdgpu\/hawaii_me.bin amdgpu\/hawaii_mec.bin amdgpu\/hawaii_pfp.bin amdgpu\/hawaii_rlc.bin amdgpu\/hawaii_sdma1.bin amdgpu\/hawaii_sdma.bin amdgpu\/hawaii_smc.bin amdgpu\/hawaii_uvd.bin amdgpu\/hawaii_vce.bin amdgpu\/kabini_ce.bin amdgpu\/kabini_me.bin amdgpu\/kabini_mec.bin amdgpu\/kabini_pfp.bin amdgpu\/kabini_rlc.bin amdgpu\/kabini_sdma1.bin amdgpu\/kabini_sdma.bin amdgpu\/kabini_uvd.bin amdgpu\/kabini_vce.bin amdgpu\/kaveri_ce.bin amdgpu\/kaveri_me.bin amdgpu\/kaveri_mec2.bin amdgpu\/kaveri_mec.bin amdgpu\/kaveri_pfp.bin amdgpu\/kaveri_rlc.bin amdgpu\/kaveri_sdma1.bin amdgpu\/kaveri_sdma.bin amdgpu\/kaveri_uvd.bin amdgpu\/kaveri_vce.bin amdgpu\/mullins_ce.bin amdgpu\/mullins_me.bin amdgpu\/mullins_mec.bin amdgpu\/mullins_pfp.bin amdgpu\/mullins_rlc.bin amdgpu\/mullins_sdma1.bin amdgpu\/mullins_sdma.bin amdgpu\/mullins_uvd.bin amdgpu\/mullins_vce.bin amdgpu\/navi10_asd.bin amdgpu\/navi10_ce.bin amdgpu\/navi10_gpu_info.bin amdgpu\/navi10_me.bin amdgpu\/navi10_mec2.bin amdgpu\/navi10_mec.bin amdgpu\/navi10_pfp.bin amdgpu\/navi10_rlc.bin amdgpu\/navi10_sdma1.bin amdgpu\/navi10_sdma.bin amdgpu\/navi10_smc.bin amdgpu\/navi10_sos.bin amdgpu\/navi10_ta.bin amdgpu\/navi10_vcn.bin amdgpu\/navi14_asd.bin amdgpu\/navi14_ce.bin amdgpu\/navi14_ce_wks.bin amdgpu\/navi14_gpu_info.bin amdgpu\/navi14_me.bin amdgpu\/navi14_mec2.bin amdgpu\/navi14_mec2_wks.bin amdgpu\/navi14_mec.bin amdgpu\/navi14_mec_wks.bin amdgpu\/navi14_me_wks.bin amdgpu\/navi14_pfp.bin amdgpu\/navi14_pfp_wks.bin amdgpu\/navi14_rlc.bin amdgpu\/navi14_sdma1.bin amdgpu\/navi14_sdma.bin amdgpu\/navi14_smc.bin amdgpu\/navi14_sos.bin amdgpu\/navi14_ta.bin amdgpu\/navi14_vcn.bin amdgpu\/oland_ce.bin amdgpu\/oland_k_smc.bin amdgpu\/oland_mc.bin amdgpu\/oland_me.bin amdgpu\/oland_pfp.bin amdgpu\/oland_rlc.bin amdgpu\/oland_smc.bin amdgpu\/picasso_asd.bin amdgpu\/picasso_ce.bin amdgpu\/picasso_gpu_info.bin amdgpu\/picasso_me.bin amdgpu\/picasso_mec2.bin amdgpu\/picasso_mec.bin amdgpu\/picasso_pfp.bin amdgpu\/picasso_rlc_am4.bin amdgpu\/picasso_rlc.bin amdgpu\/picasso_sdma.bin amdgpu\/picasso_ta.bin amdgpu\/picasso_vcn.bin amdgpu\/pitcairn_ce.bin amdgpu\/pitcairn_k_smc.bin amdgpu\/pitcairn_mc.bin amdgpu\/pitcairn_me.bin amdgpu\/pitcairn_pfp.bin amdgpu\/pitcairn_rlc.bin amdgpu\/pitcairn_smc.bin amdgpu\/polaris10_ce_2.bin amdgpu\/polaris10_ce.bin amdgpu\/polaris10_k2_smc.bin amdgpu\/polaris10_k_mc.bin amdgpu\/polaris10_k_smc.bin amdgpu\/polaris10_mc.bin amdgpu\/polaris10_me_2.bin amdgpu\/polaris10_me.bin amdgpu\/polaris10_mec2_2.bin amdgpu\/polaris10_mec_2.bin amdgpu\/polaris10_mec2.bin amdgpu\/polaris10_mec.bin amdgpu\/polaris10_pfp_2.bin amdgpu\/polaris10_pfp.bin amdgpu\/polaris10_rlc.bin amdgpu\/polaris10_sdma1.bin amdgpu\/polaris10_sdma.bin amdgpu\/polaris10_smc.bin amdgpu\/polaris10_smc_sk.bin amdgpu\/polaris10_uvd.bin amdgpu\/polaris10_vce.bin amdgpu\/polaris11_ce_2.bin amdgpu\/polaris11_ce.bin amdgpu\/polaris11_k2_smc.bin amdgpu\/polaris11_k_mc.bin amdgpu\/polaris11_k_smc.bin amdgpu\/polaris11_mc.bin amdgpu\/polaris11_me_2.bin amdgpu\/polaris11_me.bin amdgpu\/polaris11_mec2_2.bin amdgpu\/polaris11_mec_2.bin amdgpu\/polaris11_mec2.bin amdgpu\/polaris11_mec.bin amdgpu\/polaris11_pfp_2.bin amdgpu\/polaris11_pfp.bin amdgpu\/polaris11_rlc.bin amdgpu\/polaris11_sdma1.bin amdgpu\/polaris11_sdma.bin amdgpu\/polaris11_smc.bin amdgpu\/polaris11_smc_sk.bin amdgpu\/polaris11_uvd.bin amdgpu\/polaris11_vce.bin amdgpu\/polaris12_32_mc.bin amdgpu\/polaris12_ce_2.bin amdgpu\/polaris12_ce.bin amdgpu\/polaris12_k_mc.bin amdgpu\/polaris12_k_smc.bin amdgpu\/polaris12_mc.bin amdgpu\/polaris12_me_2.bin amdgpu\/polaris12_me.bin amdgpu\/polaris12_mec2_2.bin amdgpu\/polaris12_mec_2.bin amdgpu\/polaris12_mec2.bin amdgpu\/polaris12_mec.bin amdgpu\/polaris12_pfp_2.bin amdgpu\/polaris12_pfp.bin amdgpu\/polaris12_rlc.bin amdgpu\/polaris12_sdma1.bin amdgpu\/polaris12_sdma.bin amdgpu\/polaris12_smc.bin amdgpu\/polaris12_uvd.bin amdgpu\/polaris12_vce.bin amdgpu\/raven2_asd.bin amdgpu\/raven2_ce.bin amdgpu\/raven2_gpu_info.bin amdgpu\/raven2_me.bin amdgpu\/raven2_mec2.bin amdgpu\/raven2_mec.bin amdgpu\/raven2_pfp.bin amdgpu\/raven2_rlc.bin amdgpu\/raven2_sdma.bin amdgpu\/raven2_ta.bin amdgpu\/raven2_vcn.bin amdgpu\/raven_asd.bin amdgpu\/raven_ce.bin amdgpu\/raven_dmcu.bin amdgpu\/raven_gpu_info.bin amdgpu\/raven_kicker_rlc.bin amdgpu\/raven_me.bin amdgpu\/raven_mec2.bin amdgpu\/raven_mec.bin amdgpu\/raven_pfp.bin amdgpu\/raven_rlc.bin amdgpu\/raven_sdma.bin amdgpu\/raven_ta.bin amdgpu\/raven_vcn.bin amdgpu\/renoir_asd.bin amdgpu\/renoir_ce.bin amdgpu\/renoir_dmcub.bin amdgpu\/renoir_gpu_info.bin amdgpu\/renoir_me.bin amdgpu\/renoir_mec2.bin amdgpu\/renoir_mec.bin amdgpu\/renoir_pfp.bin amdgpu\/renoir_rlc.bin amdgpu\/renoir_sdma.bin amdgpu\/renoir_vcn.bin amdgpu\/si58_mc.bin amdgpu\/sienna_cichlid_ce.bin amdgpu\/sienna_cichlid_dmcub.bin amdgpu\/sienna_cichlid_me.bin amdgpu\/sienna_cichlid_mec2.bin amdgpu\/sienna_cichlid_mec.bin amdgpu\/sienna_cichlid_pfp.bin amdgpu\/sienna_cichlid_rlc.bin amdgpu\/sienna_cichlid_sdma.bin amdgpu\/sienna_cichlid_smc.bin amdgpu\/sienna_cichlid_sos.bin amdgpu\/sienna_cichlid_ta.bin amdgpu\/sienna_cichlid_vcn.bin amdgpu\/stoney_ce.bin amdgpu\/stoney_me.bin amdgpu\/stoney_mec.bin amdgpu\/stoney_pfp.bin amdgpu\/stoney_rlc.bin amdgpu\/stoney_sdma.bin amdgpu\/stoney_uvd.bin amdgpu\/stoney_vce.bin amdgpu\/tahiti_ce.bin amdgpu\/tahiti_k_smc.bin amdgpu\/tahiti_mc.bin amdgpu\/tahiti_me.bin amdgpu\/tahiti_pfp.bin amdgpu\/tahiti_rlc.bin amdgpu\/tahiti_smc.bin amdgpu\/tonga_ce.bin amdgpu\/tonga_k_smc.bin amdgpu\/tonga_mc.bin amdgpu\/tonga_me.bin amdgpu\/tonga_mec2.bin amdgpu\/tonga_mec.bin amdgpu\/tonga_pfp.bin amdgpu\/tonga_rlc.bin amdgpu\/tonga_sdma1.bin amdgpu\/tonga_sdma.bin amdgpu\/tonga_smc.bin amdgpu\/tonga_uvd.bin amdgpu\/tonga_vce.bin amdgpu\/topaz_ce.bin amdgpu\/topaz_k_smc.bin amdgpu\/topaz_mc.bin amdgpu\/topaz_me.bin amdgpu\/topaz_mec2.bin amdgpu\/topaz_mec.bin amdgpu\/topaz_pfp.bin amdgpu\/topaz_rlc.bin amdgpu\/topaz_sdma1.bin amdgpu\/topaz_sdma.bin amdgpu\/topaz_smc.bin amdgpu\/vega10_acg_smc.bin amdgpu\/vega10_asd.bin amdgpu\/vega10_ce.bin amdgpu\/vega10_gpu_info.bin amdgpu\/vega10_me.bin amdgpu\/vega10_mec2.bin amdgpu\/vega10_mec.bin amdgpu\/vega10_pfp.bin amdgpu\/vega10_rlc.bin amdgpu\/vega10_sdma1.bin amdgpu\/vega10_sdma.bin amdgpu\/vega10_smc.bin amdgpu\/vega10_sos.bin amdgpu\/vega10_uvd.bin amdgpu\/vega10_vce.bin amdgpu\/vega12_asd.bin amdgpu\/vega12_ce.bin amdgpu\/vega12_gpu_info.bin amdgpu\/vega12_me.bin amdgpu\/vega12_mec2.bin amdgpu\/vega12_mec.bin amdgpu\/vega12_pfp.bin amdgpu\/vega12_rlc.bin amdgpu\/vega12_sdma1.bin amdgpu\/vega12_sdma.bin amdgpu\/vega12_smc.bin amdgpu\/vega12_sos.bin amdgpu\/vega12_uvd.bin amdgpu\/vega12_vce.bin amdgpu\/vega20_asd.bin amdgpu\/vega20_ce.bin amdgpu\/vega20_me.bin amdgpu\/vega20_mec2.bin amdgpu\/vega20_mec.bin amdgpu\/vega20_pfp.bin amdgpu\/vega20_rlc.bin amdgpu\/vega20_sdma1.bin amdgpu\/vega20_sdma.bin amdgpu\/vega20_smc.bin amdgpu\/vega20_sos.bin amdgpu\/vega20_ta.bin amdgpu\/vega20_uvd.bin amdgpu\/vega20_vce.bin amdgpu\/vegam_ce.bin amdgpu\/vegam_me.bin amdgpu\/vegam_mec2.bin amdgpu\/vegam_mec.bin amdgpu\/vegam_pfp.bin amdgpu\/vegam_rlc.bin amdgpu\/vegam_sdma1.bin amdgpu\/vegam_sdma.bin amdgpu\/vegam_smc.bin amdgpu\/vegam_uvd.bin amdgpu\/vegam_vce.bin amdgpu\/verde_ce.bin amdgpu\/verde_k_smc.bin amdgpu\/verde_mc.bin amdgpu\/verde_me.bin amdgpu\/verde_pfp.bin amdgpu\/verde_rlc.bin amdgpu\/verde_smc.bin/CONFIG_EXTRA_FIRMWARE=""/g' ./debian.master/config/config.common.ubuntu;
fi

echo -n "[${KERNEL_PATCH_VER} ${KERNEL_SCHEDULER} ${KERNEL_TYPE}] Do you need to run editconfigs? [Y/n]: ";
read yno;
case $yno in
    [nN] | [n|N][O|o] )
        echo "*** Okay, moving on.";
        ;;
    [yY] | [yY][Ee][Ss] )
        ;&
    *)
        fakeroot debian/rules editconfigs;
        ;;
esac

echo -n "[${KERNEL_PATCH_VER} ${KERNEL_SCHEDULER} ${KERNEL_TYPE}] Copy over the new config changes? [y/N]: ";
read yno;
case $yno in
    [yY] | [yY][Ee][Ss] )
        echo "*** Copying configs... ✓";
        cp -fv ./debian.master/config/amd64/config.* ${CONFIG_PATH}/ubuntu-${KERNEL_BASE_VER}/ubuntu-${KERNEL_BASE_VER}-${KERNEL_TYPE};
        cp -fv ./debian.master/config/config.common.ubuntu ${CONFIG_PATH}/ubuntu-${KERNEL_BASE_VER}/ubuntu-${KERNEL_BASE_VER}-${KERNEL_TYPE};
        ;;
    [nN] | [n|N][O|o] )
        ;&
    *)
        echo "*** Okay, moving on.";
        ;;
esac

echo -n "[${KERNEL_PATCH_VER} ${KERNEL_SCHEDULER} ${KERNEL_TYPE}] Do you want to start building? [Y/n]: ";
read yno;
case $yno in
    [nN] | [n|N][O|o] )
        echo "*** All good. Exiting.";
        exit 0;
        ;;
    [yY] | [yY][Ee][Ss] )
        ;&
    *)
        echo "*** Starting build... ✓";
        fakeroot debian/rules binary-headers binary-generic binary-perarch;
        ;;
esac

echo "*** Finished compiling the kernel, installing... ✓";
COMPILED_KERNEL_VER=${KERNEL_PATCH_VER}-${KERNEL_SUB_VER}+${KERNEL_VERSION_LABEL}${KERNEL_TYPE}
TIME_BUILT=$(date +%s)
sudo dpkg -i ../*.deb;
mkdir -pv ${COMPILED_KERNELS_DIR};
mkdir -pv ../${COMPILED_KERNEL_VER}-${TIME_BUILT};
mv -v ../*.deb ../${COMPILED_KERNEL_VER}-${TIME_BUILT};
mv -v ../${COMPILED_KERNEL_VER}-${TIME_BUILT} ${COMPILED_KERNELS_DIR};

# The latest VirtualBox (6.1.25-r145887) requires this missing module.lds to work
# To use: Pass VBOX_SUPPORT=yes to the build script
#
# Also note: If you're running VirtualBox while the kernel is compiling
# and it tries to run this command, it will fail. Just a heads up. You can
# always run it afterwards manually to get VirtualBox support going.
#
# Another note: -rt kernels can't use VirtualBox, so keep that in mind when
# deciding on a kernel to use as your daily driver.
VBOX_SUPPORT=${VBOX_SUPPORT:-"no"}
if [ ${VBOX_SUPPORT} == "yes" ] && [ "${KERNEL_TYPE}" != "rt" ]; then
    echo "*** Enabling VirtualBox support... ✓";
    sudo cp -v ${CUSTOM_PATCH_PATH}/virtualbox-support/module.lds /usr/src/linux-headers-${KERNEL_PATCH_VER}-${KERNEL_SUB_VER}+${KERNEL_VERSION_LABEL}${KERNEL_TYPE}-generic/scripts/module.lds;
    sudo /sbin/vboxconfig;
fi

echo "*** Finished installing kernel, cleaning up build directory... ✓";
rm -rf ${KERNEL_BUILD_DIR};

# Keep an eye out for the following directories, as they build up over time.
# Also note: Running 'sudo update-grub2' will list your installed kernels,
# and you can manually delete the ones that have uninstall as time goes on.
#
# To uninstall a kernel: $ sudo apt purge *5.16.1-051601+customidle-generic*
# However, you still need to manually remove the old ones that build up below.
echo "ls -alh /usr/src"
ls -alh /usr/src;
echo "ls -alh /lib/modules"
ls -alh /lib/modules;
echo "ls -alh ${COMPILED_KERNELS_DIR}"
ls -alh ${COMPILED_KERNELS_DIR};
echo "ls -alh ${COMPILED_KERNELS_DIR}/${COMPILED_KERNEL_VER}-${TIME_BUILT}"
ls -alh ${COMPILED_KERNELS_DIR}/${COMPILED_KERNEL_VER}-${TIME_BUILT};

cd;
echo "*** All done. ✓";
echo "*** You can now reboot and select ${COMPILED_KERNEL_VER}-generic in GRUB.";
