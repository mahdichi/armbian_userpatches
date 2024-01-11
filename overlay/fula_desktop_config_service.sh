#!/bin/bash

Fula_desktop_config_service




configDesktop()
{
	echo "install Desktop Config Service"

	touch /root/.Fula_desktop_config_service
	cp /tmp/overlay/fula_desktop_config_service.sh /usr/bin/fula_desktop_config_service.sh
	chmod +x /usr/bin/fula_desktop_config_service.sh

	touch /etc/systemd/system/fula_desktop_config_service.service

	cat > /etc/systemd/system/fula_desktop_config_service.service <<- EOF
	[Unit]
	Description=fula_desktop_config_service service
	After=multi-user.target

	[Service]
	ExecStart=/bin/bash /usr/bin/fula_desktop_config_service.sh
	Type=simple

	[Install]
	WantedBy=multi-user.target
	EOF
	systemctl --no-reload enable fula_desktop_config_service.service

} # configDesktop
