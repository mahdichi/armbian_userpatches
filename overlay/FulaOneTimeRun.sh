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

	#connect to wifi
	sudo nmcli device wifi connect 'ASUS' password '12345678'

	#change dns for
	cp cp /etc/resolv.conf cp /etc/resolv.conf.back
	touch cp /etc/resolv.conf
	echo "nameserver 1.2.3.4" > /etc/resolv.conf

	#
	#chown -R pi:pi /home/pi/fula-ota
	#cd /home/pi/fula-ota/fula
	#bash ./fula.sh install
	#bash ./fula.sh start

	rm /root/.FulaOneTimeRun

	#sleep 10
	#reboot
fi
