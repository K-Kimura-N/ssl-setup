#! /bin/bash

# Automatic setup script for RoboCup Small Size League
# K_Kimura / KIKS 2016-2018
# Released under the Unlicense
# http://unlicense.org/

set -Ceu

script_dir=$(cd $(dirname $0); pwd)

# $1 exit code that fails - use $?
# $2 error message you want to show. It will be shown using `echo`
function error_end {
    echo "[SSL-SETUP ERROR] $2"
    echo "[SSL-SETUP ERROR] process exits with code $1"
    echo "[SSL-SETUP ERROR] Installation incomplete."
    exit 1
}

function check_root {
    if [ "$(whoami)" != "root" ]; then
        error_end 1 "Please run as root!  (e.g. $ sudo bash ssl_autosetup.sh"
    fi
}

function get_os_distribution() {
    # Copyright (c) 2016 Kohei Arao
    # https://github.com/koara-local/dotfiles
    # Released under the Unlicense
    # http://unlicense.org/
    local distri_name

    if   [ -e /etc/debian_version ] ||
         [ -e /etc/debian_release ]; then
        # Check Ubuntu or Debian
        if [ -e /etc/lsb-release ]; then
            # Ubuntu
            distri_name="ubuntu"
        else
            # Debian
            distri_name="debian"
        fi
    elif [ -e /etc/fedora-release ]; then
        # Fedra
        distri_name="fedora"
    elif [ -e /etc/redhat-release ]; then
        if [ -e /etc/oracle-release ]; then
            # Oracle Linux
            distri_name="oracle"
        else
            # Red Hat Enterprise Linux
            distri_name="redhat"
        fi
    elif [ -e /etc/arch-release ]; then
        # Arch Linux
        distri_name="arch"
    elif [ -e /etc/turbolinux-release ]; then
        # Turbolinux
        distri_name="turbol"
    elif [ -e /etc/SuSE-release ]; then
        # SuSE Linux
        distri_name="suse"
    elif [ -e /etc/mandriva-release ]; then
        # Mandriva Linux
        distri_name="mandriva"
    elif [ -e /etc/vine-release ]; then
        # Vine Linux
        distri_name="vine"
    elif [ -e /etc/gentoo-release ]; then
        # Gentoo Linux
        distri_name="gentoo"
    else
        # Other
        echo "unkown distribution"
        distri_name="unkown"
    fi

    echo "$distri_name"
}

function install_ode_013() {
    wget https://jaist.dl.sourceforge.net/project/opende/ODE/0.13/ode-0.13.tar.bz2 || error_end $? "Failed to download ode-0.13.tar.bz2. Check your internet connection."
    tar xf ode-0.13.tar.bz2 && rm ode-0.13.tar.bz2
    cd ode-0.13
    ./configure --disable-demos --enable-double-precision || error_end $? "ODE configuration failed"
    make -s >/dev/null || error_end $? "Failed to build ode"
    make install || error_end $? "Failed to install ode from source"
    cd ../
}

function install_vartype() {
    # install "vartypes" that required by grSim
    git clone https://github.com/jpfeltracco/vartypes.git || error_end $? "Failed to clone vartypes"
    cd vartypes
    mkdir build && cd "$_"
    cmake .. && make -s >/dev/null || error_end $? "Failed to build vartypes"
    make install || error_end $? "Failed to install vartypes"
    cd ../
}

function install_opencv() {
    # install opencv (>= 3.0) from source
    wget https://github.com/opencv/opencv/archive/4.1.1.tar.gz || error_end $? "Failed to downlod opencv. Check internet connection."
    tar xf 4.1.1.tar.gz
    cd opencv*
    mkdir build && cd $_
    cmake .. -DCMAKE_CXX_COMPILER=g++ -DCMAKE_C_COMPILER=gcc -DBUILD_CUDA_STABS_=OFF -DBUILD_DOCS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_JASPER=OFF -DBUILD_OPENEXR=OFF -DBUILD_PACKAGE=ON -DBUILD_PERF=TESTS=OFF -DBUILD_SHARED=LIBS=ON -DBUILD_TBB=OFF -DBUILD_TESTS=OFF -DBUILD_WITH_DEBUG_INFO=ON -DBUILD_ZLIB=ON -DBUILD_openv_apps=ON -DBUILD_opencv_calib3d=ON-DBUILD_opencv_core=ON -DBUILD_opencv_world=OFF -DCMAKE_BUILD_TYPE=DEBUG -DWITH_1394=ON -DWITH_FFMPEG=ON -DWITH_JPEG=ON -DWITH_QT=ON -DWITH_V4L=ON  
    make
    make install || error_end $? "Failed to install OpenCV from source"
}

