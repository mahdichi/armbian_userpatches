#!/bin/sh

#https://docs.armbian.com/Developer-Guide_Build-Options/

ARMBIAN_BUILD_PATH=/media/ma/fx/armbian/armbian-build
DOCKER_OFFLINE_PATH=$ARMBIAN_BUILD_PATH/userpatches/overlay/docker_offline/
########################################################
Main() {
	DockerOffline;
	#ArmbianCompileServer;
} # Main
########################################################
ArmbianCompileServer()
{
	$ARMBIAN_BUILD_PATH/compile.sh \
	BOARD=fxblox-rk1 \
	BRANCH=legacy \
	RELEASE=jammy \
	BUILD_DESKTOP=no \
	BUILD_MINIMAL=yes \
	KERNEL_CONFIGURE=no \
	KERNEL_GIT=shallow \
	CONSOLE_AUTOLOGIN=yes \
	EXPERT="yes" \
	CLEAN_LEVEL=oldcache \
	PACKAGE_LIST_BOARD="\
	cmake libi2c-dev \
	gdb git gcc net-tools rfkill bluetooth bluez bluez-tools blueman \
	logrotate python3-pip mergerfs inotify-tools python3-dbus dnsmasq-base \
	python3-dev python-is-python3 python3-pip python3-gi python3-gi-cairo gir1.2-gtk-3.0 dnsmasq-base lshw  \
	debhelper build-essential ntfs-3g fakeroot lockfile-progs \
	libip6tc2 libnftnl11 iptables \
	" \
	#usbmount: ebhelper build-essential ntfs-3g fakeroot lockfile-progs
	#docker:   libip6tc2 libnftnl11 iptables
	#fula: logrotate
} # ArmbianCompile
########################################################
DockerOffline()
{
	docker save functionland/node:release -o $DOCKER_OFFLINE_PATH/node_release.tar
	docker save functionland/go-fula:release -o $DOCKER_OFFLINE_PATH/go_fula_release.tar
	docker save functionland/fxsupport:release -o $DOCKER_OFFLINE_PATH/fxsupport_release.tar
} # DockerOffline
########################################################

Main "$@"
