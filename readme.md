Compile the Linux kernel for Ubuntu with custom patches and optimizations.

## Why?

Well, because you can. Don't let anyone tell you otherwise. But it's recommended for advanced users only. With great power...

## Supported versions

- 6.10 (rc)
- 6.9 (stable)
- 6.6 LTS (Long-term support, until 2029)
- 6.1 LTS (Long-term support, until 2028)
- 5.15 LTS (Long-term support, until 2027)
- 5.10 LTS (Long-term support, until 2026)
- 5.4 LTS (Long-term support, until 2025)

## So, how do I use this?

Assuming a fresh install of Ubuntu, you'll need the following dependencies:

```console
$ sudo apt install git build-essential kernel-wedge fakeroot flex bison binutils-dev libssl-dev libelf-dev libslang2-dev libpci-dev libiberty-dev libcap-dev libudev-dev libdw-dev libunwind-dev libncurses-dev libzstd-dev libnuma-dev libbabeltrace-dev libpfm4-dev lz4 zstd wireless-tools default-jre default-jdk linux-cloud-tools-common linux-tools-$(uname -r)

```

## Getting started

```console
$ git clone https://github.com/arvin-foroutan/build-ubuntu-kernel.git
$ cd build-ubuntu-kernel
$ ./build_kernel.sh
```

## Is that it?

That's it. The script is meant to be fully automated.

However, you should always review any script before running it.

See the script itself for additional details, and the information below on some extra stuff you can do.

### Passing in optional variables

```console
$ AMDGPU_BUILTIN=yes VBOX_SUPPORT=yes ./build_kernel.sh
```

#### Variables

```console
  AMDGPU_BUILTIN		Build the amdgpu module into the kernel (default: no)
  VBOX_SUPPORT			Add support for VirtualBox (default: no)
```

### Building other versions

By default, the latest 6.9 stable kernel will be built with the following:

- Low-Latency Preemptive Kernel
- 1000 Hz timer, idle tickless
- Built with gcc and 'Generic x86/64' optimizations.

Current patch set includes:

 - AMD P-State driver
 - BBR3 TCP congestion control
 - Multi-generational LRU
 - CachyOS patches
 - Xanmod patches
 - PF-kernel patches
 - FUTEX Proton/Wine Fsync support
 - NT sync primitives emulation driver
 - Steamdeck/Valve patches
 - Graysky GCC optimizations
 - Various arch patches
 - IO scheduler patches
 - AUFS support

To build other versions, you can use the following convention:

6.6 LTS:

```console
$ KERNEL_BASE_VER=6.6 KERNEL_PATCH_VER=6.6.32 KERNEL_SUB_VER=060632 ./build_kernel.sh
```

6.1 LTS:

```console
$ KERNEL_BASE_VER=6.1 KERNEL_PATCH_VER=6.1.92 KERNEL_SUB_VER=060192 ./build_kernel.sh
```

5.15 LTS:

```console
$ KERNEL_MAJOR_VER=5 KERNEL_BASE_VER=5.15 KERNEL_PATCH_VER=5.15.160 KERNEL_SUB_VER=0515160 ./build_kernel.sh
```

5.10 LTS:

```console
$ KERNEL_MAJOR_VER=5 KERNEL_BASE_VER=5.10 KERNEL_PATCH_VER=5.10.218 KERNEL_SUB_VER=0510218 ./build_kernel.sh
```

5.4 LTS:

```console
$ KERNEL_MAJOR_VER=5 KERNEL_BASE_VER=5.4 KERNEL_PATCH_VER=5.4.277 KERNEL_SUB_VER=0504277 ./build_kernel.sh
```

#### Development kernels

6.10-rc1:

```console
$ KERNEL_SRC_URI="https://git.kernel.org/torvalds/t" KERNEL_SRC_EXT="tar.gz" KERNEL_BASE_VER=6.10 KERNEL_PATCH_VER=6.10-rc1 KERNEL_SUB_VER=061000rc1 ./build_kernel.sh
```

#### RT kernels

Real-time kernels have specific use-cases and generally should only be used if you know why you need it.

6.7-rt:

```console
$ KERNEL_TYPE=rt KERNEL_BASE_VER=6.7 KERNEL_PATCH_VER=6.7 KERNEL_SUB_VER=060700 ./build_kernel.sh
```

6.6-rt:

```console
$ KERNEL_TYPE=rt KERNEL_BASE_VER=6.6 KERNEL_PATCH_VER=6.6.14 KERNEL_SUB_VER=060614 ./build_kernel.sh
```

6.1-rt:

```console
$ KERNEL_TYPE=rt KERNEL_BASE_VER=6.1 KERNEL_PATCH_VER=6.1.75 KERNEL_SUB_VER=060175 ./build_kernel.sh
```

5.15-rt:

```console
$ KERNEL_TYPE=rt KERNEL_MAJOR_VER=5 KERNEL_BASE_VER=5.15 KERNEL_PATCH_VER=5.15.145 KERNEL_SUB_VER=0515145 ./build_kernel.sh
```

5.10-rt:

```console
$ KERNEL_TYPE=rt KERNEL_MAJOR_VER=5 KERNEL_BASE_VER=5.10 KERNEL_PATCH_VER=5.10.209 KERNEL_SUB_VER=0510209 ./build_kernel.sh
```

5.4-rt:

```console
$ KERNEL_TYPE=rt KERNEL_MAJOR_VER=5 KERNEL_BASE_VER=5.4 KERNEL_PATCH_VER=5.4.264 KERNEL_SUB_VER=0504264 ./build_kernel.sh
```

#### Full tickless kernels

Just pass `KERNEL_TYPE=full` to any kernel build:

```console
$ KERNEL_TYPE=full ./build_kernel.sh
```

Note: Full tickless kernels require `nohz_full` GRUB boot parameter to be set with specific CPU cores for it to be useful. Otherwise, there is extra overhead over the traditional idle tickless kernel. 

Examples of the `nohz_full` setting:

4c: `nohz_full=1-3`

4c/8t: `nohz_full=1-3,5-7`

6c/12t `nohz_full=1-5,7-11`

8c/16t: `nohz_full=1-7,9-15`

### Additional Notes

1. Ubuntu splits up the kernel config into multiple files to limit redundancy across their *generic* and *low-latency* kernels.

2. For the purpose of this script, only the *generic* kernel is built (as a *low-latency* kernel), and the *low-latency* kernel is ignored. This may change in the future.

3. When asked by the script if you want to edit the low-latency config, you'll want to say 'n' as the generic kernel built by the script *is* the low-latency kernel.

4. In the configs folder, you'll find the following different flavors. The idle, full, and rt configs already have the optimizations included.

 - `idle`: idle tickless config (used by default)

 - `full`: full tickless config

 - `rt`: real-time config
 
 - `defaults`: Ubuntu's config (provided as a reference, not to be used)
 
5. For kernels 5.4 and 5.10, it will automatically default to "Native Optimizations" (-march=native), the other versions will need to be set manually in the config when you run the script. 

6. There's also a more generic "Core 2" option, but you should select your specific processor from the dropdown if you see it, or, "Intel Native" or "AMD Native" or "Zen 3" to create the fastest "happy" path for the compiled kernel.

7. To set your CPU processor, while in the config, select `Processor type and features` and then look for `Processor family`. (You can use forward slash ( / ) to search for anything in the config)

8. To stay up-to-date with the repo, you can always `git stash` your changes, then run `git pull`, and then run `git stash apply` to apply back your changes.

9. The build script is now yours; not mine. Feel free to make any modifications to it, and have fun.

### Script in action

![](https://i.imgur.com/1ByFhHi.gif)
