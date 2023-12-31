#!/bin/bash

Automount()
{
	echo "install Automount"

	touch /usr/local/bin/automount.sh
	chmod +x /usr/local/bin/automount.sh
	cat > /usr/local/bin/automount.sh <<- EOF
    #!/bin/bash

    MOUNTPOINT="/media/pi"
    DEVICE="/dev/$1"
    MOUNTNAME=$(echo $1 | sed 's/[^a-zA-Z0-9]//g')
    mkdir -p ${MOUNTPOINT}/${MOUNTNAME}

    # Determine filesystem type
    FSTYPE=$(blkid -o value -s TYPE ${DEVICE})

    if [ ${FSTYPE} = "ntfs" ]; then
      # If filesystem is NTFS
      # uid and gid specify the owner and the group of files.
      # dmask and fmask control the permissions for directories and files. 0000 gives everyone read and write access.
      mount -t ntfs -o uid=pi,gid=pi,dmask=0000,fmask=0000 ${DEVICE} ${MOUNTPOINT}/${MOUNTNAME}
    elif [ ${FSTYPE} = "vfat" ]; then
      # If filesystem is FAT32
      mount -t vfat -o uid=pi,gid=pi,dmask=0000,fmask=0000 ${DEVICE} ${MOUNTPOINT}/${MOUNTNAME}
    else
      # For other filesystem types
      mount ${DEVICE} ${MOUNTPOINT}/${MOUNTNAME}
      # Changing owner for non-NTFS and non-FAT32 filesystems
      chown pi:pi ${MOUNTPOINT}/${MOUNTNAME}
    fi
	EOF


	touch /etc/udev/rules.d/99-automount.rules
	cat > /etc/udev/rules.d/99-automount.rules <<- EOF
	ACTION=="add", KERNEL=="sd[a-z][0-9]", TAG+="systemd", ENV{SYSTEMD_WANTS}="automount@%k.service"
	ACTION=="add", KERNEL=="nvme[0-9]n[0-9]p[0-9]", TAG+="systemd", ENV{SYSTEMD_WANTS}="automount@%k.service"

	ACTION=="remove", KERNEL=="sd[a-z][0-9]", RUN+="/bin/systemctl stop automount@%k.service"
	ACTION=="remove", KERNEL=="nvme[0-9]n[0-9]p[0-9]", RUN+="/bin/systemctl stop automount@%k.service"
	EOF


	touch /etc/systemd/system/automount@.service
	cat > /etc/systemd/system/automount@.service <<- EOF
	[Unit]
	Description=Automount disks
	BindsTo=dev-%i.device
	After=dev-%i.device

	[Service]
	Type=oneshot
	RemainAfterExit=yes
	ExecStart=/usr/local/bin/automount.sh %I
	ExecStop=/usr/bin/sh -c '/bin/umount /media/pi/$(echo %I | sed 's/[^a-zA-Z0-9]//g'); /bin/rmdir /media/pi/$(echo %I | sed 's/[^a-zA-Z0-9]//g')'
	EOF
	udevadm control --reload-rules
	systemctl enable automount@.service
} # Automount



if [ -f /root/.FulaOneTimeRun ]; then
    echo "Fula Run One Time "

	Automount;

	rm /root/.FulaOneTimeRun
fi
