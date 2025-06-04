#!/bin/bash
canwifi() {
  if curl -Is https://github.com | head -n 1 | grep -q "HTTP/"; then
    "$@"
  else
    echo "Not connected to wifi."
    sleep 2
  fi
}
menu() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=0
    local count=${#options[@]}

    tput civis
    echo "$prompt"
    for i in "${!options[@]}"; do
        if [[ $i -eq $selected ]]; then
            tput smul
            echo " > ${options[i]}"
            tput rmul
        else
            echo "   ${options[i]}"
        fi
    done

    while true; do
        tput cuu $count
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                tput smul
                echo " > ${options[i]}"
                tput rmul
            else
                echo "   ${options[i]}"
            fi
        done

        IFS= read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
        fi

        case $key in
            '[A') ((selected--)) ;;
            '[B') ((selected++)) ;;
            '') break ;;
        esac

        ((selected < 0)) && selected=$((count - 1))
        ((selected >= count)) && selected=0
    done

    tput cnorm
    return $selected
}


export -f menu

credits() {
	echo -e "${COLOR_MAGENTA_B}Credits"
	echo -e "${COLOR_PINK_B}Sophia${COLOR_RESET}: The lead developer of IRS, Figured out wifi"
	echo -e "${COLOR_YELLOW_B}Synaptic${COLOR_RESET}: Emotional Support"
	echo -e "${COLOR_CYAN_B}Simon${COLOR_RESET}: Brainstormed how to do wifi, helped with dhcpcd"
	echo -e "${COLOR_BLUE_B}kraeb${COLOR_RESET}: QoL improvements and initial idea"
	echo -e "${COLOR_GREEN_B}xmb9${COLOR_RESET}: The name, helping with builder and init and part of shimbooting"
    echo -e "${COLOR_RED_B}Mariah Carey${COLOR_RESET}: Bugtesting wifi"
	echo -e "AC3: Literally nothing"
	echo -e "Rainestorme: Murkmod's version finder"
	echo -e " "
	read -p "Press enter to continue."
	clear
	splash 1
} # haha 69


