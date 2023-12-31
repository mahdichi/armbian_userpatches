#!/bin/bash


if [ -f /root/.FulaOneTimeRun ]; then
    echo "Fula Run One Time "

	#docker
	groupadd docker
	usermod -aG docker pi
	newgrp docker

	rm /root/.FulaOneTimeRun

	sleep 10
	reboot
fi
