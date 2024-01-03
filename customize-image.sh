#!/bin/bash

# arguments: $RELEASE $LINUXFAMILY $BOARD $BUILD_DESKTOP
#
# This is the image customization script

# NOTE: It is copied to /tmp directory inside the image
# and executed there inside chroot environment
# so don't reference any files that are not already installed

# NOTE: If you want to transfer files between chroot and host
# userpatches/overlay directory on host is bind-mounted to /tmp/overlay in chroot
# The sd card's root path is accessible via $SDCARD variable.

RELEASE=$1
LINUXFAMILY=$2
BOARD=$3
BUILD_DESKTOP=$4

Main() {
	case $RELEASE in
		stretch)
			# your code here
			# InstallOpenMediaVault # uncomment to get an OMV 4 image
			;;
		buster)
			# your code here
			;;
		bullseye)
			# your code here
			;;
		bionic)
			# your code here
			;;
		focal)
			# your code here
			;;
		jammy)
			Install;
			;;
	esac
} # Main

Install()
{
	if [ "${BOARD}" = "fxblox-rk1" ]; then
		fxBloxCustomScript;
	fi
} # Install

fxBloxCustomScript()
{
	echo "fxBlox Custom Script"

	#fix blutooth frimware loading error
	echo "fix blutooth"
	ln -s /lib/firmware/rtl8852bu_config /lib/firmware/rtl_bt/rtl8852bu_config.bin
	ln -s /lib/firmware/rtl8852bu_fw /lib/firmware/rtl_bt/rtl8852bu_fw.bin

	CreatUser;

	Automount;

	InstallpythonPackages;

	InstallDocker;

	InstallFulaOTA;

	#InstallFulaOTAService;

} # fxBloxCustomScript

