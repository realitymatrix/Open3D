#!/usr/bin/env bash
set -euox pipefail

# This script builds WebRTC for Open3D for Ubuntu and macOS. For Windows, see
# .github/workflows/webrtc.yml
#
# Usage:
# $ bash # Start a new shell
# Specify custom configuration by exporting environment variables
# GLIBCXX_USE_CXX11_ABI, WEBRTC_COMMIT and DEPOT_TOOLS_COMMIT, if required.
# $ source 3rdparty/webrtc/webrtc_build.sh
# $ install_dependencies_ubuntu   # Ubuntu only
# $ download_webrtc_sources
# $ build_webrtc
# A webrtc_<commit>_platform.tar.gz file will be created that can be used to
# build Open3D with WebRTC support.
#
# Procedure:
#
# 1) Download depot_tools, webrtc to following directories:
#    ├── Oepn3D
#    ├── depot_tools
#    └── webrtc
#        ├── .gclient
#        └── src
#
# 2) depot_tools and webrtc have compatible versions, see:
#    https://chromium.googlesource.com/chromium/src/+/master/docs/building_old_revisions.md
#
# 3) Apply the following patch to enable GLIBCXX_USE_CXX11_ABI selection:
#    - 0001-build-enable-rtc_use_cxx11_abi-option.patch        # apply to webrtc/src
#    - 0001-src-enable-rtc_use_cxx11_abi-option.patch          # apply to webrtc/src/build
#    - 0001-third_party-enable-rtc_use_cxx11_abi-option.patch  # apply to webrtc/src/third_party
#    Note that these patches may or may not be compatible with your custom
#    WebRTC commits. You may have to patch them manually.

# WEBRTC_COMMIT
WEBRTC_COMMIT=${WEBRTC_COMMIT:-5f5bdf18806d20f7ea9f7a4b5331015c374d0bfc}
# CXX ABI
GLIBCXX_USE_CXX11_ABI=${GLIBCXX_USE_CXX11_ABI:-1}

NPROC=${NPROC:-$(getconf _NPROCESSORS_ONLN)} # POSIX: MacOS + Linux
SUDO=${SUDO:-sudo}                           # Set to command if running inside docker

export DEPOT_TOOLS="/depot_tools"
export PATH=${DEPOT_TOOLS}:${PATH}
export PATH="/depot_tools/python-bin/python3":${PATH}
export PATH="/depot_tools/python2-bin/python2":${PATH}
export PATH="/depot_tools/vpython":${PATH}
export PATH="/depot_tools/vpython3":${PATH}
export DEPOT_TOOLS_UPDATE=0
export GCLIENT_PY3=1

