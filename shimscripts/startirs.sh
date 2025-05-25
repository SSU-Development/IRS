#!/bin/bash

clear
export releaseBuild=1
export shimroot="/mnt/shimroot"
export recoroot="/mnt/recoroot"
export COLOR_RESET="\033[0m"
export COLOR_BLACK_B="\033[1;30m"
export COLOR_RED_B="\033[1;31m"
export COLOR_GREEN="\033[0;32m"
export COLOR_GREEN_B="\033[1;32m"
export COLOR_YELLOW="\033[0;33m"
export COLOR_YELLOW_B="\033[1;33m"
export COLOR_BLUE_B="\033[1;34m"
export COLOR_MAGENTA_B="\033[1;35m"
export COLOR_PINK_B="\x1b[1;38;2;235;170;238m"
export COLOR_CYAN_B="\033[1;36m"

funText() {
	splashText=("    The lower tape fade meme is still massive" "     It probably existed in the first place.")
  	selectedSplashText=${splashText[$RANDOM % ${#splashText[@]}]}
	echo -e " "
   	echo -e "$selectedSplashText"
}
export -f funText

splash() {
    echo -e "$COLOR_GREEN_B"
    echo -e "               _____   _    __  __                "
    echo -e "              |_   _| / \   \ \/ /                "
    echo -e "                | |  / _ \   \  /                 "
    echo -e "                | | / ___ \  /  \                 "
    echo -e "                |_|/_/   \_\/_/\_\                "
    echo -e "   _____ __     __ _     ____  ___  ___   _   _   "
    echo -e "  | ____|\ \   / // \   / ___||_ _|/ _ \ | \ | |  "
    echo -e "  |  _|   \ \ / // _ \  \___ \ | || | | ||  \| |  "
    echo -e "  | |___   \ V // ___ \  ___) || || |_| || |\  |  "
    echo -e "  |_____|   \_//_/   \_\|____/|___|\___/ |_| \_|  "
    echo -e "${COLOR_RESET}"
    if [ "$1" -eq 1 ]; then
        echo -e "        The IRS is initializing. Please wait..."
    fi
    echo -e "      https://github.com/SSU-Development/IRS"
    funText
    echo -e " "
}
export -f splash

if [[ $releaseBuild -eq 1 ]]; then
	trap '' INT
fi

fail() {
	printf "Failure: Aborting..."
	reco="exit"
}
export -f fail

get_largest_cros_blockdev() {
	local largest size dev_name tmp_size remo
	size=0
	for blockdev in /sys/block/*; do
		dev_name="${blockdev##*/}"
		echo -e "$dev_name" | grep -q '^\(loop\|ram\)' && continue
		tmp_size=$(cat "$blockdev"/size)
		remo=$(cat "$blockdev"/removable)
		if [ "$tmp_size" -gt "$size" ] && [ "${remo:-0}" -eq 0 ]; then
			case "$(sfdisk -d "/dev/$dev_name" 2>/dev/null)" in
				*'name="STATE"'*'name="KERN-A"'*'name="ROOT-A"'*)
					largest="/dev/$dev_name"
					size="$tmp_size"
					;;
			esac
		fi
	done
	echo -e "$largest"
}
export -f get_largest_cros_blockdev
splash 1
mkdir /irs
mkdir /mnt/{newroot,shimroot,recoroot}
# Credits to xmb9 for a good portion of what's below this comment
irs_files="/dev/disk/by-label/IRS_FILES"
irs_disk=$(echo /dev/$(lsblk -ndo pkname ${irs_files} || echo -e "${COLOR_YELLOW_B}Warning${COLOR_RESET}: Failed to enumerate disk! Resizing will most likely fail."))
mount $irs_files /irs || fail "Failed to mount IRS_FILES partition!"
if [ ! -z "$(ls -A /irs/.IMAGES_NOT_YET_RESIZED 2> /dev/null)" ]; then
	echo -e "${COLOR_YELLOW}IRS needs to resize your images partition!${COLOR_RESET}"
	echo -e "${COLOR_GREEN}Info: Growing IRS_FILES partition${COLOR_RESET}"
	umount $irs_files
	growpart $irs_disk 5
    e2fsck -f $irs_files
	echo -e "${COLOR_GREEN}Info: Resizing filesystem (This operation may take a while, do not panic if it looks stuck!)${COLOR_RESET}"
	resize2fs -p $irs_files || fail "Failed to resize filesystem on ${irs_files}!"
	echo -e "${COLOR_GREEN}Done. Remounting partition...${COLOR_RESET}"
	mount $irs_files /irs
	rm -rf /irs/.IMAGES_NOT_YET_RESIZED
	sync
fi
chmod 777 /irs/*
source /irs/shimscripts/packages.sh
source /irs/shimscripts/irs.sh
mkdir /mnt/cros && mount /dev/mmcblk