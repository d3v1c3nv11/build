#!/bin/sh
#
# Copyright (c) Authors: http://www.armbian.com/authors
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.

. /etc/armbian-release

install_hassio()
{

set -e

ARCH=armv7l
DOCKER_REPO=homeassistant
DATA_SHARE=/usr/share/hassio
URL_VERSION="https://s3.amazonaws.com/hassio-version/stable.json"
URL_BIN_HASSIO="https://raw.githubusercontent.com/home-assistant/hassio-build/master/install/files/hassio-supervisor"
URL_BIN_APPARMOR="https://raw.githubusercontent.com/home-assistant/hassio-build/master/install/files/hassio-apparmor"
URL_SERVICE_HASSIO="https://raw.githubusercontent.com/home-assistant/hassio-build/master/install/files/hassio-supervisor.service"
URL_SERVICE_APPARMOR="https://raw.githubusercontent.com/home-assistant/hassio-build/master/install/files/hassio-apparmor.service"
URL_APPARMOR_PROFILE="http://s3.amazonaws.com/hassio-version/apparmor.txt"

# Check env
command -v systemctl > /dev/null 2>&1 || { echo "[Error] Only systemd is supported!"; exit 1; }
command -v docker > /dev/null 2>&1 || { echo "[Error] Please install docker first"; exit 1; }
command -v jq > /dev/null 2>&1 || { echo "[Error] Please install jq first"; exit 1; }
command -v curl > /dev/null 2>&1 || { echo "[Error] Please install curl first"; exit 1; }
command -v avahi-daemon > /dev/null 2>&1 || { echo "[Error] Please install avahi first"; exit 1; }
command -v dbus-daemon > /dev/null 2>&1 || { echo "[Error] Please install dbus first"; exit 1; }
command -v apparmor_parser > /dev/null 2>&1 || echo "[Warning] No AppArmor support on host."
command -v nmcli > /dev/null 2>&1 || echo "[Warning] No NetworkManager support on host."

function version_gt() { test "$(printf '%s\n' "$@" | sort -V | head -n 1)" != "$1"; }


# Generate hardware options
        HOMEASSISTANT_DOCKER="homeassistant/qemuarm-homeassistant"
        HASSIO_DOCKER="homeassistant/armhf-hassio-supervisor"

### Main

# Init folders
if [ ! -d "$DATA_SHARE" ]; then
    mkdir -p "$DATA_SHARE"
fi

# Read infos from web
HASSIO_VERSION=$(curl -s $URL_VERSION | jq -e -r '.supervisor')

##
# Write config
cat <<-EOF > $destination/etc/hassio.json 
{
    "supervisor": "homeassistant/armhf-hassio-supervisor",
    "homeassistant": "homeassistant/qemuarm-homeassistant}",
    "data": "/usr/share/hassio"
}
EOF
##
# Check DNS settings
DOCKER_VERSION="$(docker --version | grep -Po "\d{2}\.\d{2}\.\d")"
if version_gt "18.09.0" "${DOCKER_VERSION}" && [ ! -e "/etc/docker/daemon.json" ]; then
    echo "[Warning] Create DNS settings for Docker to avoid systemd bug!"
    mkdir -p /etc/docker
    echo '{"dns": ["8.8.8.8", "8.8.4.4"]}' > /etc/docker/daemon.json

    echo "[Info] Restart Docker and wait 30 seconds"
    systemctl restart docker.service && sleep 30
fi

##
# Pull supervisor image
echo "[Info] Install supervisor Docker container"
docker pull "$HASSIO_DOCKER:$HASSIO_VERSION" > /dev/null
docker tag "$HASSIO_DOCKER:$HASSIO_VERSION" "$HASSIO_DOCKER:latest" > /dev/null

##
# Install Hass.io Supervisor
echo "[Info] Install supervisor startup scripts"
curl -sL ${URL_BIN_HASSIO} > /usr/sbin/hassio-supervisor
curl -sL ${URL_SERVICE_HASSIO} > /etc/systemd/system/hassio-supervisor.service

chmod a+x /usr/sbin/hassio-supervisor
systemctl enable hassio-supervisor.service

#
# Install Hass.io AppArmor
if command -v apparmor_parser > /dev/null 2>&1; then
    echo "[Info] Install AppArmor scripts"
    mkdir -p ${DATA_SHARE}/apparmor
    curl -sL ${URL_BIN_APPARMOR} > /usr/sbin/hassio-apparmor
    curl -sL ${URL_SERVICE_APPARMOR} > /etc/systemd/system/hassio-apparmor.service
    curl -sL ${URL_APPARMOR_PROFILE} > ${DATA_SHARE}/apparmor/hassio-supervisor

    chmod a+x /usr/sbin/hassio-apparmor
    systemctl enable hassio-apparmor.service

    systemctl start hassio-apparmor.service
fi

##
# Init system
echo "[Info] Run Hass.io"
systemctl start hassio-supervisor.service	
	
	
}	
check_abort()
{
	echo -e "\nDisabling user account creation procedure\n"
	rm -f /root/.not_logged_in_yet
	trap - INT
	exit 0
}

