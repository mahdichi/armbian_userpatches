#!/bin/bash

HOME_DIR=/home/pi
FULA_OTA_HOME="$HOME_DIR/fula-ota"
########################################################
updateFulaOtaRepo()
{
	echo "update Fula OTA Repo"

	if [ ! -d $FULA_OTA_HOME ]; then
  		echo "fula-ota does not exist."
		echo "clone fula-ota repo"
			git clone https://github.com/functionland/fula-ota $FULA_OTA_HOME
	else
		echo "update fula-ota repo"
		cd $FULA_OTA_HOME
		git pull
	fi

} # updateFulaOtaRepo
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

	updateFulaOtaRepo;

	#
	chown -R pi:pi $FULA_OTA_HOME
	cd $FULA_OTA_HOME/fula
	bash ./fula.sh install

	rm /root/.FulaOtaInstall1
	touch /root/.FulaOtaInstall2

fi



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
