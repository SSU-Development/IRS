#!/bin/busybox sh

set -eE

NEWROOT_MNT=/newroot
ROOTFS_MNT=/usb
STATEFUL_MNT="$1"
STATEFUL_DEV="$2"
BOOTSTRAP_DEV="$3"
ARCHITECTURE="${4:-x86_64}"
ROOTFS_DEV=
COLOR_RESET="\033[0m"
COLOR_BLACK_B="\033[1;30m"
COLOR_RED_B="\033[1;31m"
COLOR_GREEN="\033[0;32m"
COLOR_GREEN_B="\033[1;32m"
COLOR_YELLOW="\033[0;33m"
COLOR_YELLOW_B="\033[1;33m"
COLOR_BLUE_B="\033[1;34m"
COLOR_MAGENTA_B="\033[1;35m"
COLOR_CYAN_B="\033[1;36m"

fail() {
  echo "$@" >&2
  sleep 1
  exit 1
}

pv_dircopy() {
	[ -d "$1" ] || return 1
	local apparent_bytes
	apparent_bytes=$(du -sb "$1" | cut -f 1)
	mkdir -p "$2"
	tar -cf - -C "$1" . | pv -f -s "${apparent_bytes:-0}" | tar -xf - -C "$2"
}

determine_rootfs() {
	local bootstrap_num
	bootstrap_num="$(echo "$BOOTSTRAP_DEV" | grep -o '[0-9]*$')"
	ROOTFS_DEV="$(echo "$BOOTSTRAP_DEV" | sed 's/[0-9]*$//')$((bootstrap_num + 1))"
	[ -b "$ROOTFS_DEV" ] || return 1
}

patch_new_root_sh1mmer() {
	[ -f "$NEWROOT_MNT/sbin/chromeos_startup" ] && sed -i "s/BLOCK_DEVMODE=1/BLOCK_DEVMODE=/g" "$NEWROOT_MNT/sbin/chromeos_startup"
	[ -f "$NEWROOT_MNT/usr/share/cros/dev_utils.sh" ] && sed -i "/^dev_check_block_dev_mode\(\)/a return" "$NEWROOT_MNT/usr/share/cros/dev_utils.sh"
	[ -f "$NEWROOT_MNT/sbin/chromeos-boot-alert" ] && sed -i "/^mode_block_devmode\(\)/a return" "$NEWROOT_MNT/sbin/chromeos-boot-alert"
	local file
	local disable_jobs="factory_shim factory_install factory_ui"
	for job in $disable_jobs; do
		file="$NEWROOT_MNT/etc/init/${job}.conf"
		if [ -f "$file" ]; then
			sed -i '/^start /!d' "$file"
			echo "exec true" >>"$file"
		fi
	done
}

mkdir -p "$NEWROOT_MNT" "$ROOTFS_MNT"
mount -t tmpfs tmpfs "$NEWROOT_MNT" -o "size=1024M" || fail "Failed to mount tmpfs"
determine_rootfs || fail "Could not determine rootfs"
mount -o ro "$ROOTFS_DEV" "$ROOTFS_MNT" || fail "Failed to mount rootfs $ROOTFS_DEV"
initsplash() {
trap 'printf "\033[?25h"; exit' EXIT
printf "\033[?25l\033[2J\033[H"
printf "${COLOR_GREEN_B}"
echo "               _____   _    __  __                "
echo "              |_   _| / \   \ \/ /                "
echo "                | |  / _ \   \  /                 "
echo "                | | / ___ \  /  \                 "
echo "                |_|/_/   \_\/_/\_\                "
echo "   _____ __     __ _     ____  ___  ___   _   _   "
echo "  | ____|\ \   / // \   / ___||_ _|/ _ \ | \ | |  "
echo "  |  _|   \ \ / // _ \  \___ \ | || | | ||  \| |  "
echo "  | |___   \ V // ___ \  ___) || || |_| || |\  |  "
echo "  |_____|   \_//_/   \_\|____/|___|\___/ |_| \_|  "                                        
printf "${COLOR_RESET}"
echo "        The IRS is finding your location..."
echo -e "      https://github.com/SSU-Development/IRS\n"
printf "\033[?25h"
}

echo "Copying the Rootfs"
pv_dircopy "$ROOTFS_MNT" "$NEWROOT_MNT"
umount "$ROOTFS_MNT"
SKIP_SH1MMER_PATCH=0
echo -e "\nPatching new root..."
printf "${COLOR_BLACK_B}"
/bin/patch_new_root.sh "$NEWROOT_MNT" "$STATEFUL_DEV"
[ "$SKIP_SH1MMER_PATCH" -eq 0 ] && patch_new_root_sh1mmer
printf "${COLOR_RESET}\n"
if [ "$SKIP_SH1MMER_PATCH" -eq 0 ]; then
	echo "Copying IRS files"
	pv_dircopy "$STATEFUL_MNT/root/noarch" "$NEWROOT_MNT" || :
	pv_dircopy "$STATEFUL_MNT/root/$ARCHITECTURE" "$NEWROOT_MNT" || :
	echo ""
fi
umount "$STATEFUL_MNT"

cat <<EOF >/bin/sh1mmer_switch_root
#!/bin/busybox sh

if [ \$\$ -ne 1 ]; then
	echo "No PID 1. Abort."
	exit 1
fi

BASE_MOUNTS="/sys /proc /dev"
move_mounts() {
	# copied from https://chromium.googlesource.com/chromiumos/platform/initramfs/+/54ea247a6283e7472a094215b4929f664e337f4f/factory_shim/bootstrap.sh#302
	echo "Moving \$BASE_MOUNTS to $NEWROOT_MNT"
	for mnt in \$BASE_MOUNTS; do
		# \$mnt is a full path (leading '/'), so no '/' joiner
		mkdir -p "$NEWROOT_MNT\$mnt"
		mount -n -o move "\$mnt" "$NEWROOT_MNT\$mnt"
	done
	echo "Done."
}
move_mounts
echo "exec switch_root"
echo "this shouldn't take more than a few seconds"
exec switch_root "$NEWROOT_MNT" /sbin/quarts -v --default-console output || :
EOF
chmod +x /bin/sh1mmer_switch_root

stty echo || :
clear
initsplash
echo "sleeping for test"
exec sh1mmer_switch_root || :