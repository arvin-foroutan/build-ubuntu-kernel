Compile the Linux kernel for Ubuntu with custom patches and optimizations.

## Why?

Well, because you can. Don't let anyone tell you otherwise. But it's recommended for advanced users only. With great power...

## Supported versions

- 7.0 (mainline)
- 6.19 (stable)
- 6.18 LTS (Long-term support, until 2031)
- 6.12 LTS (Long-term support, until 2030)
- 6.6 LTS (Long-term support, until 2029)
- 6.1 LTS (Long-term support, until 2028)
- 5.15 LTS (Long-term support, until 2027)
- 5.10 LTS (Long-term support, until 2026)

## So, how do I use this?

Assuming a fresh install of Ubuntu, you'll need the following dependencies:

```console
sudo apt install git build-essential kernel-wedge fakeroot flex bison binutils-dev libssl-dev libelf-dev libslang2-dev libpci-dev libiberty-dev libcap-dev libudev-dev libdw-dev libunwind-dev libncurses-dev libzstd-dev libnuma-dev libbabeltrace-dev libpfm4-dev lz4 zstd default-jre default-jdk linux-cloud-tools-common linux-tools-$(uname -r)
```

## Getting started

```console
git clone https://github.com/arvin-foroutan/build-ubuntu-kernel.git
cd build-ubuntu-kernel
./build_kernel.sh
```

## Is that it?

That's it. The script is meant to be fully automated.

However, you should always review any script before running it.

See the script itself for additional details, and the information below on some extra stuff you can do.

### Passing in optional variables

```console
VBOX_SUPPORT=yes ./build_kernel.sh
```

#### Variables

```console
  VBOX_SUPPORT      Add support for VirtualBox (default: no)
  USE_LLVM          Compile the kernel using LLVM/Clang instead of GCC (default: no)
```

### Building other versions

By default, the latest 7.0 mainline kernel will be built with the following:

- Low-Latency Preemptive Kernel
- 1000 Hz timer, idle tickless, -O3 optimization
- Built with gcc and '-march=native' optimizations.

Current patch set includes:

 - AMD P-State driver
 - BMQ Scheduler
 - BBR3 TCP congestion control
 - Multi-generational LRU
 - Adaptive Deadline I/O Scheduler (ADIOS)
 - CachyOS patches
 - Lucjan patches
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

6.19:

```console
KERNEL_BASE_VER=6.19 KERNEL_PATCH_VER=6.19.14 KERNEL_SUB_VER=061914 ./build_kernel.sh
```

6.18 LTS:

```console
KERNEL_BASE_VER=6.18 KERNEL_PATCH_VER=6.18.15 KERNEL_SUB_VER=061815 ./build_kernel.sh
```

6.12 LTS:

```console
KERNEL_BASE_VER=6.12 KERNEL_PATCH_VER=6.12.74 KERNEL_SUB_VER=061274 ./build_kernel.sh
```

6.6 LTS:

```console
KERNEL_BASE_VER=6.6 KERNEL_PATCH_VER=6.6.127 KERNEL_SUB_VER=0606127 ./build_kernel.sh
```

6.1 LTS:

```console
KERNEL_BASE_VER=6.1 KERNEL_PATCH_VER=6.1.164 KERNEL_SUB_VER=0601164 ./build_kernel.sh
```

5.15 LTS:

```console
KERNEL_MAJOR_VER=5 KERNEL_BASE_VER=5.15 KERNEL_PATCH_VER=5.15.201 KERNEL_SUB_VER=0515201 ./build_kernel.sh
```

5.10 LTS:

```console
KERNEL_MAJOR_VER=5 KERNEL_BASE_VER=5.10 KERNEL_PATCH_VER=5.10.251 KERNEL_SUB_VER=0510251 ./build_kernel.sh
```

#### Development kernels

7.0-rc1:

