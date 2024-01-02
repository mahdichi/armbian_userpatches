#!/bin/bash

HOME_DIR=/home/pi
FULA_OTA_HOME="$HOME_DIR/fula-ota"

WIFI_SC=$FULA_OTA_HOME/fula-ota/wifi.sh

########################################################
updateFulaOtaRepo()
{
	echo "update Fula OTA Repo"

	if [ ! -d $FULA_OTA_HOME ]; then
  		echo "fula-ota does not exist."
		echo "clone fula-ota repo"
		ping google.com -c 4
		git clone https://github.com/functionland/fula-ota $FULA_OTA_HOME
	else
		cd $FULA_OTA_HOME
		git pull
	fi

} # updateFulaOtaRepo
########################################################
check_internet()
{
  wget -q --spider --timeout=10 https://hub.docker.com
  return $?   # Return the status directly, no need for if/else.
} # check_internet
########################################################
connectwifi()
{
  echo "Check internet connection and setup WiFi if needed"
  if [ -f "$WIFI_SC" ]; then
	chmod +x $WIFI_SC
    if ! check_internet; then
      echo "connectwifi: Waiting for Wi-Fi adapter to be ready..."
      sleep 15
      bash $WIFI_SC 2>&1 || echo "Wifi setup failed"
      sleep 15
    else
      echo "connectwifi: Already has internet..."
    fi
  fi
} # connectwifi
########################################################
if [ -f /root/.FulaOtaInstall1 ]; then
    echo "Fula OTA install phase 1 "

	#fix pi access to home/root
	mkdir -p $HOME_DIR
	chown -R pi:pi $HOME_DIR

	#docker
	groupadd docker
	usermod -aG docker pi
	newgrp docker

	#disable resize rootfs
	touch /usr/bin/fula/.resize_flg

	nmcli device wifi connect 'ASUS' password '123456'
	echo "nameserver 178.22.122.100" > /etc/resolv.conf
	sleep 5

	#connectwifi;
	sleep 5
	updateFulaOtaRepo;

	chown -R pi:pi $FULA_OTA_HOME
	cd $FULA_OTA_HOME/fula
	bash ./fula.sh install
	rm /root/.FulaOtaInstall1
	touch /root/.FulaOtaInstall2
fi

nmcli device wifi connect 'ASUS' password '123456'
echo "nameserver 178.22.122.100" > /etc/resolv.conf
sleep 5
#connectwifi;
sleep 5
updateFulaOtaRepo;


docker ps | grep fula_updater 1>2
if [  $? -eq 0 ]; then
    echo "Fula OTA install ok"
else
    echo "Fula OTA install error"
	cd $FULA_OTA_HOME/fula
	bash ./fula.sh install
	sleep 10
	reboot
fi

########################################################
