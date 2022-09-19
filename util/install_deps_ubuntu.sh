#!/usr/bin/env bash
# Use: install_deps_ubuntu.sh [ assume-yes ]

set -ev

SUDO=${SUDO:=sudo} # SUDO=command in docker (running as root, sudo not available)
if [ "$1" == "assume-yes" ]; then
    APT_CONFIRM="--assume-yes"
else
    APT_CONFIRM=""
fi

deps=(
    # Open3D
    xorg-dev
    libxcb-shm0
    libglu1-mesa-dev
    python3-dev
    # Filament build-from-source
<<<<<<< HEAD
    libsdl2-dev
    libc++-10-dev
    libc++abi-10-dev
=======
    clang
    libc++-dev
    libc++abi-dev
    libsdl2-dev
>>>>>>> c074f5d00b5bdf37266f71a87125156b1087ac98
    ninja-build
    libxi-dev
    # OpenBLAS build-from-source deps
    gfortran
    libblas-dev
    liblapack-dev
    liblapacke-dev
    # ML deps
    libtbb-dev
    # Headless rendering
    libosmesa6-dev
    # RealSense
    libudev-dev
    autoconf
    libtool
)

eval $(
    source /etc/lsb-release;
    echo DISTRIB_ID="$DISTRIB_ID";
    echo DISTRIB_RELEASE="$DISTRIB_RELEASE"
)
if [ "$DISTRIB_ID" == "Ubuntu" -a "$DISTRIB_RELEASE" == "18.04" ]; then
    # Ubuntu 18.04's clang/libc++-dev/libc++abi-dev are version 6.
    # To build Filament from source, we need version 7+.
    deps=("${deps[@]/clang/clang-7}")
    deps=("${deps[@]/libc++-dev/libc++-7-dev}")
    deps=("${deps[@]/libc++abi-dev/libc++abi-7-dev}")
fi

# Special case for ARM64
if [ "$(uname -m)" == "aarch64" ]; then
    # For compling LAPACK in OpenBLAS
    deps+=("gfortran")
fi

echo "apt-get install ${deps[*]}"
$SUDO apt-get update
$SUDO apt-get install ${APT_CONFIRM} ${deps[*]}