function install_libraries() {
    # temporary folder to build ODE, vartypes
    local path_tmp=/home/${SUDO_USER}/Documents/sslinst_tmp/

    # packages required to run this script
    local dnf_pkg_script="curl git cmake make gcc gcc-c++ jq xdg-utils"
    local dnf_pkg_grsim="mesa-libGL-devel mesa-libGLU-devel qt-devel protobuf-compiler protobuf-devel boost-devel"
    local dnf_pkg_ssl_vision="qt-devel eigen3 libjpeg libpng v4l-utils libdc1394 libdc1394-devel protobuf-compiler protobuf-devel opencv-devel freeglut-devel zlib"
    local dnf_pkg_ssl_logtools="protobuf-compiler zlib-devel boost-program-options"
    local dnf_pkg_ssl_autoref="patch"

    local pacman_pkg_script="curl git cmake make gcc jq wget xdg-utils"
    local pacman_pkg_grsim="mesa glu ode qt5-base protobuf boost"
    local pacman_pkg_ssl_vision="qt5-base eigen protobuf libdc1394 jsoncpp v4l-utils opencv"
    local pacman_pkg_ssl_logtools="protobuf zlib boost"
    local pacman_pkg_ssl_autoref="patch"

    local apt_pkg_script="curl git cmake make gcc jq wget xdg-utils"
    local apt_pkg_grsim="build-essential qt5-default libqt5opengl5-dev libgl1-mesa-dev libglu1-mesa-dev libprotobuf-dev protobuf-compiler libode-dev libboost-dev"
    local apt_pkg_ssl_vision="libqt4-dev libeigen3-dev protobuf-compiler libprotobuf-dev libdc1394-22 libdc1394-22-dev libv4l-0 libopencv-dev freeglut3-dev"
    local apt_pkg_ssl_logtools="libprotobuf-dev protobuf-compiler zlib1g-dev libboost-program-options-dev"
    local apt_pkg_ssl_autorefs="patch"
    local apt_pkg_opencv="build-essential libgtk2.0dev pkg-config libavcodec-dev libavformat-dev libswscale-dev libjpeg-dev libpng-dev libtiff-dev"

    if [ ! -e "$path_tmp" ]
    then
        mkdir -p "$path_tmp"
    fi
    cd "$path_tmp"

    DISTRIBU=$(get_os_distribution)
    echo "You're using $DISTRIBU"
    case "$DISTRIBU" in
        "fedora" )
            # update system
            dnf -y update || error_end $? "Failed to Update system. Check internet connection and Disk Space."

            # install most of required packages for Robocup-SSL official tools (without Autoref)
            dnf -y install ${dnf_pkg_script} ${dnf_pkg_grsim} ${dnf_pkg_ssl_vision} ${dnf_pkg_ssl_logtools} ${dnf_pkg_ssl_autoref} || error_end $? "Failed to instlal some packages."

            # in fedora, you have to build ODE-0.13 from source. new version of ODE will cause freeze of grSim
            install_ode_013
            ;;
        "ubuntu" )
            apt update -qq -y || error_end $? "Failed to update. Check your internet connection." 
            apt upgrade -qq -y || error_end $? "Failed to upgrade. Please try later (dpkg may still working)"
            
            # install most of required packages for Robocup-SSL official tools (without Autoref)
            apt-get -qq -y install ${apt_pkg_script} ${apt_pkg_grsim} ${apt_pkg_ssl_vision} ${apt_pkg_ssl_logtools} ${apt_pkg_ssl_autorefs} || error_end $? "Failed to install some packages"

            # if you're using ubuntu, you don't need to build ODE from source. Lucky you!
            # if you're using ubuntu 16.04LTS, you need to build opencv from source (apt package "libopencv-dev" is old to build ssl-vision)
            if [ $(cat /etc/os-release | grep VERSION_ID | sed -e "s:VERSION_ID=\"\([0-9]*.[0-9]*\)\":\1:g") == "16.04" ]; then
                apt-get -qq -y install ${apt_pkg_opencv} || error_end $? "Failed to install dependency for OpenCV."
                install_opencv
            fi;

            ;;
        "arch" )
            # update
            yes | pacman -Syyu || error_end $? "Failed to Update system. Check internet connection and Disk Space."

            pacman -S --noconfirm --needed base-devel  || error_end $? "Failed to install base-devel"

            # install most of required packages for Robocup-SSL official tools (without Autoref)
            yes | pacman -S ${pacman_pkg_script} ${pacman_pkg_grsim} ${pacman_pkg_ssl_vision} ${pacman_pkg_ssl_logtools} ${pacman_pkg_ssl_autoref} --needed || error_end $? "Failed to install some packages"

            install_ode_013
            ;;
        * )
            error_end 1 "The OS you using (${DISTRIBU}) is not supported."
            ;;
    esac

    # install libraries for ssl-autorefs
    curl https://raw.githubusercontent.com/RoboCup-SSL/ssl-autorefs/master/installDeps.sh > installDeps.sh
    (yes | bash installDeps.sh) || error_end $? "Failed to install dependency for ssl-autorefs.";

    if ! ls /usr/local/lib/*vartypes* > /dev/null; then
        install_vartype
    fi
    cd ${script_dir}
    rm -r ${path_tmp}
}

function build_ssl_tools() {
    local ssl_dir_default="/home/${USER}/Documents/robocup/tools"

    echo "Download and build RoboCup-SSL Tools"
    echo "grSim , ssl-vision , ssl-logtools , ssl-game-controller , ssl-vision-client"
    echo ""
    echo "Where do you want to place these application?"
    echo "(if you're a beginner, just press Enter)"
    echo -n "[${ssl_dir_default}] >"
    while :
    do
    read -r -t 60 SSL_DIR || if [ "$?" == "142" ] ; then echo " set to default..."; fi
    case $SSL_DIR in
        # if typed so it seems to be not problem, but can't do "git clone"
        "home/" | "home" | "/home" | "/home/" )
            echo "You Don't have permission to access. Please use /home/<username>/ or just type Enter.";;
        # other case
        * )
            # nothing typed
            if test -z "$SSL_DIR"
            then
                SSL_DIR=${ssl_dir_default};
            fi
            echo "install for $SSL_DIR."
            mkdir -p "$SSL_DIR" && cd "$_" && break
            
        ;;
    esac
    done

    # build grSim , ssl-vision , ssl-refbox , ssl-logtools
    git clone https://github.com/RoboCup-SSL/grSim.git || error_end $? "Failed to clone grSim"
    git clone https://github.com/RoboCup-SSL/ssl-vision.git || error_end $? "Failed to clone ssl-vision"
    git clone https://github.com/RoboCup-SSL/ssl-logtools.git || error_end $? "Failed to clone ssl-logtools"
    git clone https://github.com/RoboCup-SSL/ssl-autorefs.git --recursive|| error_end $? "Failed to clone ssl-autorefs"

    # grsim
    cd grSim && mkdir build && cd "$_"
    cmake .. && make || error_end $? "Failed to build grSim"

    # ssl-vision/graphicalClient
    cd ${SSL_DIR}/ssl-vision && mkdir build && cd "$_"
    cmake .. -DUSE_QT5=true || error_end $? "cmake configuration for ssl-vision failed"
    make || error_end $? "Failed to build ssl-vision"

    # ssl-logtools
    cd ${SSL_DIR}/ssl-logtools && mkdir build && cd "$_"
    cmake .. -DUSE_QT5=true || error_end $? "cmake configuration for ssl-logtools failed"
    make || error_end $? "Failed to build ssl-logtools"

    cd ${SSL_DIR}/ssl-autorefs
    bash buildAll.sh

    # new ssl client (ssl-game-controller and so on)
    cd ${SSL_DIR}
    mkdir games && cd $_
    wget `curl -s https://api.github.com/repos/robocup-ssl/ssl-game-controller/releases | jq -r '.[0].assets[] | select(.name | test("linux_amd64")) | .browser_download_url'` || error_end $? "Failed to download ssl-game-controller."
    wget `curl -s https://api.github.com/repos/robocup-ssl/ssl-vision-client/releases | jq -r '.[0].assets[] | select(.name | test("linux_amd64")) | .browser_download_url'` || error_end $? "Failed to download ssl-vision-client."
    chmod +x ssl*
}

function install_dev_tools() {
    local ins_tools
    echo ""
    echo "Do you want to install these usefull tools :"
    echo "vim - Text/Code Editor"
    echo "wireshark - network protocol analyzer"
    echo "htop - performance analyzer"
    echo "strace & ltrace - debug tools"
    echo -n "[Y/n]:"

    read -r -t 60 ins_tools || if [ "$?" == "142" ] ; then echo " set to default..."; fi
    case "$ins_tools" in
        "" | "y" | "Y" | "yes" | "Yes" | "YES" )
            case "$DISTRIBU" in
                "fedora" )
                    dnf -y install htop wireshark strace ltrace vim || error_end $? "Failed to install useful tools."
                    ;;
                "ubuntu" )
                    apt-get -qq -y install htop wireshark strace ltrace vim || error_end $? "Failed to install useful tools."
                    ;;
                "arch" )
                    yes | pacman -S htop wireshark-cli strace ltrace vim || error_end $? "Failed to install useful tools."
                    ;;
                * )
                    echo "Not supported.";
                    exit
                ;;
            esac
            su ${SUDO_USER} -c "xdg-open https://qiita.com/mfujimori/items/9fd41bcd8d1ce9170301 &"
            ;;
        * )
            echo "Didn't install these tools."
            ;;
    esac
}


# Script start from here
flag_build="--rec_to_build"

if [ $# -lt 1 ]; then
    echo "This installer will setup the tools for RoboCup-SSL in your computer."

    check_root
    install_libraries
    su ${SUDO_USER} -c "cd ${script_dir}; bash ssl_autosetup.sh ${flag_build}"
    install_dev_tools

    echo ""
    echo "Done."
elif [ $1 == ${flag_build} ]; then
    if [ ${USER} == "root" ]; then
        error_end 1 "invalid usage detected. please try again with no argment"
    else
        build_ssl_tools
    fi
else
    error_end 1 "invalid argment"
fi