CreatUser()
{
	echo "Creat User"

	rm /root/.not_logged_in_yet
	export LANG=C LC_ALL="en_US.UTF-8"

	# set root password
	password="pi"
	(
	echo "$password"
	echo "$password"
	) | passwd root > /dev/null 2>&1


	# set shell
	USER_SHELL="bash"
	SHELL_PATH=$(grep "/$USER_SHELL$" /etc/shells | tail -1)
	chsh -s "$(grep -iF "/$USER_SHELL" /etc/shells | tail -1)"
	sed -i "s|^SHELL=.*|SHELL=${SHELL_PATH}|" /etc/default/useradd
	sed -i "s|^DSHELL=.*|DSHELL=${SHELL_PATH}|" /etc/adduser.conf

	# create user
	RealUserName="pi"
	RealName="pi"
	password="pi"

	adduser --quiet --disabled-password --home /home/"$RealUserName" --gecos "$RealName" "$RealUserName"
	(
		echo "$password"
		echo "$password"
	) | passwd "$RealUserName" > /dev/null 2>&1

	mkdir -p /home/pi/
	#chown -R "$RealUserName":"$RealUserName" /home/pi/

	for additionalgroup in sudo netdev audio video disk tty users games dialout plugdev input bluetooth systemd-journal ssh; do
		usermod -aG "${additionalgroup}" "${RealUserName}" 2> /dev/null
	done

	# fix for gksu in Xenial
	touch /home/"$RealUserName"/.Xauthority
	chown "$RealUserName":"$RealUserName" /home/"$RealUserName"/.Xauthority
	RealName="$(awk -F":" "/^${RealUserName}:/ {print \$5}" < /etc/passwd | cut -d',' -f1)"
	[ -z "$RealName" ] && RealName="$RealUserName"
	#echo -e "\nDear \e[0;92m${RealName}\x1B[0m, your account \e[0;92m${RealUserName}\x1B[0m has been created and is sudo enabled."
	#echo -e "Please use this account for your daily work from now on.\n"
	rm -f /root/.not_logged_in_yet
	chmod +x /etc/update-motd.d/*
	# set up profile sync daemon on desktop systems
	if command -v psd > /dev/null 2>&1; then
		echo -e "${RealUserName} ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper" >> /etc/sudoers
		touch /home/"${RealUserName}"/.activate_psd
		chown "$RealUserName":"$RealUserName" /home/"${RealUserName}"/.activate_psd
	fi
} # CreatUser

Automount()
{
	echo "install Automount"

	# touch /usr/local/bin/automount.sh
	# chmod +x /usr/local/bin/automount.sh
	# cat > /usr/local/bin/automount.sh <<- EOF
    # #!/bin/bash

    # MOUNTPOINT="/media/pi"
    # DEVICE="/dev/$1"
    # MOUNTNAME=$(echo $1 | sed 's/[^a-zA-Z0-9]//g')
    # mkdir -p ${MOUNTPOINT}/${MOUNTNAME}

    # # Determine filesystem type
    # FSTYPE=$(blkid -o value -s TYPE ${DEVICE})

    # if [ ${FSTYPE} = "ntfs" ]; then
    #   # If filesystem is NTFS
    #   # uid and gid specify the owner and the group of files.
    #   # dmask and fmask control the permissions for directories and files. 0000 gives everyone read and write access.
    #   mount -t ntfs -o uid=pi,gid=pi,dmask=0000,fmask=0000 ${DEVICE} ${MOUNTPOINT}/${MOUNTNAME}
    # elif [ ${FSTYPE} = "vfat" ]; then
    #   # If filesystem is FAT32
    #   mount -t vfat -o uid=pi,gid=pi,dmask=0000,fmask=0000 ${DEVICE} ${MOUNTPOINT}/${MOUNTNAME}
    # else
    #   # For other filesystem types
    #   mount ${DEVICE} ${MOUNTPOINT}/${MOUNTNAME}
    #   # Changing owner for non-NTFS and non-FAT32 filesystems
    #   chown pi:pi ${MOUNTPOINT}/${MOUNTNAME}
    # fi
	# EOF


	# touch /etc/udev/rules.d/99-automount.rules
	# cat > /etc/udev/rules.d/99-automount.rules <<- EOF
	# ACTION=="add", KERNEL=="sd[a-z][0-9]", TAG+="systemd", ENV{SYSTEMD_WANTS}="automount@%k.service"
	# ACTION=="add", KERNEL=="nvme[0-9]n[0-9]p[0-9]", TAG+="systemd", ENV{SYSTEMD_WANTS}="automount@%k.service"

	# ACTION=="remove", KERNEL=="sd[a-z][0-9]", RUN+="/bin/systemctl stop automount@%k.service"
	# ACTION=="remove", KERNEL=="nvme[0-9]n[0-9]p[0-9]", RUN+="/bin/systemctl stop automount@%k.service"
	# EOF


	# touch /etc/systemd/system/automount@.service
	# cat > /etc/systemd/system/automount@.service <<- EOF
	# [Unit]
	# Description=Automount disks
	# BindsTo=dev-%i.device
	# After=dev-%i.device

	# [Service]
	# Type=oneshot
	# RemainAfterExit=yes
	# ExecStart=/usr/local/bin/automount.sh %I
	# ExecStop=/usr/bin/sh -c '/bin/umount /media/pi/$(echo %I | sed 's/[^a-zA-Z0-9]//g'); /bin/rmdir /media/pi/$(echo %I | sed 's/[^a-zA-Z0-9]//g')'
	# EOF
	# udevadm control --reload-rules
	# systemctl enable automount@.service


	#https://gist.github.com/zebrajaeger/168341df88abb6caaea5a029a2117925

	apt install /tmp/overlay/usbmount_0.0.24_all.deb

	mkdir /etc/systemd/system/systemd-udevd.service.d
	touch /etc/systemd/system/systemd-udevd.service.d/00-my-custom-mountflags.conf
	cat > /etc/systemd/system/systemd-udevd.service.d/00-my-custom-mountflags.conf <<- EOF
	[Service]
	PrivateMounts=no
	EOF

	#systemctl daemon-reexec
	#service systemd-udevd restart

} # Automount

InstallpythonPackages()
{
	echo "Install python Packages"

	pip install RPi.GPIO
	pip install pexpect
	pip install psutil
} # InstallpythonPackages

InstallDocker()
{
	echo "installing docker"

	apt install /tmp/overlay/docker/*.deb

	#Install Docker Compose 1.29.2
	echo "Docker Compose"
	# curl -L "https://github.com/docker/compose/releases/download/v2.16.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
	cp /tmp/overlay/docker/docker-compose /usr/local/bin/docker-compose
	chmod +x /usr/local/bin/docker-compose
	ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

} # InstallDocker

InstallFulaOTAService()
{
	echo "install Fula OTA install Service"

	touch /root/.FulaOtaInstall1
	cp /tmp/overlay/FulaOtaInstall.sh /usr/bin/FulaOtaInstall.sh
	chmod +x /usr/bin/FulaOtaInstall.sh

	touch /etc/systemd/system/FulaOtaInstall.service

	cat > /etc/systemd/system/FulaOtaInstall.service <<- EOF
	[Unit]
	Description=FulaOtaInstall service
	After=multi-user.target

	[Service]
	ExecStart=/bin/bash /usr/bin/FulaOtaInstall.sh
	Type=simple

	[Install]
	WantedBy=multi-user.target
	EOF
	systemctl --no-reload enable FulaOtaInstall.service

} # InstallFulaOTAService

InstallFulaOTA()
{
	echo "Install Fula OTA"

	#git clone -b auto-image https://github.com/functionland/fula-ota /home/pi/fula-ota
	git clone -b mahdichi-auto-image-patch  https://github.com/mahdichi/fula-ota /home/pi/fula-ota

	#copy offline docker
	mkdir -p /usr/bin/fula/
	cp /tmp/overlay/offline_docker/* /usr/bin/fula/
	ls -la /usr/bin/fula

	cd /home/pi/fula-ota/docker/fxsupport/linux
	bash ./fula.sh install chroot

	mkdir -p /home/pi
	chown -R pi:pi /home/pi

	#disable resize rootfs
	touch /usr/bin/fula/.resize_flg

	cd /tmp

} # InstallFulaOTA


function setup_logrotate
{
    # Check if logrotate is installed
    if ! command -v logrotate &> /dev/null
    then
        echo "logrotate could not be found. Installing..."
          apt-get update
          apt-get install logrotate -y
    else
        echo "logrotate is already installed."
    fi

    # Create logrotate configuration file
    local logfile_path=$1
    local config_path="/etc/logrotate.d/fula_logs"
    local temp_config_path="/tmp/fula_logs.tmp"

    cat << EOF > ${temp_config_path}
${logfile_path} {
    daily
    rotate 6
    compress
    missingok
    notifempty
    create 0640 root root
    copytruncate
}
EOF

    # Check if the existing config file is different than the temp config
    if [ ! -f ${config_path} ] || ! cmp -s ${config_path} ${temp_config_path}
    then
        # If they differ, replace the old config with the new one
          mv ${temp_config_path} ${config_path}
        echo "Logrotate configuration file for $logfile_path has been updated."

        # Force logrotate to read the new configuration
          logrotate -f /etc/logrotate.conf
    else
        echo "Logrotate configuration file for $logfile_path is already up to date."
        # Remove the temporary config file
        rm ${temp_config_path}
    fi
}

function modify_bluetooth()
{
  # Backup the original file
  cp /etc/systemd/system/dbus-org.bluez.service /etc/systemd/system/dbus-org.bluez.service.bak

  # Modify ExecStart
  sed -i 's|^ExecStart=/usr/libexec/bluetooth/bluetoothd$|ExecStart=/usr/libexec/bluetooth/bluetoothd  --compat --noplugin=sap -C|' /etc/systemd/system/dbus-org.bluez.service

  # Modify ExecStartPost only if "ExecStartPost=/usr/bin/sdptool add SP" does not exist
  if ! grep -q "ExecStartPost=/usr/bin/sdptool add SP" /etc/systemd/system/dbus-org.bluez.service; then
    sed -i '/ExecStart=/a ExecStartPost=/usr/bin/sdptool add SP' /etc/systemd/system/dbus-org.bluez.service
  fi

  # Reload the systemd manager configuration
  #systemctl daemon-reload

  # Restart the bluetooth service
  #  systemctl restart bluetooth
}

function check_internet() {
  wget -q --spider --timeout=10 https://hub.docker.com
  return $?   # Return the status directly, no need for if/else.
}

HOME_DIR=/home/pi
FULA_OTA_HOME=$HOME_DIR/fula-ota/fula
FULA_PATH=/usr/bin/fula
FULA_LOG_PATH=$HOME_DIR/fula.sh.log
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$FULA_PATH/.env"
DOCKER_DIR=$DIR
SYSTEMD_PATH=/etc/systemd/system

function dockerPull() {
  if check_internet; then
    echo "Start polling images..." | tee -a $FULA_LOG_PATH

	echo "run docker deamon..." | tee -a $FULA_LOG_PATH
	#dockerd&

    if [ -z "$1" ]; then
      echo "Full Image Updating..." | tee -a $FULA_LOG_PATH

      # Iterate over services and pull images only if they do not exist locally
      #for service in $(docker-compose config --services); do
	  for service in $(docker-compose -f /home/pi/fula-ota/docker/fxsupport/linux/docker-compose.yml config --services); do
        #image=$(docker-compose config | awk '$1 == "image:" { print $2 }' | grep "$service")
		image=$(docker-compose -f /home/pi/fula-ota/docker/fxsupport/linux/docker-compose.yml config | awk '$1 == "image:" { print $2 }' | grep "$service")
		echo "images:"
		echo $image
        # Attempt to pull the image, if it fails use the local version
		echo "Attempt to pull the image"
        #if ! docker-compose -f "${DOCKER_DIR}/docker-compose.yml" --env-file "$ENV_FILE" pull "$service"; then
		if ! docker-compose -f "${FULA_OTA_HOME}/docker-compose.yml" --env-file "$ENV_FILE" pull "$service"; then
          echo "$service image pull failed, using local version" | tee -a $FULA_LOG_PATH
        fi
      done
    else
      . "$ENV_FILE"
      echo "Updating fxsupport ($FX_SUPPROT)..." | tee -a $FULA_LOG_PATH

      # Attempt to pull the image, if it fails use the local version
      if ! docker pull "$FX_SUPPROT"; then
        echo "fx_support image pull failed, using local version" | tee -a $FULA_LOG_PATH
      fi
    fi
  else
    echo "You are not connected to internet!" | tee -a $FULA_LOG_PATH
    echo "Please check your connection" | tee -a $FULA_LOG_PATH
  fi
}

function dockerComposeBuild() {
  docker-compose -f "${DOCKER_DIR}/docker-compose.yml" --env-file "$ENV_FILE" build --no-cache 2>&1 | tee -a $FULA_LOG_PATH
}

function create_cron() {
  local cron_command_update="*/5 * * * * if [ -f /usr/bin/fula/update.sh ]; then sudo bash /usr/bin/fula/update.sh; fi"
  local cron_command_bluetooth="@reboot sudo bash /usr/bin/fula/bluetooth.sh 2>&1 | tee -a /home/pi/fula.sh.log"

  # Create a temporary file
  local temp_file
  temp_file=$(mktemp)

  # Remove all existing instances of the update job and the bluetooth job
  # Write the results to the temporary file
  crontab -l | grep -v -e "/usr/bin/fula/update.sh" -e "/usr/bin/fula/bluetooth.sh" > "$temp_file"

  # Add the cron jobs back in
  echo "$cron_command_update" >> "$temp_file"
  echo "$cron_command_bluetooth" >> "$temp_file"

  # Replace the current cron jobs with the contents of the temporary file
  crontab "$temp_file"

  # Remove the temporary file
  rm "$temp_file"

  echo "Cron jobs created/updated." 2>&1 | tee -a $FULA_LOG_PATH
}