add_profile_sync_settings()
{
	/usr/bin/psd >/dev/null 2>&1
	config_file="${HOME}/.config/psd/psd.conf"
	if [ -f "${config_file}" ]; then
		# test for overlayfs
		sed -i 's/#USE_OVERLAYFS=.*/USE_OVERLAYFS="yes"/' "${config_file}"
		case $(/usr/bin/psd p 2>/dev/null | grep Overlayfs) in
			*active*)
				echo -e "\nConfigured profile sync daemon with overlayfs."
				;;
			*)
				echo -e "\nConfigured profile sync daemon."
				sed -i 's/USE_OVERLAYFS="yes"/#USE_OVERLAYFS="no"/' "${config_file}"
				;;
		esac
	fi
	systemctl --user enable psd.service >/dev/null 2>&1
	systemctl --user start psd.service >/dev/null 2>&1
}

add_user()
{
	read -t 0 temp
	echo -e "\nPlease provide a username (eg. your forename): \c"
	read -e username
	RealUserName="$(echo "$username" | tr '[:upper:]' '[:lower:]' | tr -d -c '[:alnum:]')"
	[ -z "$RealUserName" ] && return
	echo "Trying to add user $RealUserName"
	adduser $RealUserName || return
	for additionalgroup in sudo netdev audio video dialout plugdev input bluetooth systemd-journal ssh; do
		usermod -aG ${additionalgroup} ${RealUserName} 2>/dev/null
	done
	# fix for gksu in Xenial
	touch /home/$RealUserName/.Xauthority
	chown $RealUserName:$RealUserName /home/$RealUserName/.Xauthority
	RealName="$(awk -F":" "/^${RealUserName}:/ {print \$5}" </etc/passwd | cut -d',' -f1)"
	[ -z "$RealName" ] && RealName=$RealUserName
	echo -e "\nDear ${RealName}, your account ${RealUserName} has been created and is sudo enabled."
	echo -e "Please use this account for your daily work from now on.\n"
	rm -f /root/.not_logged_in_yet
	# set up profile sync daemon on desktop systems
	which psd >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo -e "${RealUserName} ALL=(ALL) NOPASSWD: /usr/bin/psd-overlay-helper" >> /etc/sudoers
		touch /home/${RealUserName}/.activate_psd
		chown $RealUserName:$RealUserName /home/${RealUserName}/.activate_psd
	fi
}

if [ ! -f /etc/hassio.json ]; then
 echo "Installing Home Assistent..."
 install_hassio
fi

