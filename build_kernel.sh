#!/bin/bash

# Compile the Linux kernel for Ubuntu.

set -euo pipefail

KERNEL_BASE_VER=${KERNEL_BASE_VER:-"5.4"}
KERNEL_PATCH_VER=${KERNEL_PATCH_VER:-"5.4.135"}
KERNEL_SUB_VER=${KERNEL_SUB_VER:-"0504135"}
KERNEL_PATCH_SUB_VER=${KERNEL_PATCH_SUB_VER:-"5.4.0-26.30"}
KERNEL_TYPE=${KERNEL_TYPE:-"idle"} # idle, full, rt
KERNEL_SCHEDULER=${KERNEL_SCHEDULER:-"cacule"} # cacule, cfs
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
KERNEL_SRC_URL=${KERNEL_SRC_URL:-${KERNEL_SRC_URI}/linux-${KERNEL_PATCH_VER}.${KERNEL_SRC_EXT}}

if ! [[ -d ${KERNEL_MAIN_DIR} ]]; then
    echo "*** Creating main directory for our kernel workspace... ✓";
    mkdir -pv ${KERNEL_MAIN_DIR};
fi

if ! [[ -d ${KERNEL_SOURCES_DIR} ]]; then
    echo "*** Creating sources directory to store our tarballs... ✓";
    mkdir -pv ${KERNEL_SOURCES_DIR};
fi