recochoose=(/irs/recovery/*)
shimchoose=(/irs/shims/*)
stuff="/irs/stuff"
selpayload=(/irs/payloads/*.sh)


NEWROOT_MNT=/newroot
STATEFUL_MNT=/stateful

lsbval() {
  local key="$1"
  local lsbfile="${2:-/etc/lsb-release}"

  if ! echo "${key}" | grep -Eq '^[a-zA-Z0-9_]+$'; then
    return 1
  fi

  sed -E -n -e \
    "/^[[:space:]]*${key}[[:space:]]*=/{
      s:^[^=]+=[[:space:]]*::
      s:[[:space:]]+$::
      p
    }" "${lsbfile}"
}
versions() {
    clear
    local release_board=$(lsbval CHROMEOS_RELEASE_BOARD)
    local board_name=${release_board%%-*}
	export board_name
    echo "What version of ChromeOS do you want to download?"
	options_install=(
	    "Latest Version"
	    "Custom Version"
	)

	menu "Select an option (use ↑ ↓ arrows, Enter to select):" "${options_install[@]}"
	install_choice=$?

	case "$install_choice" in
	    0) VERSION="latest" ;;
	    1) read -p "Enter version: " VERSION ;;
        *) echo "Invalid choice, exiting." && exit ;;
	esac
    echo "Fetching recovery image..."
    if [ $VERSION == "latest" ]; then
        export builds=$(curl -ks https://chromiumdash.appspot.com/cros/fetch_serving_builds?deviceCategory=Chrome%20OS)
        export hwid=$(jq "(.builds.$board_name[] | keys)[0]" <<<"$builds")
        export hwid=${hwid:1:-1}
        export milestones=$(jq ".builds.$board_name[].$hwid.pushRecoveries | keys | .[]" <<<"$builds")
        export VERSION=$(echo "$milestones" | tail -n 1 | tr -d '"')
        echo "Latest version is $VERSION"
    fi
    export url="https://raw.githubusercontent.com/rainestorme/chrome100-json/main/boards/$board_name.json"
    export json=$(curl -ks "$url")
    chrome_versions=$(echo "$json" | jq -r '.pageProps.images[].chrome')
    echo "Found $(echo "$chrome_versions" | wc -l) versions of ChromeOS for your board on Chrome100."
    echo "Searching for a match..."
    MATCH_FOUND=0
    for cros_version in $chrome_versions; do
        platform=$(echo "$json" | jq -r --arg version "$cros_version" '.pageProps.images[] | select(.chrome == $version) | .platform')
        channel=$(echo "$json" | jq -r --arg version "$cros_version" '.pageProps.images[] | select(.chrome == $version) | .channel')
        mp_token=$(echo "$json" | jq -r --arg version "$cros_version" '.pageProps.images[] | select(.chrome == $version) | .mp_token')
        mp_key=$(echo "$json" | jq -r --arg version "$cros_version" '.pageProps.images[] | select(.chrome == $version) | .mp_key')
        last_modified=$(echo "$json" | jq -r --arg version "$cros_version" '.pageProps.images[] | select(.chrome == $version) | .last_modified')
        if [[ $cros_version == $VERSION* ]]; then
            echo "Found a $VERSION match on platform $platform from $last_modified."
            MATCH_FOUND=1
            FINAL_URL="https://dl.google.com/dl/edgedl/chromeos/recovery/chromeos_${platform}_${board_name}_recovery_${channel}_${mp_token}-v${mp_key}.bin.zip"
            break
        fi
    done
    if [ $MATCH_FOUND -eq 0 ]; then
        echo "No match found on Chrome100. Falling back to ChromiumDash."
        export builds=$(curl -ks https://chromiumdash.appspot.com/cros/fetch_serving_builds?deviceCategory=Chrome%20OS)
        export hwid=$(jq "(.builds.$board_name[] | keys)[0]" <<<"$builds")
        export hwid=${hwid:1:-1}
        milestones=$(jq ".builds.$board_name[].$hwid.pushRecoveries | keys | .[]" <<<"$builds")
        echo "Searching for a match..."
        for milestone in $milestones; do
            milestone=$(echo "$milestone" | tr -d '"')
            if [[ $milestone == $VERSION* ]]; then
                MATCH_FOUND=1
                FINAL_URL=$(jq -r ".builds.$board_name[].$hwid.pushRecoveries[\"$milestone\"]" <<<"$builds")
                echo "Found a match!"
                break
            fi
        done
    fi
    if [ $MATCH_FOUND -eq 0 ]; then
        echo "No recovery image found for your board and target version. Exiting."
        exit
    fi
	export VERSION
}
export_args() {
  local arg=
  local key=
  local val=
  local acceptable_set='[A-Za-z0-9]_'
  echo "Exporting kernel arguments..."
  for arg in "$@"; do
    key=$(echo "${arg%%=*}" | busybox tr 'a-z' 'A-Z' | \
                   busybox tr -dc "$acceptable_set" '_')
    val="${arg#*=}"
    export "KERN_ARG_$key"="$val"
    echo -n " KERN_ARG_$key=$val,"
  done
  echo ""
}

export_args $(cat /proc/cmdline | sed -e 's/"[^"]*"/DROPPED/g') 1> /dev/null

copy_lsb() {
    echo "Copying lsb..."

    local lsb_file="dev_image/etc/lsb-factory"
    local src_path="${STATEFUL_MNT}/${lsb_file}"
    local dest_path="/newroot/etc/lsb-factory"

    mkdir -p "$(dirname "${dest_path}")"

    if [ -f "${src_path}" ]; then
        echo "Found ${src_path}"
        cp "${src_path}" "${dest_path}" || fail "failed with $?"
        echo "REAL_USB_DEV=${loop}p3" >> "${dest_path}"
        echo "KERN_ARG_KERN_GUID=$(echo "${KERN_ARG_KERN_GUID}" | tr '[:lower:]' '[:upper:]')" >> "${dest_path}"
        echo "Copied lsb-factory to ${dest_path}"
    else
        echo "Missing ${src_path}!"
        return 1
    fi
}


pv_dircopy() {
	[ -d "$1" ] || return 1
	local apparent_bytes
	apparent_bytes=$(du -sb "$1" | cut -f 1)
	mkdir -p "$2"
	tar -C /mnt/shimroot -cf - . | tar -C /newroot -xf -
}

downloadshim() {
	echo "Not all shims will work. KVS does not, but it is already implemented into IRS."
	
}

downloadcros() {
	versions
	cd /irs/recovery/
    curl --progress-bar -k "$FINAL_URL" -o $VERSION.zip
	unzip $VERSION.zip
	rm $VERSION.zip
    cd /
}
downloadshims() {
	cd /irs/shims/
    curl 
    curl --progress-bar -k "$FINAL_URL" -o $NAME.zip
	unzip $NAME.zip
	rm $NAME.zip
    cd /
}
installcros() { #credits to xmb9 for part of this
	options_install=(
	    "Download an image off the interwebs to the flash drive and install"
	    "Use an image already in the images directory"
	    "Exit and return to The IRS Menu"
	)

	menu "Select an option (use ↑ ↓ arrows, Enter to select):" "${options_install[@]}"
	install_choice=$?

	case "$install_choice" in
	    0) canwifi downloadcros ;;
	    1) ;;
	    *) reco="exit" ;;
	esac

	if [[ -z "$(ls -A /irs/recovery)" ]]; then
		echo -e "${COLOR_YELLOW_B}You have no recovery images downloaded!\nPlease download a few images for your board (${board_name})."
		echo -e "Alternatively, these are available on websites such as chrome100.dev, or cros.tech. Put them into the recovery folder on IRS_FILES."
		reco="exit"
	else
		echo -e "Choose the image you want to flash:"
		select FILE in "${recochoose[@]}" "Exit"; do
 			if [[ -n "$FILE" ]]; then
				reco=$FILE
				break
			elif [[ $FILE == "Exit" ]]; then
				reco=$FILE
				break
			fi
		done
	fi

	if [[ $reco == "Exit" ]]; then
		read -p "Press enter to continue."
		clear
		splash 1
	else
		mkdir -p $recoroot
		echo -e "Searching for ROOT-A on reco image..."
		loop=$(losetup -fP --show $reco)
		loop_root="$(cgpt find -l ROOT-A $loop | head -n 1)"
		if mount -r "${loop_root}" $recoroot ; then
			echo -e "ROOT-A found successfully and mounted."
		else
 			result=$?
			err1="Mount process failed! Exit code was ${result}.\n"
			err2="              This may be a bug! Please check your recovery image,\n"
			err3="              and if it looks fine, report it to the GitHub repo!\n"
			fail "${err1}${err2}${err3}"
		fi
		local cros_dev="$(get_largest_cros_blockdev)"
  		if [ -z "$cros_dev" ]; then
			echo -e "${COLOR_YELLOW_B}No ChromeOS drive was found on the device! Please make sure ChromeOS is installed before using IRS. Continuing anyway...${COLOR_RESET}"
		fi
		stateful="$(cgpt find -l STATE ${loop} | head -n 1 | grep --color=never /dev/)" || fail "Failed to find stateful partition on ${loop}!"
		mount $stateful /mnt/stateful_partition || fail "Failed to mount stateful partition!"
		MOUNTS="/proc /dev /sys /tmp /run /var /mnt/stateful_partition"
		cd /mnt/recoroot/
		d=
		for d in ${MOUNTS}; do
	  		mount -n --bind "${d}" "./${d}"
	  		mount --make-slave "./${d}"
		done
		chroot ./ /usr/sbin/chromeos-install --payload_image="${loop}" --yes || fail "Failed during chroot!"
		cgpt add -i 2 $cros_dev -P 15 -T 15 -S 1 -R 1 || echo -e "${COLOR_YELLOW_B}Failed to set kernel priority! Continuing anyway.${COLOR_RESET}"
		echo -e "${COLOR_GREEN}\n"
		read -p "Recovery finished. Press any key to reboot."
		reboot
		sleep 1
		echo -e "\n${COLOR_RED_B}Reboot failed. Hanging..."
	fi
}
shimboot() { # credits to xmb9 for some of this
    options_install=(
        "Download a shim off the interwebs to the flash drive and boot"
        "Use a shim already in the shims directory"
        "Exit and return to The IRS Menu"
    )

    menu "Select an option (use ↑ ↓ arrows, Enter to select):" "${options_install[@]}"
    install_choice=$?

    case "$install_choice" in
        0) canwifi downloadshims ;;
        1) ;;
        *) return ;;
    esac

    if [[ -z "$(ls -A /irs/shims)" ]]; then
        echo -e "${COLOR_YELLOW_B}You have no recovery images downloaded!\nPlease download a few images for your board (${board_name})."
        echo -e "Alternatively, these are available on websites such as chrome100.dev, or cros.tech. Put them into the recovery folder on IRS_FILES."
        reco="exit"
    else
        if [[ -z "$(ls -A /irs/shims 2>/dev/null)" ]]; then
            echo -e "${COLOR_YELLOW_B}You have no shims downloaded!"
            shim="Exit"
        else
            shim_options=("${shimchoose[@]}" "Exit")
            menu "Select an option (use ↑ ↓ arrows, Enter to select):" "${shim_options[@]}"
            choice=$?
            shim="${shim_options[$choice]}"
        fi

        if [[ $shim == "Exit" ]]; then
            read -p "Press enter to continue."
            clear
            splash
            return
        fi

        mkdir -p "$shimroot"
        loop=$(losetup -fP --show "$shim") || fail "Failed to set up loop device."
        export loop

        loop_root=$(cgpt find -l ROOT-A "$loop" 2>/dev/null || cgpt find -t rootfs "$loop" | head -n 1)
        [[ -z "$loop_root" ]] && fail "ROOT-A not found."
        mount "$loop_root" "$shimroot" || fail "Failed to mount ROOT-A."

        if ! stateful=$(cgpt find -l STATE "$loop" 2>/dev/null | grep -m1 /dev/); then
            if ! stateful=$(cgpt find -l SH1MMER "$loop" 2>/dev/null | grep -m1 /dev/); then
                for dev in "$loop"*; do
                    [[ -b "$dev" ]] || continue
                    parttype=$(udevadm info --query=property --name="$dev" 2>/dev/null | grep '^ID_PART_ENTRY_TYPE=' | cut -d= -f2)
                    [[ "$parttype" == "0fc63daf-8483-4772-8e79-3d69d8477de4" ]] && stateful="$dev" && break
                done
            fi
        fi

        [[ -z "${stateful// }" ]] && fail "Could not find stateful partition."

        mkdir -p /stateful /newroot
        mount -t tmpfs tmpfs /newroot -o size=1024M || fail "TMPFS mount failed."
        mount -o ro "$stateful" /stateful || fail "Mounting stateful failed."

        copy_lsb
        pv_dircopy "$shimroot" /newroot || fail "Rootfs copy failed."

        for d in dev proc sys tmp run; do mkdir -p "/newroot/$d"; done
        mount -t tmpfs -o mode=1777 none /newroot/tmp
        mount -t tmpfs -o mode=0555 run /newroot/run
        mkdir -p -m 0755 /newroot/run/lock

        umount -lf /dev/pts 2>/dev/null

        for mnt in /dev /proc /sys; do
            mount --move "$mnt" "/newroot$mnt" || true
        done

        mkdir -p /newroot/tmp/irs
        pivot_root /newroot /newroot/tmp/irs || fail "pivot_root failed."
        if [ -f "/bin/kvs" ]; then
            exec /bin/kvs
        fi
	if [ -f "/irs/shimscripts/irs.sh" ]; then
 	    cp /tmp/irs/shims/* /irs/shims/
	fi # mwah hah hahhhhhhh
        exec /sbin/init || {
            echo "Init failed. Dropping to shell. This is PID 1."
            /tmp/irs/bin/uname -a
            exec /tmp/irs/bin/sh
        }
    fi
}

payloads() {
	options_payload=("${selpayload[@]}" "Exit")

	menu "Choose payload to run:" "${options_payload[@]}"
	choice=$?

	payload="${options_payload[$choice]}"

	if [[ $payload == "Exit" ]]; then
	    read -p "Press enter to continue."
	    clear
	    splash 0
	else
	    source "$payload"
	    read -p "Press enter to continue."
	    clear
	    splash 0
	fi
}

firmware() {
	cp -r /irs/firmware/* /lib/firmware
	modprobe -r iwlwifi
	modprobe iwlwifi
}

iface=$(ip a | grep "wl" | head -n 1 | awk '{print $2}' | sed 's/://')

autoipcon() {
    iface=$(ip -o link show | awk -F': ' '/wl/ {print $2; exit}')
    DHCP_INFO=$(dhcpcd -d -4 -G -K -T $iface 2>&1)
    ip=$(echo "$DHCP_INFO" | grep -oE 'offered [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}')
    gateway=$(echo "$DHCP_INFO" | grep -oE 'offered .* from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $NF}')
    if [ -z "$ip" ] || [ -z "$gateway" ]; then
        echo "Failed to get ip/gateway. Please report this bug in IRS's issues."
  sleep 1
        
    fi
    firstnum=$(echo "$ip" | cut -d. -f1)
    if [ "$firstnum" = "10" ]; then
        mask="255.0.0.0"
    else
        mask="255.255.255.0"
    fi
    echo "IP: $ip"
    echo "Gateway: $gateway"
    echo "Subnet Mask: $mask"
    ifconfig ${iface} "$ip" netmask "$mask" up
    route add default gw "$gateway"
	read -p "Confirm? (Y/n)" confirmchanges 
}

manipcon() {
    iface=$(ip -o link show | awk -F': ' '/wl/ {print $2; exit}')
	echo -e "Use this only if you know what you're doing or if there was an error with automatic static ip connection."
	echo -e "You can find this information on most any device connected to your wifi."
	read -p "Confirm by pressing Enter."
    DHCP_INFO=$(dhcpcd -d -4 -G -K -T $iface 2>&1)
    ip=$(echo "$DHCP_INFO" | grep -oE 'offered [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $2}')
    gateway=$(echo "$DHCP_INFO" | grep -oE 'offered .* from [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $NF}')
    if [ -z "$ip" ] || [ -z "$gateway" ]; then
        echo "Failed to get ip/gateway. Please report this bug in IRS's issues."
	sleep 1
    fi
    firstnum=$(echo "$ip" | cut -d. -f1)
    if [ "$firstnum" = "10" ]; then
        mask="255.0.0.0"
    else
        mask="255.255.255.0"
    fi

	echo "Found IP: $ip"
	echo "Found Gateway: $gateway"
	echo "Found Subnet Mask: $mask"
	changedhcpinfo() {
		read -p "Enter IP address (leave blank to keep: $ip): " input
		ip="${input:-$ip}"
		read -p "Enter Gateway (leave blank to keep: $gateway): " input
		gateway="${input:-$gateway}"
		read -p "Enter Subnet Mask (leave blank to keep: $mask): " input
		mask="${input:-$mask}"
		echo "Using IP: $ip"
		echo "Using Gateway: $gateway"
		echo "Using Subnet Mask: $mask"
		read -p "Confirm these changes? (Y/n): " confirmchanges
	}	
	changedhcpinfo
}

wifi() {
    rm -f /etc/resolv.conf
    sync
    echo "nameserver 8.8.8.8" > /etc/resolv.conf 
	echo -e "This may take a while!!!"
	mkdir -p /run/dbus
	dbus-daemon --system > /dev/null 2>&1
	mkdir -p /var/lib
	firmware
    read -p "Enter your wifi SSID/Name: " ssid
    read -p "Enter your wifi password (leave blank if none): " psk
    iface=$(ip -o link show | awk -F': ' '/wl/ {print $2; exit}')
    ifconfig $iface up || return
    if [ -z "$psk" ]; then
        wpa_supplicant -i $iface -C /run/wpa_supplicant -B -c <(
            cat <<EOF
network={
    ssid="$ssid"
    key_mgmt=NONE
}
EOF
            )
        else
            wpa_supplicant -i $iface -C /run/wpa_supplicant -B -c <(wpa_passphrase "$ssid" "$psk")
        fi
        dhcpcd >/dev/null
        read -p "Would you like to automatically configure the static ip to connect to the wifi with? (Y/n): " autoip
    	case "$autoip" in
    		y | Y) autoipcon ;;
    		n | N) manipcon ;;
    		*) autoipcon ;;
    	esac
    	case "$confirmchanges" in
    		y | Y) 
    			ifconfig $iface "$ip" netmask "$mask" up
    		    route add default gw "$gateway" ;;
    		n | N) changedhcpinfo ;;
    		    *) ;;
	    esac
} #haha 420

updateshim() {
    source /irs/shimscripts/updateshim.sh
}
options=(
    "Bash shell"
    "Install a ChromeOS recovery image"
    "Payloads"
    "Connect to wifi"
    "Credits"
    "KVS"
    "Boot a shim"
    "Update the IRS Shim"
    "Exit and Reboot"
)

actions=(
    bash
    installcros
    payloads
    wifi
    credits
    "kvs || chromeos-tpm-recovery"
    "shimboot"
    "canwifi updateshim"
    "reboot -f"
)

while true; do
    clear
    splash 0
    menu "Select an option (use ↑ ↓ arrows, Enter to select):" "${options[@]}"
    selected=$?
    eval "${actions[$selected]}"
    echo
done
