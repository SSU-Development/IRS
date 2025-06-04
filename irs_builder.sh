#!/usr/bin/env bash

# MASSIVE credits to xmb9 for the initial file this came from.

COLOR_RESET="\033[0m"
COLOR_BLACK_B="\033[1;30m"
COLOR_RED_B="\033[1;31m"
COLOR_GREEN_B="\033[1;32m"
COLOR_YELLOW_B="\033[1;33m"
COLOR_BLUE_B="\033[1;34m"
COLOR_MAGENTA_B="\033[1;35m"
COLOR_PINK_B="\x1b[1;38;2;235;170;238m"
COLOR_CYAN_B="\033[1;36m"

IMAGE=$1
SCRIPT_DIR=$(dirname "$0")
SCRIPT_DIR=${SCRIPT_DIR:-"."}
. "$SCRIPT_DIR/wax_common.sh"

[ -z "$IMAGE" ] && fail "Specify a SH1MMER Legacy image (Feb 2024+): irs_builder.sh board.bin"
[ "$EUID" -ne 0 ] && fail "Please run as root."
command -v git &>/dev/null || fail "Please install git."

cleanup() {
    [ -d "$MNT_SH1MMER" ] && umount "$MNT_SH1MMER" && rmdir "$MNT_SH1MMER"
    [ -n "$LOOPDEV" ] && losetup -d "$LOOPDEV" || :
    trap - EXIT INT
}

check_raw_shim() {
    log_info "Confirming SH1MMER Legacy image..."
    CGPT="$SCRIPT_DIR/lib/$ARCHITECTURE/cgpt"
    chmod +x "$CGPT"
    "$CGPT" find -l SH1MMER "$LOOPDEV" &>/dev/null || fail "Use a SH1MMER Legacy image! Other images cannot evade taxes."
    log_info "SH1MMER Legacy image detected, tax evading..."
}

patch_sh1mmer() {
    log_info "Downloading Linux Firmware..."
    [ ! -d "linux-firmware" ] && git clone --depth=1 https://chromium.googlesource.com/chromiumos/third_party/linux-firmware

    log_info "Creating IRS images partition ($(format_bytes "$SH1MMER_PART_SIZE"))"
    local sector_size
    sector_size=$(get_sector_size "$LOOPDEV")
    cgpt_add_auto "$IMAGE" "$LOOPDEV" 5 $((SH1MMER_PART_SIZE / sector_size)) -t data -l IRS_FILES
    mkfs.ext2 -F -b 4096 -L IRS_FILES "${LOOPDEV}p5"
    safesync
    suppress sgdisk -e "$IMAGE" 2>&1 | sed 's/\a//g'

    MNT_SH1MMER=$(mktemp -d)
    MNT_IRS=$(mktemp -d)
    mount "${LOOPDEV}p1" "$MNT_SH1MMER"

    log_info "Copying payloads..."
    mv "$MNT_SH1MMER/root/noarch/usr/sbin/sh1mmer_main.sh" "$MNT_SH1MMER/root/noarch/usr/sbin/sh1mmer_main_old.sh"
    cp shimscripts/startirs.sh "$MNT_SH1MMER/root/noarch/usr/sbin/sh1mmer_main.sh"
    cp shimscripts/init.sh "$MNT_SH1MMER/bootstrap/noarch/init_sh1mmer.sh"

    mkdir -p "$MNT_SH1MMER/root/noarch/sbin/"
    cp quarts "$MNT_SH1MMER/root/noarch/sbin/quarts"
    cp build/utilities/growpart.sh "$MNT_SH1MMER/root/noarch/usr/sbin/growpart"
    chmod -R +x "$MNT_SH1MMER"

    umount "$MNT_SH1MMER"
    rmdir "$MNT_SH1MMER"

    mount "${LOOPDEV}p5" "$MNT_IRS"
    log_info "Creating directories..."
    mkdir -p "$MNT_IRS"/{shims,shimscripts,recovery,payloads,firmware,binaries}

    cp -r "$SCRIPT_DIR/payloads/"* "$MNT_IRS/payloads/"
    cp -r "$SCRIPT_DIR/binaries/"* "$MNT_IRS/binaries/"
    cp -r "$SCRIPT_DIR/shimscripts/"* "$MNT_IRS/shimscripts/"
    cp -r "$SCRIPT_DIR/linux-firmware/"* "$MNT_IRS/firmware/"
    touch "$MNT_IRS/.IMAGES_NOT_YET_RESIZED"
    chmod 777 "$MNT_IRS"/*

    safesync
    umount "$MNT_IRS"
    rmdir "$MNT_IRS"
}

FLAGS_sh1mmer_part_size=580M

if [ -b "$IMAGE" ]; then
    log_info "Image is a block device, tax evasion may be terrible."
else
    check_file_rw "$IMAGE" || fail "$IMAGE is not valid or writable."
    check_slow_fs "$IMAGE"
fi

check_gpt_image "$IMAGE" || fail "$IMAGE is not GPT or is corrupted"
SH1MMER_PART_SIZE=$(parse_bytes "$FLAGS_sh1mmer_part_size") || fail "Invalid size '$FLAGS_sh1mmer_part_size'"

dd if=/dev/zero bs=1M of="$IMAGE" conv=notrunc oflag=append count=100
suppress sgdisk -e "$IMAGE" 2>&1 | sed 's/\a//g'

log_info "Correcting GPT errors"
suppress fdisk "$IMAGE" <<< "w"

log_info "Creating loop device"
LOOPDEV=$(losetup -f)
losetup -P "$LOOPDEV" "$IMAGE"
safesync

check_raw_shim
safesync

trap 'cleanup; exit' EXIT
trap 'echo Abort.; cleanup; exit' INT

patch_sh1mmer
safesync

losetup -d "$LOOPDEV"
safesync
suppress sgdisk -e "$IMAGE" 2>&1 | sed 's/\a//g'

log_info "Done. Have fun!"

echo -e "${COLOR_MAGENTA_B}Credits"
echo -e "${COLOR_PINK_B}Sophia${COLOR_RESET}: The lead developer of IRS, Figured out wifi"
echo -e "${COLOR_YELLOW_B}Synaptic${COLOR_RESET}: Emotional Support"
echo -e "${COLOR_CYAN_B}Simon${COLOR_RESET}: Brainstormed how to do wifi, helped with dhcpcd"
echo -e "${COLOR_BLUE_B}kraeb${COLOR_RESET}: QoL improvements and initial idea"
echo -e "${COLOR_GREEN_B}xmb9${COLOR_RESET}: The name, helping with builder and init and part of shimbooting"
echo -e "${COLOR_RED_B}Mariah Carey${COLOR_RESET}: Bugtesting wifi"
echo -e "AC3: Literally nothing"
echo -e "Rainestorme: Murkmod's version finder"

trap - EXIT