function FulaOTAinstall()
{
	all_success=true
	mkdir -p $HOME_DIR/internal

	if [ -d "$HOME_DIR/fula-ota" ]; then
	  echo "Updating fula-ota repository..." | tee -a $FULA_LOG_PATH
	  git config --global --add safe.directory "$HOME_DIR/fula-ota" || { echo "Git config failed for fula-ota" | tee -a $FULA_LOG_PATH; } || true
	  git -C "$HOME_DIR/fula-ota" pull 2>&1 | tee -a $FULA_LOG_PATH || { echo "Git pull failed for fula-ota" | tee -a $FULA_LOG_PATH; } || true
	else
	  echo "fula-ota directory not found" | tee -a $FULA_LOG_PATH

	fi

	if test -f /etc/apt/apt.conf.d/proxy.conf; then rm /etc/apt/apt.conf.d/proxy.conf; fi
	setup_logrotate $FULA_LOG_PATH || { echo "Error setting up logrotate" 2>&1 | tee -a $FULA_LOG_PATH; all_success=false; } || true
	mkdir -p /home/pi/commands/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error making directory /home/pi/commands/" 2>&1 | tee -a $FULA_LOG_PATH; all_success=false; } || true

	echo "Call modify_bluetooth, but don't stop the script if it fails" 2>&1 |   tee -a $FULA_LOG_PATH
	modify_bluetooth 2>&1 | tee -a $FULA_LOG_PATH || { echo "modify_bluetooth failed, but continuing installation..." 2>&1 | tee -a $FULA_LOG_PATH; all_success=false; } || true

	echo "Copying Files..." | tee -a $FULA_LOG_PATH
  	mkdir -p $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error making directory $FULA_PATH" | tee -a $FULA_LOG_PATH; }

	if [ "$(readlink -f .)" != "$(readlink -f $FULA_PATH)" ]; then
	  cp $FULA_OTA_HOME/docker-compose.yml $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file docker-compose.yml" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/.env $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file .env" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/union-drive.sh $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file union-drive.sh" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/fula.sh $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file fula.sh" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/hw_test.py $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file hw_test.py" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/resize.sh $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file resize.sh" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/wifi.sh $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file wifi.sh" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/control_led.py $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file control_led.py" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/service.py $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file service.py" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/advertisement.py $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file advertisement.py" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/bletools.py $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file bletools.py" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/service.py $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file service.py" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/bluetooth.py $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file bluetooth.py" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/update.sh $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file update.sh" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/docker_rm_duplicate_network.py $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file docker_rm_duplicate_network.py" | tee -a $FULA_LOG_PATH; } || true
	  cp $FULA_OTA_HOME/commands.sh $FULA_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying file commands.sh" | tee -a $FULA_LOG_PATH; } || true
	else
	  echo "Source and destination are the same, skipping copy" | tee -a $FULA_LOG_PATH
	fi

	echo "Installing Fula ..." 2>&1 | tee -a $FULA_LOG_PATH
	echo "Pulling Images..." 2>&1 | tee -a $FULA_LOG_PATH
	dockerPull || { echo "Error while dockerPull" 2>&1 | tee -a $FULA_LOG_PATH; all_success=false; }

	echo "Building Images..." |   tee -a $FULA_LOG_PATH
	dockerComposeBuild 2>&1 |   tee -a $FULA_LOG_PATH || { echo "Error while dockerComposeBuild" |   tee -a $FULA_LOG_PATH; all_success=false; }

  	cp $FULA_OTA_HOME/fula.service $SYSTEMD_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying fula.service" | tee -a $FULA_LOG_PATH; } || true
  	cp $FULA_OTA_HOME/uniondrive.service $SYSTEMD_PATH/ 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error copying uniondrive.service" | tee -a $FULA_LOG_PATH; } || true

  	if [ -f "/usr/bin/fula/docker.env" ]; then
  	  rm /usr/bin/fula/docker.env 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error removing /usr/bin/fula/docker.env" | tee -a $FULA_LOG_PATH; } || true
  	else
  	  echo "File /usr/bin/fula/docker.env does not exist, skipping removal" | tee -a $FULA_LOG_PATH
  	fi

  	echo "Setting chmod..." | tee -a $FULA_LOG_PATH
  	if [ -f "$FULA_PATH/fula.sh" ]; then
  	  # Check if fula.sh is executable
  	  if [ ! -x "$FULA_PATH/fula.sh" ]; then
  	    echo "$FULA_PATH/fula.sh is not executable, changing permissions..." | tee -a $FULA_LOG_PATH
  	    chmod +x $FULA_PATH/fula.sh 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error chmod file fula.sh" | tee -a $FULA_LOG_PATH; }
  	  fi
  	fi

	if [ -f "$FULA_PATH/resize.sh" ]; then
	  # Check if resize.sh is executable
	  if [ ! -x "$FULA_PATH/resize.sh" ]; then
	    echo "$FULA_PATH/resize.sh is not executable, changing permissions..." | tee -a $FULA_LOG_PATH
	    chmod +x $FULA_PATH/resize.sh 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error chmod file resize.sh" | tee -a $FULA_LOG_PATH; }
	  fi
	fi

	if [ -f "$FULA_PATH/update.sh" ]; then
	  # Check if update.sh is executable
	  if [ ! -x "$FULA_PATH/update.sh" ]; then
	    echo "$FULA_PATH/update.sh is not executable, changing permissions..." | tee -a $FULA_LOG_PATH
	    chmod +x $FULA_PATH/update.sh 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error chmod file update.sh" | tee -a $FULA_LOG_PATH; }
	  fi
	fi
	if [ -f "$FULA_PATH/wifi.sh" ]; then
	  # Check if wifi.sh is executable
	  if [ ! -x "$FULA_PATH/wifi.sh" ]; then
	    echo "$FULA_PATH/wifi.sh is not executable, changing permissions..." | tee -a $FULA_LOG_PATH
	    chmod +x $FULA_PATH/wifi.sh 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error chmod file wifi.sh" | tee -a $FULA_LOG_PATH; }
	  fi
	fi
	if [ -f "$FULA_PATH/commands.sh" ]; then
	  # Check if commands.sh is executable
	  if [ ! -x "$FULA_PATH/commands.sh" ]; then
	    echo "$FULA_PATH/commands.sh is not executable, changing permissions..." | tee -a $FULA_LOG_PATH
	    chmod +x $FULA_PATH/commands.sh 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error chmod file commands.sh" | tee -a $FULA_LOG_PATH; }
	  fi
	fi

	echo "Installing Services..." | tee -a $FULA_LOG_PATH
  	systemctl daemon-reload 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error daemon reload" | tee -a $FULA_LOG_PATH; all_success=false; }
  	systemctl enable uniondrive.service 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error enableing uniondrive.service" | tee -a $FULA_LOG_PATH; all_success=false; }
  	echo "Installing Uniondrive Finished" | tee -a $FULA_LOG_PATH
  	systemctl enable fula.service 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error enableing fula.service" | tee -a $FULA_LOG_PATH; all_success=false; }
  	echo "Installing Fula Finished" | tee -a $FULA_LOG_PATH
  	echo "Setting up cron job for manual update" | tee -a $FULA_LOG_PATH
  	create_cron 2>&1 | tee -a $FULA_LOG_PATH || { echo "Could not setup cron job" | tee -a $FULA_LOG_PATH; all_success=false; } || true
  	echo "installation done with all_success=$all_success" | tee -a $FULA_LOG_PATH
  	if $all_success; then
  	  rm -f $HOME_DIR/V[0-9].info || { echo "Error removing previous version files" | tee -a $FULA_LOG_PATH; }
  	  touch $HOME_DIR/V6.info 2>&1 | tee -a $FULA_LOG_PATH || { echo "Error creating version file" | tee -a $FULA_LOG_PATH; }
  	else
  	  echo "Installation finished with errors, version file not created." | tee -a $FULA_LOG_PATH
  	fi

} # FulaOTAinstall