if [ -f /root/.not_logged_in_yet ] && [ -n "$BASH_VERSION" ] && [ "$-" != "${-#*i}" ]; then
	# detect desktop
	desktop_nodm=$(dpkg-query -W -f='${db:Status-Abbrev}\n' nodm 2>/dev/null)
	desktop_lightdm=$(dpkg-query -W -f='${db:Status-Abbrev}\n' lightdm 2>/dev/null)

	if [ -n "$desktop_nodm" ]; then DESKTOPDETECT="nodm"; fi
	if [ -n "$desktop_lightdm" ]; then DESKTOPDETECT="lightdm"; fi

	if [ "$IMAGE_TYPE" != "nightly" ]; then
		echo -e "\n\e[0;31mThank you for choosing Armbian! Support: \e[1m\e[39mwww.armbian.com\x1B[0m\n"
	else
		echo -e "\nYou are using an Armbian nightly build meant only for developers to provide"
		echo -e "constructive feedback to improve build system, OS settings or user experience."
		echo -e "If this does not apply to you, \e[0;31mSTOP NOW!\x1B[0m. Especially don't use this image for"
		echo -e "daily work since things might not work as expected or at all and may break"
		echo -e "anytime with next update. \e[0;31mYOU HAVE BEEN WARNED!\x1B[0m"
		echo -e "\nThis image is provided \e[0;31mAS IS\x1B[0m with \e[0;31mNO WARRANTY\x1B[0m and \e[0;31mNO END USER SUPPORT!\x1B[0m.\n"
	fi
	    echo "Creating a new user account. Press <Ctrl-C> to abort"
	[ -n "$DESKTOPDETECT" ] && echo "Desktop environment will not be enabled if you abort the new user creation"
	trap check_abort INT
			
	while [ -f "/root/.not_logged_in_yet" ]; do
		add_user
	done
	trap - INT TERM EXIT
	# check for H3/legacy kernel to promote h3disp utility
	if [ -f /boot/script.bin ]; then tmp=$(bin2fex </boot/script.bin 2>/dev/null | grep -w "hdmi_used = 1"); fi
	if [ "$LINUXFAMILY" = "sun8i" ] && [ "$BRANCH" = "default" ] && [ -n "$tmp" ]; then
		setterm -default
		echo -e "\nYour display settings are currently 720p (1280x720). To change this use the"
		echo -e "h3disp utility. Do you want to change display settings now? [nY] \c"
		read -n1 ConfigureDisplay
		if [ "$ConfigureDisplay" != "n" ] && [ "$ConfigureDisplay" != "N" ]; then
			echo -e "\n" ; h3disp
		else
			echo -e "\n"
		fi
	fi
	# check whether desktop environment has to be considered
	if [ "$DESKTOPDETECT" = nodm ] && [ -n "$RealName" ] ; then
		sed -i "s/NODM_USER=\(.*\)/NODM_USER=${RealUserName}/" /etc/default/nodm
		sed -i "s/NODM_ENABLED=\(.*\)/NODM_ENABLED=true/g" /etc/default/nodm
		if [[ -f /var/run/resize2fs-reboot ]]; then
			# Let the user reboot now otherwise start desktop environment
			printf "\n\n\e[0;91mWarning: a reboot is needed to finish resizing the filesystem \x1B[0m \n"
			printf "\e[0;91mPlease reboot the system now \x1B[0m \n\n"
		elif [ -z "$ConfigureDisplay" ] || [ "$ConfigureDisplay" = "n" ] || [ "$ConfigureDisplay" = "N" ]; then
			echo -e "\n\e[1m\e[39mNow starting desktop environment...\x1B[0m\n"
			sleep 3
			service nodm stop
			sleep 1
			service nodm start
		fi
	elif [ "$DESKTOPDETECT" = lightdm ] && [ -n "$RealName" ] ; then
			ln -sf /lib/systemd/system/lightdm.service /etc/systemd/system/display-manager.service
		if [[ -f /var/run/resize2fs-reboot ]]; then
			# Let the user reboot now otherwise start desktop environment
			printf "\n\n\e[0;91mWarning: a reboot is needed to finish resizing the filesystem \x1B[0m \n"
			printf "\e[0;91mPlease reboot the system now \x1B[0m \n\n"
		elif [ -z "$ConfigureDisplay" ] || [ "$ConfigureDisplay" = "n" ] || [ "$ConfigureDisplay" = "N" ]; then
			echo -e "\n\e[1m\e[39mNow starting desktop environment...\x1B[0m\n"
			sleep 1
			service lightdm start 2>/dev/null
			# logout if logged at console
			[[ -n $(who -la | grep root | grep tty1) ]] && exit 1
		fi
	else
		# Display reboot recommendation if necessary
		if [[ -f /var/run/resize2fs-reboot ]]; then
			printf "\n\n\e[0;91mWarning: a reboot is needed to finish resizing the filesystem \x1B[0m \n"
			printf "\e[0;91mPlease reboot the system now \x1B[0m \n\n"
		fi
	fi
fi
