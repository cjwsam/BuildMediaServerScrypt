#!/bin/bash
# yeaaaaaa i did this enjoy :) 

CWD=$(pwd)
PACKAGES="$CWD/packages"
WORKSPACE="$CWD/workspace"
LOG="$CWD/log"
CC=clang
DISTO=$(uname -m)
DOCKERTYPE="latest"
OS=$((awk -F= '/^NAME/{print $2}' /etc/os-release) | tr -d '"')
LDFLAGS="-L${WORKSPACE}/lib -lm"
CFLAGS="-I${WORKSPACE}/include"
PKG_CONFIG_PATH="${WORKSPACE}/lib/pkgconfig"
ADDITIONAL_CONFIGURE_OPTIONS=""


################################################################################################

if [ $DISTO == "x86_64" ]; then 
DISTO="amd64"
fi

if [ $DISTO == "aarch64" ]; then 
DISTO="arm64"
DOCKERTYPE="arm64v8-latest"
fi

if [ $DISTO == "armv7l" ]; then 
DISTO="armhf"
DOCKERTYPE="arm32v7-latest"
fi

if [ $OS == "Ubuntu" ]; then 
OS="ubuntu"
fi

if [ $OS == "Debian"* ]; then 
OS="debian"
fi

if [[ $UID != 0 ]]; then
    echo "Please run this script with sudo:"
    echo "sudo $0 $*"
    exit 1
fi

# Progress bar function
prog() {
    local w=50 p=$1;  shift
    printf -v dots "%*s" "$(( $p*$w/100 ))" ""; dots=${dots// /#};
    printf "\r\e[K|%-*s| %3d %% %s" "$w" "$dots" "$p" "$*";
}

# Speed up the process
# Env Var NUMJOBS overrides automatic detection
if [[ -n $NUMJOBS ]]; then
    MJOBS=$NUMJOBS
elif [[ -f /proc/cpuinfo ]]; then
    MJOBS=$(grep -c processor /proc/cpuinfo)
elif [[ "$OSTYPE" == "darwin"* ]]; then
	MJOBS=$(sysctl -n machdep.cpu.thread_count)
	ADDITIONAL_CONFIGURE_OPTIONS="--enable-videotoolbox"
else
    MJOBS=4
fi

make_dir () {
	if [ ! -d $1 ]; then
		if ! mkdir $1; then
			printf "\n Failed to create dir %s" "$1";
			exit 1
		fi
	fi
}

remove_dir () {
	if [ -d $1 ]; then
		rm -r "$1"
	fi
}

download () {

	DOWNLOAD_PATH=$PACKAGES;

	if [ ! -z "$3" ]; then
		mkdir -p $PACKAGES/$3
		DOWNLOAD_PATH=$PACKAGES/$3
	fi;

	if [ ! -f "$DOWNLOAD_PATH/$2" ]; then

		echo "Downloading $1"
		curl -L --silent -o "$DOWNLOAD_PATH/$2" "$1"

		EXITCODE=$?
		if [ $EXITCODE -ne 0 ]; then
			echo ""
			echo "Failed to download $1. Exitcode $EXITCODE. Retrying in 10 seconds";
			sleep 10
			curl -L --silent -o "$DOWNLOAD_PATH/$2" "$1"
		fi

		EXITCODE=$?
		if [ $EXITCODE -ne 0 ]; then
			echo ""
			echo "Failed to download $1. Exitcode $EXITCODE";
			exit 1
		fi

		echo "... Done"

		if ! tar -xvf "$DOWNLOAD_PATH/$2" -C "$DOWNLOAD_PATH" 2>/dev/null >/dev/null; then
			echo "Failed to extract $2";
			exit 1
		fi

	fi
}

execute () {
	echo "$ $*"

	OUTPUT=$($@ 2>&1)

	if [ $? -ne 0 ]; then
        echo "$OUTPUT"
        echo ""
        echo "Failed to Execute $*" >&2
        exit 1
    fi
}

build () {
	echo ""
	echo "building $1"
	echo "======================="

	if [ -f "$PACKAGES/$1.done" ]; then
		echo "$1 already built. Remove $PACKAGES/$1.done lockfile to rebuild it."
		return 1
	fi

	return 0
}

command_exists() {
    if ! [[ -x $(command -v "$1") ]]; then
        return 1
    fi

    return 0
}


build_done () {
	touch "$PACKAGES/$1.done"
}

echo -e "++ Scrypt Processing ++\n--------------------------------\n"
echo "Building Server  - please be patient..."

case "$1" in
"--cleanup")
	remove_dir $PACKAGES
	remove_dir $WORKSPACE
	echo "Cleanup done."
	echo ""
	exit 0
    ;;