InstallOpenMediaVault() {
	# use this routine to create a Debian based fully functional OpenMediaVault
	# image (OMV 3 on Jessie, OMV 4 with Stretch). Use of mainline kernel highly
	# recommended!
	#
	# Please note that this variant changes Armbian default security
	# policies since you end up with root password 'openmediavault' which
	# you have to change yourself later. SSH login as root has to be enabled
	# through OMV web UI first
	#
	# This routine is based on idea/code courtesy Benny Stark. For fixes,
	# discussion and feature requests please refer to
	# https://forum.armbian.com/index.php?/topic/2644-openmediavault-3x-customize-imagesh/

	echo root:openmediavault | chpasswd
	rm /root/.not_logged_in_yet
	. /etc/default/cpufrequtils
	export LANG=C LC_ALL="en_US.UTF-8"
	export DEBIAN_FRONTEND=noninteractive
	export APT_LISTCHANGES_FRONTEND=none

	case ${RELEASE} in
		jessie)
			OMV_Name="erasmus"
			OMV_EXTRAS_URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/openmediavault-omvextrasorg_latest_all3.deb"
			;;
		stretch)
			OMV_Name="arrakis"
			OMV_EXTRAS_URL="https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/openmediavault-omvextrasorg_latest_all4.deb"
			;;
	esac

	# Add OMV source.list and Update System
	cat > /etc/apt/sources.list.d/openmediavault.list <<- EOF
	deb https://openmediavault.github.io/packages/ ${OMV_Name} main
	## Uncomment the following line to add software from the proposed repository.
	deb https://openmediavault.github.io/packages/ ${OMV_Name}-proposed main

	## This software is not part of OpenMediaVault, but is offered by third-party
	## developers as a service to OpenMediaVault users.
	# deb https://openmediavault.github.io/packages/ ${OMV_Name} partner
	EOF

	# Add OMV and OMV Plugin developer keys, add Cloudshell 2 repo for XU4
	if [ "${BOARD}" = "odroidxu4" ]; then
		add-apt-repository -y ppa:kyle1117/ppa
		sed -i 's/jessie/xenial/' /etc/apt/sources.list.d/kyle1117-ppa-jessie.list
	fi
	mount --bind /dev/null /proc/mdstat
	apt-get update
	apt-get --yes --force-yes --allow-unauthenticated install openmediavault-keyring
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 7AA630A1EDEE7D73
	apt-get update

	# install debconf-utils, postfix and OMV
	HOSTNAME="${BOARD}"
	debconf-set-selections <<< "postfix postfix/mailname string ${HOSTNAME}"
	debconf-set-selections <<< "postfix postfix/main_mailer_type string 'No configuration'"
	apt-get --yes --force-yes --allow-unauthenticated  --fix-missing --no-install-recommends \
		-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
		debconf-utils postfix
	# move newaliases temporarely out of the way (see Ubuntu bug 1531299)
	cp -p /usr/bin/newaliases /usr/bin/newaliases.bak && ln -sf /bin/true /usr/bin/newaliases
	sed -i -e "s/^::1         localhost.*/::1         ${HOSTNAME} localhost ip6-localhost ip6-loopback/" \
		-e "s/^127.0.0.1   localhost.*/127.0.0.1   ${HOSTNAME} localhost/" /etc/hosts
	sed -i -e "s/^mydestination =.*/mydestination = ${HOSTNAME}, localhost.localdomain, localhost/" \
		-e "s/^myhostname =.*/myhostname = ${HOSTNAME}/" /etc/postfix/main.cf
	apt-get --yes --force-yes --allow-unauthenticated  --fix-missing --no-install-recommends \
		-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" install \
		openmediavault

	# install OMV extras, enable folder2ram and tweak some settings
	FILE=$(mktemp)
	wget "$OMV_EXTRAS_URL" -qO $FILE && dpkg -i $FILE

	/usr/sbin/omv-update
	# Install flashmemory plugin and netatalk by default, use nice logo for the latter,
	# tweak some OMV settings
	. /usr/share/openmediavault/scripts/helper-functions
	apt-get -y -q install openmediavault-netatalk openmediavault-flashmemory
	AFP_Options="mimic model = Macmini"
	SMB_Options="min receivefile size = 16384\nwrite cache size = 524288\ngetwd cache = yes\nsocket options = TCP_NODELAY IPTOS_LOWDELAY"
	xmlstarlet ed -L -u "/config/services/afp/extraoptions" -v "$(echo -e "${AFP_Options}")" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/smb/extraoptions" -v "$(echo -e "${SMB_Options}")" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/flashmemory/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/ssh/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/services/ssh/permitrootlogin" -v "0" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/time/ntp/enable" -v "1" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/time/timezone" -v "UTC" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/network/dns/hostname" -v "${HOSTNAME}" /etc/openmediavault/config.xml
	xmlstarlet ed -L -u "/config/system/monitoring/perfstats/enable" -v "0" /etc/openmediavault/config.xml
	echo -e "OMV_CPUFREQUTILS_GOVERNOR=${GOVERNOR}" >>/etc/default/openmediavault
	echo -e "OMV_CPUFREQUTILS_MINSPEED=${MIN_SPEED}" >>/etc/default/openmediavault
	echo -e "OMV_CPUFREQUTILS_MAXSPEED=${MAX_SPEED}" >>/etc/default/openmediavault
	for i in netatalk samba flashmemory ssh ntp timezone interfaces cpufrequtils monit collectd rrdcached ; do
		/usr/sbin/omv-mkconf $i
	done
	/sbin/folder2ram -enablesystemd || true
	sed -i 's|-j /var/lib/rrdcached/journal/ ||' /etc/init.d/rrdcached

	# Fix multiple sources entry on ARM with OMV4
	sed -i '/stretch-backports/d' /etc/apt/sources.list

	# rootfs resize to 7.3G max and adding omv-initsystem to firstrun -- q&d but shouldn't matter
	echo 15500000s >/root/.rootfs_resize
	sed -i '/systemctl\ disable\ armbian-firstrun/i \
	mv /usr/bin/newaliases.bak /usr/bin/newaliases \
	export DEBIAN_FRONTEND=noninteractive \
	sleep 3 \
	apt-get install -f -qq python-pip python-setuptools || exit 0 \
	pip install -U tzupdate \
	tzupdate \
	read TZ </etc/timezone \
	/usr/sbin/omv-initsystem \
	xmlstarlet ed -L -u "/config/system/time/timezone" -v "${TZ}" /etc/openmediavault/config.xml \
	/usr/sbin/omv-mkconf timezone \
	lsusb | egrep -q "0b95:1790|0b95:178a|0df6:0072" || sed -i "/ax88179_178a/d" /etc/modules' /usr/lib/armbian/armbian-firstrun
	sed -i '/systemctl\ disable\ armbian-firstrun/a \
	sleep 30 && sync && reboot' /usr/lib/armbian/armbian-firstrun

	# add USB3 Gigabit Ethernet support
	echo -e "r8152\nax88179_178a" >>/etc/modules

	# Special treatment for ODROID-XU4 (and later Amlogic S912, RK3399 and other big.LITTLE
	# based devices). Move all NAS daemons to the big cores. With ODROID-XU4 a lot
	# more tweaks are needed. CS2 repo added, CS1 workaround added, coherent_pool=1M
	# set: https://forum.odroid.com/viewtopic.php?f=146&t=26016&start=200#p197729
	# (latter not necessary any more since we fixed it upstream in Armbian)
	case ${BOARD} in
		odroidxu4)
			HMP_Fix='; taskset -c -p 4-7 $i '
			# Cloudshell stuff (fan, lcd, missing serials on 1st CS2 batch)
			echo "H4sIAKdXHVkCA7WQXWuDMBiFr+eveOe6FcbSrEIH3WihWx0rtVbUFQqCqAkYGhJn
			tF1x/vep+7oebDfh5DmHwJOzUxwzgeNIpRp9zWRegDPznya4VDlWTXXbpS58XJtD
			i7ICmFBFxDmgI6AXSLgsiUop54gnBC40rkoVA9rDG0SHHaBHPQx16GN3Zs/XqxBD
			leVMFNAz6n6zSWlEAIlhEw8p4xTyFtwBkdoJTVIJ+sz3Xa9iZEMFkXk9mQT6cGSQ
			QL+Cr8rJJSmTouuuRzfDtluarm1aLVHksgWmvanm5sbfOmY3JEztWu5tV9bCXn4S
			HB8RIzjoUbGvFvPw/tmr0UMr6bWSBupVrulY2xp9T1bruWnVga7DdAqYFgkuCd3j
			vORUDQgej9HPJxmDDv+3WxblBSuYFH8oiNpHz8XvPIkU9B3JVCJ/awIAAA==" \
			| tr -d '[:blank:]' | base64 --decode | gunzip -c >/usr/local/sbin/cloudshell2-support.sh
			chmod 755 /usr/local/sbin/cloudshell2-support.sh
			apt install -y i2c-tools odroid-cloudshell cloudshell2-fan
			sed -i '/systemctl\ disable\ armbian-firstrun/i \
			lsusb | grep -q -i "05e3:0735" && sed -i "/exit\ 0/i echo 20 > /sys/class/block/sda/queue/max_sectors_kb" /etc/rc.local \
			/usr/sbin/i2cdetect -y 1 | grep -q "60: 60" && /usr/local/sbin/cloudshell2-support.sh' /usr/lib/armbian/armbian-firstrun
			;;
		bananapim3|nanopifire3|nanopct3plus|nanopim3)
			HMP_Fix='; taskset -c -p 4-7 $i '
			;;
		edge*|ficus|firefly-rk3399|nanopct4|nanopim4|nanopineo4|renegade-elite|roc-rk3399-pc|rockpro64|station-p1)
			HMP_Fix='; taskset -c -p 4-5 $i '
			;;
	esac
	echo "* * * * * root for i in \`pgrep \"ftpd|nfsiod|smbd|afpd|cnid\"\` ; do ionice -c1 -p \$i ${HMP_Fix}; done >/dev/null 2>&1" \
		>/etc/cron.d/make_nas_processes_faster
	chmod 600 /etc/cron.d/make_nas_processes_faster

	# add SATA port multiplier hint if appropriate
	[ "${LINUXFAMILY}" = "sunxi" ] && \
		echo -e "#\n# If you want to use a SATA PM add \"ahci_sunxi.enable_pmp=1\" to bootargs above" \
		>>/boot/boot.cmd

	# Filter out some log messages
	echo ':msg, contains, "do ionice -c1" ~' >/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "action " ~' >>/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "netsnmp_assert" ~' >>/etc/rsyslog.d/omv-armbian.conf
	echo ':msg, contains, "Failed to initiate sched scan" ~' >>/etc/rsyslog.d/omv-armbian.conf

	# Fix little python bug upstream Debian 9 obviously ignores
	if [ -f /usr/lib/python3.5/weakref.py ]; then
		wget -O /usr/lib/python3.5/weakref.py \
		https://raw.githubusercontent.com/python/cpython/9cd7e17640a49635d1c1f8c2989578a8fc2c1de6/Lib/weakref.py
	fi

	# clean up and force password change on first boot
	umount /proc/mdstat
	chage -d 0 root
} # InstallOpenMediaVault