if ! [[ -d ${PATCH_PATH} ]]; then
    echo "*** Copying over the custom patches folder... ✓";
    mkdir -pv ${CUSTOM_PATCH_PATH};
    cp -r ./patches/* ${CUSTOM_PATCH_PATH};
fi

if ! [[ -d ${CONFIG_PATH} ]]; then
    echo "*** Copying over the custom config folder... ✓"
    mkdir -pv ${CONFIG_PATH};
    cp -r ./configs/* ${CONFIG_PATH};
fi

if [[ -d ${KERNEL_BUILD_DIR} ]]; then
    echo "*** Found previous build dir, removing... ✓";
    rm -rf ${KERNEL_BUILD_DIR};
fi

if ! [[ -f ${KERNEL_MAIN_DIR}/build_kernel.sh ]]; then
    # Note: You can use this copied over script to make your own customized changes
    # as time goes on, and then pull from the GitHub repo separately in another dir
    # to see what's changed. Another option is to ignore this copied script and just
    # use the cloned one from GitHub, but stashing your changes with "git stash" and then
    # "git pull origin master" to get latest script, and then "git stash apply" to
    # apply your own changes on top of the script
    echo "*** Copying over the build script to allow for custom editing... ✓"
    cp -r ./build_kernel.sh ${KERNEL_MAIN_DIR};
fi

echo "*** Creating new build dir... ✓";
mkdir -pv ${KERNEL_BUILD_DIR};
cd ${KERNEL_BUILD_DIR};

if ! [[ -f ${KERNEL_SOURCES_DIR}/linux-${KERNEL_PATCH_VER}.${KERNEL_SRC_EXT} ]]; then
    echo "No tarball found for linux-${KERNEL_PATCH_VER}, fetching... ✓";
    wget ${KERNEL_SRC_URL};
    cp ./linux-${KERNEL_PATCH_VER}.${KERNEL_SRC_EXT} ${KERNEL_SOURCES_DIR};
fi

echo "Copying over the source tarball and extracting... ✓";
cp -v ${KERNEL_SOURCES_DIR}/linux-${KERNEL_PATCH_VER}.${KERNEL_SRC_EXT} .;
tar xvf linux-${KERNEL_PATCH_VER}.${KERNEL_SRC_EXT};
rm -f linux-${KERNEL_PATCH_VER}.${KERNEL_SRC_EXT};
cd linux-${KERNEL_PATCH_VER};

# Deprecated as of 5.4.45 but can still be applied
# See https://kernel.ubuntu.com/~kernel-ppa/mainline/v5.4.45/
echo "*** Copying and applying Ubuntu patches... ✓";
cp -v ${CUSTOM_PATCH_PATH}/ubuntu-${KERNEL_BASE_VER}/*.patch .;
patch -p1 < ./0001-base-packaging.patch;
patch -p1 < ./0002-UBUNTU-SAUCE-add-vmlinux.strip-to-BOOT_TARGETS1-on-p.patch;
patch -p1 < ./0003-UBUNTU-SAUCE-tools-hv-lsvmbus-add-manual-page.patch;
# Update the version in the changelog to latest version since the patches
# are no longer maintained and because we want to keep our kernel as Ubuntu-like
# as possible (with ABI and all)
echo "*** Updating version number in changelog... ✓"
if [ ${KERNEL_BASE_VER} = "5.4" ]; then
    sed -i "s/5.4.45-050445/${KERNEL_PATCH_VER}-${KERNEL_SUB_VER}/g" ./0004-debian-changelog.patch;
else # for all kernels > 5.4. The 5.7.1 kernel was last to supply patches
    sed -i "s/5.7.1-050701/${KERNEL_PATCH_VER}-${KERNEL_SUB_VER}/g" ./0004-debian-changelog.patch;
fi
patch -p1 < ./0004-debian-changelog.patch;
patch -p1 < ./0005-configs-based-on-Ubuntu-${KERNEL_PATCH_SUB_VER}.patch;
echo "*** Successfully applied Ubuntu patches... ✓"

# Populate the patches dir with xanmod and lucjan patches
if ! [[ -d ${PATCH_PATH}/lucjan-patches ]]; then
    echo "*** Fetching lucjan patches... ✓"
    git clone https://github.com/sirlucjan/kernel-patches.git ${PATCH_PATH}/lucjan-patches;
fi
if ! [[ -d ${PATCH_PATH}/xanmod-patches ]]; then
    echo "*** Fetching xanmod patches... ✓"
    git clone https://github.com/xanmod/linux-patches.git ${PATCH_PATH}/xanmod-patches;
fi

# Allow support for rt (real-time) kernels
# https://mirrors.edge.kernel.org/pub/linux/kernel/projects/rt
if [ ${KERNEL_TYPE} = "rt" ]; then
    echo "*** Copying and applying rt patches... ✓"
    if [ ${KERNEL_BASE_VER} = "5.4" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/rt/${KERNEL_BASE_VER}/patch-5.4.129-rt61.patch .;
        patch -p1 < ./patch-5.4.129-rt61.patch;
    elif [ ${KERNEL_BASE_VER} = "5.13" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/rt/${KERNEL_BASE_VER}/patch-5.13-rt1.patch .;
        patch -p1 < ./patch-5.13-rt1.patch;
    fi
fi

# Build the 5.4 LTS kernel. Supported until 2025
if [ ${KERNEL_BASE_VER} = "5.4" ]; then
    echo "*** Copying and applying freesync patches from 5.10.. ✓"
    cp -v ${CUSTOM_PATCH_PATH}/amdgpu/freesync-refresh/*.patch .;
    patch -p1 < ./01_freesync_refresh.patch;
    patch -p1 < ./02_freesync_refresh.patch;
    patch -p1 < ./03_freesync_refresh.patch;
    patch -p1 < ./04_freesync_refresh.patch;
    patch -p1 < ./05_freesync_refresh.patch;
    patch -p1 < ./06_freesync_refresh.patch;
    echo "*** Copying and applying fsgsbase patches.. ✓"
    #https://lkml.org/lkml/2019/10/4/725 - v9 is for 5.4 and earlier
    cp -v ${CUSTOM_PATCH_PATH}/fsgsbase/v9/v9*.patch .;
    for i in {1..17}; do
        patch -p1 < ./v9-${i}.patch;
    done
    echo "*** Copying and applying block 5.4 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/block-patches-v2-sep/*.patch .;
    patch -p1 < ./0001-block-Kconfig.iosched-set-default-value-of-IOSCHED_B.patch;
    patch -p1 < ./0002-block-Fix-depends-for-BLK_DEV_ZONED.patch;
    patch -p1 < ./0003-block-set-rq_affinity-2-for-full-multithreading-I-O-.patch;
    echo "*** Copying and applying block 5.6 patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/5.6/block-patches-v3-sep/*.patch .;
    patch -p1 < ./0004-blk-mq-remove-the-bio-argument-to-prepare_request.patch;
    patch -p1 < ./0005-block-Flag-elevators-suitable-for-single-queue.patch;
    echo "*** Copying and applying block 5.7 patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/5.7/block-patches-v5-sep/*.patch .;
    patch -p1 < ./0006-block-bfq-iosched-fix-duplicated-word.patch;
    patch -p1 < ./0007-block-bio-delete-duplicated-words.patch;
    patch -p1 < ./0008-block-elevator-delete-duplicated-word-and-fix-typos.patch;
    patch -p1 < ./0009-block-blk-timeout-delete-duplicated-word.patch;
    echo "*** Copying and applying block 5.8 patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/5.8/block-patches-v6-sep/*.patch .;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-block-5.8-0011-block-Convert-to-use-the-preferred-fallthrough-macro*.patch .;
    patch -p1 < ./5.4-block-5.8-0011-block-Convert-to-use-the-preferred-fallthrough-macro-part1.patch;
    patch -p1 < ./5.4-block-5.8-0011-block-Convert-to-use-the-preferred-fallthrough-macro-part2.patch;
    patch -p1 < ./0012-block-bfq-Disable-low_latency-when-blk_iolatency-is-.patch;
    echo "*** Copying and applying block 5.10 patches.. ✓"
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-block-5.10-elevator-mq-aware.patch .;
    patch -p1 <./5.4-block-5.10-elevator-mq-aware.patch;
    echo "*** Copying and applying block 5.12 patches.. ✓"
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-block-5.12-0008-block-Remove-unnecessary-elevator-operation-checks*.patch .;
    patch -p1 < ./5.4-block-5.12-0008-block-Remove-unnecessary-elevator-operation-checks.patch;
    patch -p1 < ./5.4-block-5.12-0008-block-Remove-unnecessary-elevator-operation-checks-part2.patch;
    echo "*** Copying and applying BFQ 5.4 patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/bfq-patches-sep/*.patch .;
    patch -p1 < ./0001-blkcg-Make-bfq-disable-iocost-when-enabled.patch;
    patch -p1 < ./0002-block-bfq-present-a-double-cgroups-interface.patch;
    patch -p1 < ./0003-block-bfq-Skip-tracing-hooks-if-possible.patch;
    echo "*** Copying and applying BFQ 5.7 patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/5.7/bfq-patches-v5-sep/*.patch .;
    patch -p1 < ./0001-bfq-Fix-check-detecting-whether-waker-queue-should-b.patch;
    patch -p1 < ./0002-bfq-Allow-short_ttime-queues-to-have-waker.patch;
    echo "*** Copying and applying BFQ 5.10 patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/5.10/bfq-patches-v5-sep/*.patch .;
    patch -p1 < ./0003-block-bfq-increase-time-window-for-waker-detection.patch;
    patch -p1 < ./0004-block-bfq-do-not-raise-non-default-weights.patch;
    patch -p1 < ./0005-block-bfq-avoid-spurious-switches-to-soft_rt-of-inte.patch;
    patch -p1 < ./0006-block-bfq-do-not-expire-a-queue-when-it-is-the-only-.patch;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-0007-block-bfq-replace-mechanism-for-evaluating-I-O-inten*.patch .;
    patch -p1 < ./5.4-0007-block-bfq-replace-mechanism-for-evaluating-I-O-inten-part2.patch;
    patch -p1 < ./5.4-0007-block-bfq-replace-mechanism-for-evaluating-I-O-inten-part3.patch;
    patch -p1 < ./0008-block-bfq-re-evaluate-convenience-of-I-O-plugging-on.patch;
    patch -p1 < ./0009-block-bfq-fix-switch-back-from-soft-rt-weitgh-raisin.patch;
    patch -p1 < ./0010-block-bfq-save-also-weight-raised-service-on-queue-m.patch;
    patch -p1 < ./0011-block-bfq-save-also-injection-state-on-queue-merging.patch;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-0012-block-bfq-make-waker-queue-detection-more-robust*.patch .;
    patch -p1 < ./5.4-0012-block-bfq-make-waker-queue-detection-more-robust.patch;
    patch -p1 < ./5.4-0012-block-bfq-make-waker-queue-detection-more-robust-part2.patch;
    patch -p1 < ./0013-bfq-bfq_check_waker-should-be-static.patch;
    patch -p1 < ./0014-block-bfq-always-inject-I-O-of-queues-blocked-by-wak.patch;
    patch -p1 < ./0015-block-bfq-put-reqs-of-waker-and-woken-in-dispatch-li.patch;
    patch -p1 < ./0016-block-bfq-make-shared-queues-inherit-wakers.patch;
    patch -p1 < ./0017-block-bfq-fix-weight-raising-resume-with-low_latency.patch;
    patch -p1 < ./0018-block-bfq-keep-shared-queues-out-of-the-waker-mechan.patch;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-0019-block-bfq-merge-bursts-of-newly-created-queues*.patch .;
    patch -p1 < ./5.4-0019-block-bfq-merge-bursts-of-newly-created-queues.patch;
    patch -p1 < ./5.4-0019-block-bfq-merge-bursts-of-newly-created-queues-part2.patch;
    patch -p1 < ./0020-bfq-don-t-duplicate-code-for-different-paths.patch;
    patch -p1 < ./0022-bfq-Use-ttime-local-variable.patch;
    patch -p1 < ./0023-bfq-Use-only-idle-IO-periods-for-think-time-calculat.patch;
    patch -p1 < ./0024-bfq-Remove-stale-comment.patch;
    patch -p1 < ./0025-Revert-bfq-Remove-stale-comment.patch;
    echo "*** Copying and applying BFQ 5.11 patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/5.11/bfq-patches-v7-sep/*.patch .;
    patch -p1 < ./0023-block-bfq-update-comments-and-default-value-in-docs-.patch;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-0027-Revert-block-bfq-make-shared-queues-inherit-wakers*.patch .;
    patch -p1 < ./5.4-0027-Revert-block-bfq-make-shared-queues-inherit-wakers.patch;
    patch -p1 < ./5.4-0027-Revert-block-bfq-make-shared-queues-inherit-wakers-part2.patch;
    patch -p1 < ./0028-Revert-block-bfq-put-reqs-of-waker-and-woken-in-disp.patch;
    patch -p1 < ./0029-Revert-block-bfq-always-inject-I-O-of-queues-blocked.patch;
    patch -p1 < ./0030-block-bfq-always-inject-I-O-of-queues-blocked-by-wak.patch;
    patch -p1 < ./0031-block-bfq-put-reqs-of-waker-and-woken-in-dispatch-li.patch;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-0032-block-bfq-make-shared-queues-inherit-wakers*.patch .;
    patch -p1 < ./5.4-0032-block-bfq-make-shared-queues-inherit-wakers.patch;
    patch -p1 < ./5.4-0032-block-bfq-make-shared-queues-inherit-wakers-part2.patch;
    patch -p1 < ./0037-block-bfq-fix-the-timeout-calculation-in-bfq_bfqq_ch.patch;
    patch -p1 < ./0038-blk-mq-bypass-IO-scheduler-s-limit_depth-for-passthr.patch;
    patch -p1 < ./0039-bfq-mq-deadline-remove-redundant-check-for-passthrou.patch;
    echo "*** Copying and applying BFQ 5.12 patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/5.12/bfq-patches-v15-sep/*.patch .;
    patch -p1 < ./0024-block-bfq-remove-the-repeated-declaration.patch;
    patch -p1 < ./0030-block-bfq-let-also-stably-merged-queues-enjoy-weight.patch;
    patch -p1 < ./0031-block-bfq-fix-delayed-stable-merge-check.patch;
    patch -p1 < ./0032-block-bfq-consider-also-creation-time-in-delayed-sta.patch;
    patch -p1 < ./0033-block-bfq-boost-throughput-by-extending-queue-mergin.patch;
    patch -p1 < ./0034-block-bfq-avoid-delayed-merge-of-async-queues.patch;
    patch -p1 < ./0035-block-bfq-check-waker-only-for-queues-with-no-in-fli.patch;
    patch -p1 < ./0036-block-bfq-reset-waker-pointer-with-shared-queues.patch;
    echo "*** Copying and applying Valve fsync/futex patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/5.10/futex-patches/0001-futex-patches.patch .;
    patch -p1 < ./0001-futex-patches.patch;
    echo "*** Copying and applying misc fixes patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/fixes-miscellaneous-v5/*.patch .;
    patch -p1 < ./0001-fixes-miscellaneous.patch;
    echo "*** Copying and applying cve patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/cve-patches-v8-sep/*.patch .;
    patch -p1 < ./0001-consolemap-Fix-a-memory-leaking-bug-in-drivers-tty-v.patch;
    echo "*** Copying and applying exfat patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/exfat-patches/*.patch .;
    patch -p1 < ./0001-exfat-patches.patch;
    echo "*** Copying and applying SCSI patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/scsi-patches/*.patch .;
    patch -p1 < ./0001-scsi-patches.patch;
    echo "*** Copying and applying ll patches.. ✓"
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
    echo "*** Copying and applying intel_cpufreq patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/5.6/xanmod-patches/*.patch .;
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
    echo "*** Copying and applying graysky's GCC patch.. ✓"
    cp -v ${CUSTOM_PATCH_PATH}/graysky/graysky-gcc9-5.4.patch .;
    patch -p1 < ./graysky-gcc9-5.4.patch;
    echo "*** Copying and applying O3 patches.. ✓"
    cp -v ${CUSTOM_PATCH_PATH}/O3-optimization/O3-v5.4+.patch .;
    patch -p1 < ./O3-v5.4+.patch;
    echo "*** Copying and applying O3 fix patch.. ✓"
    cp -v ${CUSTOM_PATCH_PATH}/O3-optimization/0004-Makefile-Turn-off-loop-vectorization-for-GCC-O3-opti.patch .;
    patch -p1 < ./0004-Makefile-Turn-off-loop-vectorization-for-GCC-O3-opti.patch;
    echo "*** Copying and applying arch 5.7 patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/5.7/arch-patches-v9-sep/*.patch .;
    patch -p1 < ./0004-virt-vbox-Add-support-for-the-new-VBG_IOCTL_ACQUIRE_.patch;
    echo "*** Copying and applying arch 5.9 patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/5.9/arch-patches-v9-sep/*.patch .;
    patch -p1 < ./0004-HID-quirks-Add-Apple-Magic-Trackpad-2-to-hid_have_sp.patch;
    echo "*** Copying and applying arch 5.12 patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/5.12/arch-patches-v7-sep/*.patch .;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-from-5.12-arch-0002-x86-setup-Consolidate-early-memory-reservations.patch .;
    patch -p1 < ./5.4-from-5.12-arch-0002-x86-setup-Consolidate-early-memory-reservations.patch;
    patch -p1 < ./0003-x86-setup-Merge-several-reservations-of-start-of-mem.patch;
    patch -p1 < ./0004-x86-setup-Move-trim_snb_memory-later-in-setup_arch-t.patch;
    patch -p1 < ./0005-x86-setup-always-reserve-the-first-1M-of-RAM.patch;
    cp -v ${CUSTOM_PATCH_PATH}/backports/${KERNEL_BASE_VER}/5.4-from-5.12-arch-reserve_bios_regions.patch .;
    patch -p1 < ./5.4-from-5.12-arch-reserve_bios_regions.patch;
    patch -p1 < ./0007-x86-crash-remove-crash_reserve_low_1M.patch;
    echo "*** Copying and applying Clear Linux patches.. ✓"
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/clearlinux-patches-v6-sep/*.patch .;
    patch -p1 < ./0006-intel_idle-tweak-cpuidle-cstates.patch;
    patch -p1 < ./0009-raid6-add-Kconfig-option-to-skip-raid6-benchmarking.patch;
    patch -p1 < ./0016-Add-boot-option-to-allow-unsigned-modules.patch;
    patch -p1 < ./0020-use-lfence-instead-of-rep-and-nop.patch;
    echo "*** Copying and applying Clear Linux patches from 5.10.. ✓"
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
    if [ ${KERNEL_TYPE} = "rt" ]; then
        patch -p1 < ./0020-do-accept-in-LIFO-order-for-cache-efficiency-rt.patch;
        patch -p1 < ./include-linux-wait-h-merge-fix-rt.patch;
    else
        patch -p1 < ./0020-do-accept-in-LIFO-order-for-cache-efficiency.patch;
        patch -p1 < ./include-linux-wait-h-merge-fix.patch;
    fi
    patch -p1 < ./0021-locking-rwsem-spin-faster.patch;
    patch -p1 < ./0022-ata-libahci-ignore-staggered-spin-up.patch;
    patch -p1 < ./0023-print-CPU-that-faults.patch;
    patch -p1 < ./0025-nvme-workaround.patch;
    patch -p1 < ./0026-Don-t-report-an-error-if-PowerClamp-run-on-other-CPU.patch;
    if [ ${KERNEL_TYPE} = "rt" ]; then
        cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/arch-patches-rt-v3-sep/*.patch .;
        patch -p1 < ./0001-ZEN-Add-sysctl-and-CONFIG-to-disallow-unprivileged-C.patch;
        patch -p1 < ./0007-iwlwifi-pcie-restore-support-for-Killer-Qu-C0-NICs.patch;
        patch -p1 < ./0008-drm-i915-save-AUD_FREQ_CNTRL-state-at-audio-domain-s.patch;
        patch -p1 < ./0010-drm-i915-Fix-audio-power-up-sequence-for-gen10-displ.patch;
        patch -p1 < ./0011-drm-i915-extend-audio-CDCLK-2-BCLK-constraint-to-mor.patch;
        patch -p1 < ./0012-drm-i915-Limit-audio-CDCLK-2-BCLK-constraint-back-to.patch;
        patch -p1 < ./0016-drm-amdgpu-Add-DC-feature-mask-to-disable-fractional.patch;
        sed -i 's/sched_nr_migrate = 32/sched_nr_migrate = 256/g' ./kernel/sched/core.c;
        echo "*** Copying and applying arch-rt 5.4 patches.. ✓"
    else
        patch -p1 < ./0003-sched-core-nr_migrate-256-increases-number-of-tasks-.patch;
        echo "*** Copying and applying arch 5.4 patches.. ✓"
        cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/arch-patches-v25-sep/*.patch .;
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
    echo "*** Copying and applying pciacso patches.. ✓";
    cp -v ${XANMOD_PATCH_PATH}/linux-5.10.y-xanmod/pci_acso/*.patch .;
    patch -p1 < ./0001-add-acs-overrides_iommu.patch;
    echo "*** Copying and applying modules patches.. ✓";
    cp -v ${XANMOD_PATCH_PATH}/linux-5.10.y-xanmod/modules/*.patch .;
    patch -p1 < ./0001-modules-disinherit-taint-proprietary-module.patch;
    echo "*** Copying and applying xanmod patches.. ✓";
    cp -v ${XANMOD_PATCH_PATH}/linux-5.10.y-xanmod/xanmod/*.patch .;
    if ! [ ${KERNEL_TYPE} = "rt" ]; then
        patch -p1 < ./0005-kconfig-set-PREEMPT-and-RCU_BOOST-without-delay-by-d.patch;
    fi
    patch -p1 < ./0006-dcache-cache_pressure-50-decreases-the-rate-at-which.patch;
    patch -p1 < ./0009-cpufreq-tunes-ondemand-and-conservative-governor-for.patch;
    patch -p1 < ./0010-scripts-disable-the-localversion-tag-of-a-git-repo.patch;
elif [ ${KERNEL_BASE_VER} = "5.13" ]; then
    echo "*** Copying and applying alsa patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/alsa-patches-v2/*.patch .;
    patch -p1 < ./0001-alsa-patches.patch;
    echo "*** Copying and applying bbr2 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/bbr2-patches-v2/*.patch .;
    patch -p1 < ./0001-bbr2-patches.patch;
    echo "*** Copying and applying bfq patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/bfq-patches-v3-sep/*.patch .;
    patch -p1 < ./0001-block-bfq-let-also-stably-merged-queues-enjoy-weight.patch;
    if ! [ ${KERNEL_TYPE} = "rt" ]; then
        patch -p1 < ./0002-block-bfq-consider-also-creation-time-in-delayed-sta.patch;
        patch -p1 < ./0003-block-bfq-boost-throughput-by-extending-queue-mergin.patch;
    fi
    patch -p1 < ./0004-block-bfq-check-waker-only-for-queues-with-no-in-fli.patch;
    patch -p1 < ./0005-block-Do-not-pull-requests-from-the-scheduler-when-w.patch;
    patch -p1 < ./0006-block-Remove-unnecessary-elevator-operation-checks.patch;
    patch -p1 < ./0007-bfq-Remove-merged-request-already-in-bfq_requests_me.patch;
    patch -p1 < ./0008-blk-Fix-lock-inversion-between-ioc-lock-and-bfqd-loc.patch;
    patch -p1 < ./0009-block-bfq-remove-the-repeated-declaration.patch;
    echo "*** Copying and applying block patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/block-patches-v2/*.patch .;
    patch -p1 < ./0001-block-patches.patch;
    if ! [ ${KERNEL_TYPE} = "rt" ]; then
        echo "*** Copying and applying btrfs patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/btrfs-patches-v2/*.patch .;
        patch -p1 < ./0001-btrfs-patches.patch;
    fi
    echo "*** Copying and applying cjktty patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/cjktty-patches/*.patch .;
    patch -p1 < ./0001-cjktty-5.13-initial-import-from-https-github.com-zhm.patch;
    echo "*** Copying and applying clearlinux patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/clearlinux-patches-v2-sep/*.patch .;
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
    if [ ${KERNEL_TYPE} = "rt" ]; then
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
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/cpu-patches/*.patch .;
    patch -p1 < ./0001-cpu-patches.patch;
    echo "*** Copying and applying fixes misc patches.. ✓"
    cp -v ${CUSTOM_PATCH_PATH}/fixes/${KERNEL_BASE_VER}/5.13-fixes-miscellaneous-all-in-one.patch .;
    patch -p1 < ./5.13-fixes-miscellaneous-all-in-one.patch;
    if ! [ ${KERNEL_TYPE} = "rt" ]; then
        echo "*** Copying and applying ksm patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/ksm-patches/*.patch .;
        patch -p1 < ./0001-ksm-patches.patch;
    fi
    echo "*** Copying and applying lrng patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/lrng-patches/*.patch .;
    patch -p1 < ./0001-lrng-patches.patch;
    echo "*** Copying and applying lru-mm patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/lru-patches-v5/*.patch .;
    patch -p1 < ./0001-lru-patches.patch;
    echo "*** Copying and applying ntfs3 patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/ntfs3-patches/*.patch .;
    patch -p1 < ./0001-ntfs3-patches.patch;
    echo "*** Copying and applying pf patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/pf-patches-v6-sep/*.patch .;
    patch -p1 < ./0001-genirq-i2c-Provide-and-use-generic_dispatch_irq.patch;
    patch -p1 < ./0002-mac80211-minstrel_ht-force-ampdu_len-to-be-0.patch;
    patch -p1 < ./0003-net-replace-WARN_ONCE-with-pr_warn_once.patch;
    patch -p1 < ./0004-Revert-Revert-mm-shmem-fix-shmem_swapin-race-with-sw.patch;
    patch -p1 < ./0005-Revert-Revert-swap-fix-do_swap_page-race-with-swapof.patch;
    echo "*** Copying and applying spadfs patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/spadfs-patches/*.patch .;
    patch -p1 < ./0001-spadfs-5.13-merge-v1.0.14.patch;
    echo "*** Copying and applying swap patches.. ✓";
    cp -v $LUCJAN_PATCH_PATH/$KERNEL_BASE_VER/swap-patches/*.patch .;
    patch -p1 < ./0001-swap-patches.patch;
    echo "*** Copying and applying v4l2loopback-patches patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/v4l2loopback-patches/*.patch .;
    patch -p1 < ./0001-v4l2loopback-patches.patch;
    echo "*** Copying and applying writeback patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/writeback-patches/*.patch .;
    patch -p1 < ./0001-writeback-patches.patch;
    echo "*** Copying and applying xanmod patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/xanmod-patches/*.patch .;
    patch -p1 < ./0001-sched-autogroup-Add-kernel-parameter-and-config-opti.patch;
    echo "*** Copying and applying zstd patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/zstd-patches-v4/*.patch .;
    patch -p1 < ./0001-zstd-patches.patch;
    echo "*** Copying and applying zen patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/zen-patches-sep/*.patch .;
    patch -p1 < ./0001-ZEN-Add-VHBA-driver.patch
    patch -p1 < ./0002-ZEN-intel-pstate-Implement-enable-parameter.patch
    patch -p1 < ./0003-ZEN-vhba-Update-to-20210418.patch
    echo "*** Copying and applying ll patches.. ✓"
    cp -v ${CUSTOM_PATCH_PATH}/ll-patches/*.patch .;
    patch -p1 < ./0001-LL-kconfig-add-500Hz-timer-interrupt-kernel-config-o.patch;
    patch -p1 < ./0004-mm-set-8-megabytes-for-address_space-level-file-read.patch;
    if [ ${KERNEL_TYPE} = "rt" ]; then
        sed -i 's/sched_nr_migrate = 32/sched_nr_migrate = 256/g' ./kernel/sched/core.c;
    else
        patch -p1 < ./0003-sched-core-nr_migrate-256-increases-number-of-tasks-.patch;
    fi
    if [ ${KERNEL_TYPE} = "rt" ]; then
        echo "*** Copying and applying Valve fsync patches.. ✓";
        cp -v ${CUSTOM_PATCH_PATH}/rt/${KERNEL_BASE_VER}/5-13-futex-rt.patch .;
        patch -p1 < ./5-13-futex-rt.patch;
        echo "*** Copying and applying Valve fsync fix patches.. ✓";
        cp -v ${CUSTOM_PATCH_PATH}/rt/${KERNEL_BASE_VER}/futex-rt-fix.patch .;
        patch -p1 < ./futex-rt-fix.patch;
    else
        echo "*** Copying and applying Valve fsync patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/futex-patches/*.patch .;
        patch -p1 < ./0001-futex-resync-from-gitlab.collabora.com.patch;
        echo "*** Copying and applying futex2 zen patches.. ✓";
        cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/futex2-zen-patches-v2/*.patch .;
        patch -p1 < ./0001-futex2-resync-from-gitlab.collabora.com.patch;
    fi
    echo "*** Copying and applying lqx patches.. ✓";
    cp -v ${LUCJAN_PATCH_PATH}/$KERNEL_BASE_VER/lqx-patches-v2-sep/*.patch .;
    patch -p1 < ./0001-zen-Allow-MSR-writes-by-default.patch;
    patch -p1 < ./0002-PCI-Add-Intel-remapped-NVMe-device-support.patch;
    echo "*** Copying and applying cfs zen tweaks patch.. ✓";
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/cfs-zen-tweaks.patch .;
    patch -p1 < ./cfs-zen-tweaks.patch;
    echo "*** Copying and applying cfs xanmod tweaks patch.. ✓";
    #https://github.com/xanmod/linux-patches/tree/master/linux-5.13.y-xanmod
    cp -v ${CUSTOM_PATCH_PATH}/tweaks/5.13-cfs-xanmod-tweaks.patch .;
    patch -p1 < ./5.13-cfs-xanmod-tweaks.patch;
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
fi

# CacULE scheduler enabled by default. To disable, pass KERNEL_SCHEDULER=cfs
if [ ${KERNEL_SCHEDULER} = "cacule" ]; then
    echo "*** Copying and applying CacULE patch.. ✓"
    if [ "${KERNEL_BASE_VER}" = "5.4" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/cacule-sched/cacule-5.4*.patch .;
        patch -p1 < ./cacule-5.4.patch;
        for i in {1..16}; do
            patch -p1 < ./cacule-5.4-merge-fixes-part${i}.patch;
        done
    elif [ "${KERNEL_BASE_VER}" = "5.13" ]; then
        cp -v ${CUSTOM_PATCH_PATH}/cacule-sched/cacule-5.13*.patch .;
        cp -v ${CUSTOM_PATCH_PATH}/cacule-sched/rdb-5.13*.patch .;
        patch -p1 < ./cacule-5.13.patch;
        patch -p1 < ./cacule-5.13-fix-migration-cost-merge.patch;
        # patch -p1 < ./rdb-5.13.patch;
    fi
fi

# Examples:
# 5.4.136-0504136+customidle-generic
# 5.4.136-0504136+customfull-generic
# 5.4.136-0504136+customrt-generic
# Note: A hyphen between label and type (e.g. customidle -> custom-idle) causes problems with some parsers
# Because the final version name becomes: 5.4.136-0504136+custom-idle-generic, so just keep it combined
echo "*** Updating version in changelog (necessary for Ubuntu)... ✓"
sed -i "s/${KERNEL_SUB_VER}/${KERNEL_SUB_VER}+${KERNEL_VERSION_LABEL}${KERNEL_TYPE}/g" ./debian.master/changelog;

# For whatever reason, this errors for me, may not error for you
echo "*** Disabling ZFS during install which appears to be causing problems... ✓"
sed -i 's/do_zfs/#do_zfs/g' ./debian.master/rules.d/amd64.mk;

# Disable virtualbox dkms
echo "*** Disabling zfs, vbox, wireguard dkms... ✓"
sed -i 's/do_dkms_vbox    = true/do_dkms_vbox    = false/g' ./debian.master/rules.d/amd64.mk;
sed -i 's/do_dkms_nvidia  = true/do_dkms_nvidia  = false/g' ./debian.master/rules.d/amd64.mk;
sed -i 's/do_dkms_wireguard = true/do_dkms_wireguard = false/g' ./debian.master/rules.d/amd64.mk;

# Build only for amd64 (saves lots of time here when compiling)
echo "*** Removing unnecessary arch's and building just for amd64... ✓";
sed -i 's/archs="amd64 i386 armhf arm64 ppc64el s390x"/archs="amd64"/g' ./debian.master/etc/kernelconfig;

echo "*** Making scripts executable... ✓"
chmod a+x debian/rules
chmod a+x debian/scripts/*
chmod a+x debian/scripts/misc/*

echo "*** Create symlink for kernel ABI... ✓"
[[ ${KERNEL_BASE_VER} == "5.4" ]] && ABI_VERSION=5.4.0-25.29 || ABI_VERSION=5.7.0-5.6;
ln -rsv ./debian.master/abi/${ABI_VERSION} ./debian.master/abi/${KERNEL_PATCH_VER}-0.0

echo "*** Running fakeroot debian/rules clean... ✓"
fakeroot debian/rules clean

echo "*** Copying over our custom configs... ✓"
/bin/cp -fv ${CONFIG_PATH}/ubuntu-${KERNEL_BASE_VER}-${KERNEL_TYPE}/config.common.amd64 ./debian.master/config/amd64
/bin/cp -fv ${CONFIG_PATH}/ubuntu-${KERNEL_BASE_VER}-${KERNEL_TYPE}/config.flavour.generic ./debian.master/config/amd64
/bin/cp -fv ${CONFIG_PATH}/ubuntu-${KERNEL_BASE_VER}-${KERNEL_TYPE}/config.flavour.lowlatency ./debian.master/config/amd64
/bin/cp -fv ${CONFIG_PATH}/ubuntu-${KERNEL_BASE_VER}-${KERNEL_TYPE}/config.common.ubuntu ./debian.master/config

AMDGPU_BUILTIN=${AMDGPU_BUILTIN:-"no"}
if [ ${AMDGPU_BUILTIN} = "yes" ]; then
    # Note: this long string is generated by:
    # cd /lib/firmware, then: ls amdgpu/polaris* and hit tab for it auto-complete to grab all of the files
    # For example, for Navi: ls amdgpu/navi* and populate EXTRA_FIRMWARE with Navi blobs. This will be done
    # automatically in a future version. For now, just do Polaris.
    echo "Updating config to build-in amdgpu into the kernel... ✓";
    sed -i 's/CONFIG_EXTRA_FIRMWARE_DIR=""/CONFIG_EXTRA_FIRMWARE_DIR="\/lib\/firmware"/g' ./debian.master/config/config.common.ubuntu
    sed -i 's/CONFIG_EXTRA_FIRMWARE=""/CONFIG_EXTRA_FIRMWARE="amdgpu\/polaris10_ce_2.bin amdgpu\/polaris10_ce.bin amdgpu\/polaris10_k2_smc.bin amdgpu\/polaris10_k_mc.bin amdgpu\/polaris10_k_smc.bin amdgpu\/polaris10_mc.bin amdgpu\/polaris10_me_2.bin amdgpu\/polaris10_me.bin amdgpu\/polaris10_mec2_2.bin amdgpu\/polaris10_mec_2.bin amdgpu\/polaris10_mec2.bin amdgpu\/polaris10_mec.bin amdgpu\/polaris10_pfp_2.bin amdgpu\/polaris10_pfp.bin amdgpu\/polaris10_rlc.bin amdgpu\/polaris10_sdma1.bin amdgpu\/polaris10_sdma.bin amdgpu\/polaris10_smc.bin amdgpu\/polaris10_smc_sk.bin amdgpu\/polaris10_uvd.bin amdgpu\/polaris10_vce.bin amdgpu\/polaris11_ce_2.bin amdgpu\/polaris11_ce.bin amdgpu\/polaris11_k2_smc.bin amdgpu\/polaris11_k_mc.bin amdgpu\/polaris11_k_smc.bin amdgpu\/polaris11_mc.bin amdgpu\/polaris11_me_2.bin amdgpu\/polaris11_me.bin amdgpu\/polaris11_mec2_2.bin amdgpu\/polaris11_mec_2.bin amdgpu\/polaris11_mec2.bin amdgpu\/polaris11_mec.bin amdgpu\/polaris11_pfp_2.bin amdgpu\/polaris11_pfp.bin amdgpu\/polaris11_rlc.bin amdgpu\/polaris11_sdma1.bin amdgpu\/polaris11_sdma.bin amdgpu\/polaris11_smc.bin amdgpu\/polaris11_smc_sk.bin amdgpu\/polaris11_uvd.bin amdgpu\/polaris11_vce.bin amdgpu\/polaris12_32_mc.bin amdgpu\/polaris12_ce_2.bin amdgpu\/polaris12_ce.bin amdgpu\/polaris12_k_mc.bin amdgpu\/polaris12_k_smc.bin amdgpu\/polaris12_mc.bin amdgpu\/polaris12_me_2.bin amdgpu\/polaris12_me.bin amdgpu\/polaris12_mec2_2.bin amdgpu\/polaris12_mec_2.bin amdgpu\/polaris12_mec2.bin amdgpu\/polaris12_mec.bin amdgpu\/polaris12_pfp_2.bin amdgpu\/polaris12_pfp.bin amdgpu\/polaris12_rlc.bin amdgpu\/polaris12_sdma1.bin amdgpu\/polaris12_sdma.bin amdgpu\/polaris12_smc.bin amdgpu\/polaris12_uvd.bin amdgpu\/polaris12_vce.bin"/g' ./debian.master/config/amd64/config.flavour.generic
else
    # If AMDGPU_BUILTIN=no (or if it's not passed into the build script, the default) remove it from the config if it
    # was previously set. If it was never set to begin with, sed will quietly error since it didn't find a string match
    echo "Updating config to build amdgpu as a module... ✓";
    sed -i 's/CONFIG_EXTRA_FIRMWARE_DIR="\/lib\/firmware"/CONFIG_EXTRA_FIRMWARE_DIR=""/g' ./debian.master/config/config.common.ubuntu
    sed -i 's/CONFIG_EXTRA_FIRMWARE="amdgpu\/polaris10_ce_2.bin amdgpu\/polaris10_ce.bin amdgpu\/polaris10_k2_smc.bin amdgpu\/polaris10_k_mc.bin amdgpu\/polaris10_k_smc.bin amdgpu\/polaris10_mc.bin amdgpu\/polaris10_me_2.bin amdgpu\/polaris10_me.bin amdgpu\/polaris10_mec2_2.bin amdgpu\/polaris10_mec_2.bin amdgpu\/polaris10_mec2.bin amdgpu\/polaris10_mec.bin amdgpu\/polaris10_pfp_2.bin amdgpu\/polaris10_pfp.bin amdgpu\/polaris10_rlc.bin amdgpu\/polaris10_sdma1.bin amdgpu\/polaris10_sdma.bin amdgpu\/polaris10_smc.bin amdgpu\/polaris10_smc_sk.bin amdgpu\/polaris10_uvd.bin amdgpu\/polaris10_vce.bin amdgpu\/polaris11_ce_2.bin amdgpu\/polaris11_ce.bin amdgpu\/polaris11_k2_smc.bin amdgpu\/polaris11_k_mc.bin amdgpu\/polaris11_k_smc.bin amdgpu\/polaris11_mc.bin amdgpu\/polaris11_me_2.bin amdgpu\/polaris11_me.bin amdgpu\/polaris11_mec2_2.bin amdgpu\/polaris11_mec_2.bin amdgpu\/polaris11_mec2.bin amdgpu\/polaris11_mec.bin amdgpu\/polaris11_pfp_2.bin amdgpu\/polaris11_pfp.bin amdgpu\/polaris11_rlc.bin amdgpu\/polaris11_sdma1.bin amdgpu\/polaris11_sdma.bin amdgpu\/polaris11_smc.bin amdgpu\/polaris11_smc_sk.bin amdgpu\/polaris11_uvd.bin amdgpu\/polaris11_vce.bin amdgpu\/polaris12_32_mc.bin amdgpu\/polaris12_ce_2.bin amdgpu\/polaris12_ce.bin amdgpu\/polaris12_k_mc.bin amdgpu\/polaris12_k_smc.bin amdgpu\/polaris12_mc.bin amdgpu\/polaris12_me_2.bin amdgpu\/polaris12_me.bin amdgpu\/polaris12_mec2_2.bin amdgpu\/polaris12_mec_2.bin amdgpu\/polaris12_mec2.bin amdgpu\/polaris12_mec.bin amdgpu\/polaris12_pfp_2.bin amdgpu\/polaris12_pfp.bin amdgpu\/polaris12_rlc.bin amdgpu\/polaris12_sdma1.bin amdgpu\/polaris12_sdma.bin amdgpu\/polaris12_smc.bin amdgpu\/polaris12_uvd.bin amdgpu\/polaris12_vce.bin/CONFIG_EXTRA_FIRMWARE=""/g' ./debian.master/config/amd64/config.flavour.generic
fi

echo -n "[${KERNEL_PATCH_VER} ${KERNEL_SCHEDULER} ${KERNEL_TYPE}] Do you need to run editconfigs? [Y/n]: "
read yno
case $yno in
    [nN] | [n|N][O|o] )
        echo "Okay, moving on.";
        ;;
    [yY] | [yY][Ee][Ss] )
        fakeroot debian/rules editconfigs
        ;;
    *)
        fakeroot debian/rules editconfigs
        ;;
esac

echo -n "[${KERNEL_PATCH_VER} ${KERNEL_SCHEDULER} ${KERNEL_TYPE}] Copy over the new config changes? [y/N]: "
read yno
case $yno in
    [yY] | [yY][Ee][Ss] )
        echo "*** Copying configs... ✓"
        /bin/cp -fv ./debian.master/config/amd64/config.* ${CONFIG_PATH}/ubuntu-${KERNEL_BASE_VER}-${KERNEL_TYPE}
        /bin/cp -fv ./debian.master/config/config.common.ubuntu ${CONFIG_PATH}/ubuntu-${KERNEL_BASE_VER}-${KERNEL_TYPE}
        ;;
    [nN] | [n|N][O|o] )
        echo "Okay, moving on.";
        ;;
    *)
        echo "Okay, moving on.";
        ;;
esac

echo -n "[${KERNEL_PATCH_VER} ${KERNEL_SCHEDULER} ${KERNEL_TYPE}] Do you want to start building? [Y/n]: "
read yno
case $yno in
    [nN] | [n|N][O|o] )
        echo "All good. Exiting.";
        exit 0
        ;;
    [yY] | [yY][Ee][Ss] )
        echo "Starting build... ✓"
        fakeroot debian/rules binary-headers binary-generic binary-perarch
        ;;
    *)
        echo "Starting build... ✓"
        fakeroot debian/rules binary-headers binary-generic binary-perarch
        ;;
esac

# Install the compiled kernel
echo "*** Finished compiling kernel, installing... ✓"
cd ..
COMPILED_KERNEL_VER=${KERNEL_PATCH_VER}-${KERNEL_SUB_VER}+${KERNEL_VERSION_LABEL}-${KERNEL_TYPE}
TIME_BUILT=$(date +%s)
mkdir -pv ${COMPILED_KERNEL_VER}-${TIME_BUILT}
mv -v *.deb ${COMPILED_KERNEL_VER}-${TIME_BUILT}
cd ${COMPILED_KERNEL_VER}-${TIME_BUILT}
sudo dpkg -i *.deb;
cd -

# Create directory for compiled kernels if it doesn't aleady exist
if ! [[ -d ${COMPILED_KERNELS_DIR} ]]; then
    echo "*** Compiled kernel directory doesn't exist, creating... ✓"
    mkdir -pv ${COMPILED_KERNELS_DIR}
fi
# Move our new compiled *.deb's for our kernel into our compiled directory
mv -v ${COMPILED_KERNEL_VER}-${TIME_BUILT} ${COMPILED_KERNELS_DIR}

# VirtualBox requires this missing module.lds for 5.4 support
# To use: Pass VBOX_SUPPORT=yes to the build script
VBOX_SUPPORT=${VBOX_SUPPORT:-"no"}
if [ ${VBOX_SUPPORT} = "yes" ]; then
    if [ ${KERNEL_BASE_VER} = "5.4" ]; then
        echo "*** Enabling VirtualBox support for 5.4 kernel... ✓"
        sudo cp -v ${CUSTOM_PATCH_PATH}/virtualbox-5.4-support/module.lds /usr/src/linux-headers-${KERNEL_PATCH_VER}-${KERNEL_SUB_VER}+${KERNEL_VERSION_LABEL}-generic/scripts/module.lds;
        sudo /sbin/vboxconfig;
    fi
fi

# Final cleanup
echo "*** Finished installing kernel, cleaning up build dir... ✓"
rm -rf ${KERNEL_BUILD_DIR}
cd
ls -al ${COMPILED_KERNELS_DIR}
ls -al ${COMPILED_KERNELS_DIR}/${COMPILED_KERNEL_VER}-${TIME_BUILT}
echo "*** All done. ✓"
echo "*** You can now reboot and select ${COMPILED_KERNEL_VER} in GRUB."