"--build")

    ;;
*)
    echo "Usage: $0"
    echo "   --build: start building "
    echo "   --cleanup: remove all working dirs"
    echo "   --help: thoughts and prayer"
    echo ""
    exit 0
    ;;
esac

echo "Using $MJOBS  Cores to build jobs simultaneously."


make_dir $PACKAGES
make_dir $WORKSPACE
make_dir $LOG
 
export PATH=${WORKSPACE}/bin:$PATH

if ! command_exists "make"; then
    echo "make not installed, INSTALLING.";
			execute apt install make -y 
    exit 1
fi

if ! command_exists "g++"; then
    echo "g++ not installed, INSTALLING .";
		execute apt install build-essential -y 

    exit 1
fi

if ! command_exists "curl"; then
    echo "curl not installed, INSTALLING.";
	execute apt install curl -y 
    exit 1
fi

if ! command_exists "wget"; then
    echo "wget not installed, INSTALLING.";
		execute apt install wget -y 
    exit 1
fi

if build "DOCKER"; then

echo "installing Docker."

 execute apt-get install  -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
	  
curl -fsSL https://download.docker.com/linux/$OS/gpg | apt-key add - 

  echo "deb [arch=$DISTO] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee -a /etc/apt/sources.list

  execute apt-get update

  execute apt-get install docker-ce docker-ce-cli containerd.io -y

echo "DONE, Intalling Docker."
echo " ";				
fi

if build "Portainer"; then

echo "installing PORTAINER."

execute docker volume create portainer_data
execute docker run --name portainer -d --restart=always -p 8000:8000 -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock -v portainer_data:/data portainer/portainer

echo "DONE, Intalling Portainer YOU CAN ACCESS IT ON *IP* :9000."
echo " ";

fi

if build "Sonarr"; then

echo "installing Sonarr."

execute docker pull linuxserver/sonarr:$DOCKERTYPE 
execute docker run --name Sonarr -d --restart=always -p 8989:8989 -v /nas:/nas linuxserver/sonarr

echo "DONE, Intalling Sonarr YOU CAN ACCESS IT ON *IP* :8989."
echo " ";

fi
if build "Radarr"; then

echo "installing Radarr."

execute docker pull linuxserver/radarr:$DOCKERTYPE 
execute docker run --name radarr -d --restart=always -p 7878:7878 -v /nas:/nas linuxserver/radarr

echo "DONE, Intalling Radarr YOU CAN ACCESS IT ON *IP* :7878."
echo " ";

fi

if build "Tautulli"; then

echo "installing Tautulli."

execute docker pull linuxserver/tautulli:$DOCKERTYPE 
execute docker run --name tautulli -d --restart=always -p 8181:8181 -v /nas:/nas linuxserver/tautulli

echo "DONE, Intalling Tautulli YOU CAN ACCESS IT ON *IP* :8181."
echo " ";

fi

if build "Transmission"; then
echo "installing Transmission-Daemon."

execute apt install transmission-daemon
execute service transmission-daemon stop
execute rm /etc/transmission-daemon/settings.json
execute curl -o /etc/transmission-daemon/settings.json https://raw.githubusercontent.com/cjwsam/BuildMediaServerScrypt/master/settings.json 
execute chmod 0777 /etc/transmission-daemon/settings.json
execute service transmission-daemon start   

echo "DONE, Installing Transmission YOU CAN ACCESS IT ON *IP* :8181."
echo " ";

fi

if build "Monitorix"; then
echo "installing Monitorix."

execute wget https://www.monitorix.org/monitorix_3.11.0-izzy1_all.deb
 dpkg -i monitorix_3.11.0-izzy1_all.deb
execute apt install -f -y 
execute service monitorix stop
execute rm /etc/monitorix/monitorix.conf
execute curl -o /etc/monitorix/monitorix.conf https://raw.githubusercontent.com/cjwsam/BuildMediaServerScrypt/master/monitorix.conf
execute chmod 0777 /etc/monitorix/monitorix.conf
execute service monitorix start   


echo "DONE, Installing Monitorix YOU CAN ACCESS IT ON *IP* :9999."
echo " ";

fi

echo "installing FFMPEG."

execute apt install ffmpeg -y

echo "DONE, Installing FFMPEG."
echo " DONEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE ";





