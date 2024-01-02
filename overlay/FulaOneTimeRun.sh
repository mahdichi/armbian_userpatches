#!/bin/bash


if [ -f /root/.FulaOneTimeRun ]; then
    echo "Fula Run One Time "

	#fix pi access to home/root
	mkdir -p /home/pi/
	chown -R pi:pi /home/pi/

	#docker
	groupadd docker
	usermod -aG docker pi
	newgrp docker

	#disable resize rootfs
	touch /usr/bin/fula/.resize_flg

	#
	chown -R pi:pi /home/pi/fula-ota
	cd /home/pi/fula-ota/fula
	bash ./fula.sh install
	#bash ./fula.sh start

	rm /root/.FulaOneTimeRun

fi