```console
KERNEL_MAJOR_VER=7 KERNEL_SRC_URI="https://git.kernel.org/torvalds/t" KERNEL_SRC_EXT="tar.gz" KERNEL_BASE_VER=7.0 KERNEL_PATCH_VER=7.0-rc1 KERNEL_SUB_VER=070000rc1 ./build_kernel.sh
```

#### RT kernels

Real-time kernels have specific use-cases and generally should only be used if you know why you need it.

Note: RT kernel support has been mainlined (since 6.12) and can be selected when running the config.

For previous versions, you can use the following convention:

6.6-rt:

```console
KERNEL_TYPE=rt KERNEL_BASE_VER=6.6 KERNEL_PATCH_VER=6.6.87 KERNEL_SUB_VER=060687 ./build_kernel.sh
```

6.1-rt:

```console
KERNEL_TYPE=rt KERNEL_BASE_VER=6.1 KERNEL_PATCH_VER=6.1.134 KERNEL_SUB_VER=0601134 ./build_kernel.sh
```

5.15-rt:

```console
KERNEL_TYPE=rt KERNEL_MAJOR_VER=5 KERNEL_BASE_VER=5.15 KERNEL_PATCH_VER=5.15.183 KERNEL_SUB_VER=0515183 ./build_kernel.sh
```

5.10-rt:

```console
KERNEL_TYPE=rt KERNEL_MAJOR_VER=5 KERNEL_BASE_VER=5.10 KERNEL_PATCH_VER=5.10.237 KERNEL_SUB_VER=0510237 ./build_kernel.sh
```

#### Full tickless kernels

Just pass `KERNEL_TYPE=full` to any kernel build:

```console
KERNEL_TYPE=full ./build_kernel.sh
```

Note: Full tickless kernels require `nohz_full` GRUB boot parameter to be set with specific CPU cores for it to be useful. Otherwise, there is extra overhead over the traditional idle tickless kernel. 

Examples of the `nohz_full` setting:

4c: `nohz_full=1-3`

4c/8t: `nohz_full=1-7`

8c/16t: `nohz_full=1-15`

12c/24t: `nohz_full=1-23`

16c/32t: `nohz_full=1-31`

### Additional Notes

1. Ubuntu splits up the kernel config into multiple files to limit redundancy across their *generic* and *low-latency* kernels.

2. For the purpose of this script, only the *generic* kernel is built (as a *low-latency* kernel), and the *low-latency* kernel is ignored. This may change in the future.

3. When asked by the script if you want to edit the low-latency config, you'll want to say 'n' as the generic kernel built by the script *is* the low-latency kernel.

4. In the configs folder, you'll find the following different flavors. The idle, full, and rt configs already have the optimizations included.

 - `idle`: idle tickless config (used by default)

 - `full`: full tickless config

 - `rt`: real-time config
 
 - `defaults`: Ubuntu's config (provided as a reference, not to be used)
 
5. For kernel 5.10, it will automatically default to "Native Optimizations" (-march=native), the other versions will need to be set manually in the config when you run the script.

6. There's also a more generic "Core 2" option, but you should select your specific processor from the dropdown if you see it, or, "Intel Native" or "AMD Native" or "Zen 3" to create the fastest "happy" path for the compiled kernel.

7. To set your CPU processor, while in the config, select `Processor type and features` and then look for `Processor family`. (You can use forward slash ( / ) to search for anything in the config)

8. To stay up-to-date with the repo, you can always `git stash` your changes, then run `git pull`, and then run `git stash apply` to apply back your changes.

9. The build script is now yours; not mine. Feel free to make any modifications to it, and have fun.

### Benchmarks

March 14, 2026 - AMD Ryzen 5950X - [OpenBenchmarking](https://openbenchmarking.org/result/2603149-NE-OSBENCHKE55)

June 16, 2024 - Intel i5-4670K - [OpenBenchmarking](https://openbenchmarking.org/result/2406165-NE-OSBENCHTE40)

### Script in action

![](https://i.imgur.com/1ByFhHi.gif)