UnattendedStorageBenchmark() {
	# Function to create Armbian images ready for unattended storage performance testing.
	# Useful to use the same OS image with a bunch of different SD cards or eMMC modules
	# to test for performance differences without wasting too much time.

	rm /root/.not_logged_in_yet

	apt-get -qq install time

	wget -qO /usr/local/bin/sd-card-bench.sh https://raw.githubusercontent.com/ThomasKaiser/sbc-bench/master/sd-card-bench.sh
	chmod 755 /usr/local/bin/sd-card-bench.sh

	sed -i '/^exit\ 0$/i \
	/usr/local/bin/sd-card-bench.sh &' /etc/rc.local
} # UnattendedStorageBenchmark

InstallAdvancedDesktop()
{
	apt-get install -yy transmission libreoffice libreoffice-style-tango meld remmina thunderbird kazam avahi-daemon
	[[ -f /usr/share/doc/avahi-daemon/examples/sftp-ssh.service ]] && cp /usr/share/doc/avahi-daemon/examples/sftp-ssh.service /etc/avahi/services/
	[[ -f /usr/share/doc/avahi-daemon/examples/ssh.service ]] && cp /usr/share/doc/avahi-daemon/examples/ssh.service /etc/avahi/services/
	apt clean
} # InstallAdvancedDesktop

Main "$@"