install_dependencies_ubuntu() {
    options="$(echo "$@" | tr ' ' '|')"
    # Dependencies
    # python*       : resolve ImportError: No module named pkg_resources
    # libglib2.0-dev: resolve pkg_config("glib")
    $SUDO apt-get update
    $SUDO apt-get install -y \
        apt-transport-https \
        build-essential \
        ca-certificates \
        git \
        gnupg \
        libglib2.0-dev \
        python \
        python-pip \
        python-setuptools \
        python-wheel \
        software-properties-common \
        tree \
        curl \
        wget
    curl https://apt.kitware.com/keys/kitware-archive-latest.asc \
        2>/dev/null | gpg --dearmor - |
        $SUDO sed -n 'w /etc/apt/trusted.gpg.d/kitware.gpg' # Write to file, no stdout
    source <(grep VERSION_CODENAME /etc/os-release)
    $SUDO apt-add-repository --yes "deb https://apt.kitware.com/ubuntu/ $VERSION_CODENAME main"
    $SUDO apt-get update
    $SUDO apt-get --yes install cmake
    cmake --version >/dev/null
    if [[ "purge-cache" =~ ^($options)$ ]]; then
        $SUDO apt-get clean
        $SUDO rm -rf /var/lib/apt/lists/*
    fi

    wget https://github.com/llvm/llvm-project/releases/download/llvmorg-12.0.1/clang+llvm-12.0.1-aarch64-linux-gnu.tar.xz
    tar -xf clang+llvm-12.0.1-aarch64-linux-gnu.tar.xz
    export PATH="/clang+llvm-12.0.1-aarch64-linux-gnu/bin":${PATH}

    echo ${PATH}
}

download_webrtc_sources() {
    # PWD=Open3D
    pushd ..
    echo Get depot_tools
    git clone https://github.com/realitymatrix/depot_tools.git
    chmod 755 /depot_tools/gclient
    chmod 755 /depot_tools/fetch
    chmod 755 /depot_tools/vpython
    chmod 755 /depot_tools/vpython3
    chmod 755 /depot_tools/cipd
    chmod 755 /depot_tools/download_from_google_storage
    chmod 755 /depot_tools/gn
    chmod 755 /depot_tools/ninja
    vpython3 --version
    vpython3 -m pip install \
     httplib2 \
     six

    echo Get WebRTC
    mkdir webrtc
    cd webrtc
    fetch --nohooks webrtc

    # Checkout to a specific version
    # Ref: https://chromium.googlesource.com/chromium/src/+/master/docs/building_old_revisions.md
    git -C src checkout $WEBRTC_COMMIT
    git -C src submodule update --init --recursive
    echo gclient sync
    gclient sync -D --force --reset
    cd ..
    echo random.org
    curl "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" -o skipcache
    popd
    cd /webrtc/src/third_party/libyuv
    git checkout 966768
    #git pull origin master
    cd /webrtc/src
    python3 ./build/linux/sysroot_scripts/install-sysroot.py --arch=arm64
    cd /Open3D
}

build_webrtc() {
    # PWD=Open3D
    OPEN3D_DIR="$PWD"
    #echo Apply patches
    cp 3rdparty/webrtc/{CMakeLists.txt,webrtc_common.cmake} ../webrtc
    #git -C ../webrtc/src apply \
    #    "$OPEN3D_DIR"/3rdparty/webrtc/0001-src-enable-rtc_use_cxx11_abi-option.patch
    #git -C ../webrtc/src/build apply \
    #    "$OPEN3D_DIR"/3rdparty/webrtc/0001-build-enable-rtc_use_cxx11_abi-option.patch
    #git -C ../webrtc/src/third_party apply \
    #    "$OPEN3D_DIR"/3rdparty/webrtc/0001-third_party-enable-rtc_use_cxx11_abi-option.patch
    WEBRTC_COMMIT_SHORT=$(git -C ../webrtc/src rev-parse --short=7 HEAD)

    echo Build WebRTC
    cd /webrtc/src
    gn gen ../../webrtc_release --args='is_debug=false enable_iterator_debugging=false treat_warnings_as_errors=false rtc_include_tests=false target_os="linux" target_cpu="arm64" is_clang=true libyuv_use_neon=false '
    cd /webrtc_release
    ninja -C . -j8
    #mkdir ../webrtc/build
    #pushd ../webrtc/build
    #cmake -DCMAKE_INSTALL_PREFIX=../../webrtc_release .. \
    #    -DGLIBCXX_USE_CXX11_ABI=${GLIBCXX_USE_CXX11_ABI} \
    #    -DCMAKE_CXX_COMPILER=clang++ \
    #    -DCMAKE_BUILD_TYPE=Release \
    #    ..
    #make -j$NPROC
    #make install
    #popd # PWD=Open3D
    pushd ..
    tree -L 2 webrtc_release || ls webrtc_release/*

    echo Package WebRTC
    if [[ $(uname -s) == 'Linux' ]]; then
        tar -czf \
            "$OPEN3D_DIR/webrtc_${WEBRTC_COMMIT_SHORT}_linux_cxx-abi-${GLIBCXX_USE_CXX11_ABI}.tar.gz" \
            webrtc_release
    elif [[ $(uname -s) == 'Darwin' ]]; then
        tar -czf \
            "$OPEN3D_DIR/webrtc_${WEBRTC_COMMIT_SHORT}_macos.tar.gz" \
            webrtc_release
    fi
    popd # PWD=Open3D
    webrtc_package=$(ls webrtc_*.tar.gz)
    cmake -E sha256sum "$webrtc_package" | tee "checksum_${webrtc_package%%.*}.txt"
    ls -alh "$webrtc_package"
}
