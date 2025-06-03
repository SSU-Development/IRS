#!/bin/bash

# IRS' backup and update system.
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
shimupdate() {
export update="/irs/update"
export scripts="/irs/shimscripts"
export backups="/irs/backups"
export payloads="/irs/payloads"
export binaries="/irs/binaries"
    read -p "Updating will delete the previous backups and overwrite them with the current files. Proceed? (Y/n): " confirmupdate
    case $confirmupdate in
        y|Y) ;;
        *) return ;;
    esac

    mkdir -p "$update" "$backups"

    url="https://github.com/SSU-Development/IRS/archive/refs/heads/main.zip"
    path="$update/update.zip"
    echo "Downloading IRS..."
    curl -L "$url" -o "$path" 2>/dev/null
    echo "Extracting..."
    unzip -o "$path" -d "$update"
    mv "$scripts"/* "$backups/"
    mkdir -p "$scripts"
    cp -r "$update/IRS-main/shimscripts/"* "$scripts/"
    cp -r "$update/IRS-main/payloads/"* "$payloads/"
    cp -r "$update/IRS-main/binaries/"* "$binaries/"
    cp "$update/IRS-main/shimscripts/startirs.sh" "/usr/sbin/sh1mmer_main.sh"
    sync
    echo "Update complete."
}

driveupdate() {
    read -p "Are you on linux/cros? Not crostini, instructions for that in the repo. (Y/n)" linux
    case $linux in 
        n|N) echo "Please run on linux or cros devmode shell." && sleep 2 && return ;;
        *) ;;
    esac
    mkdir -p ~/IRSMOUNT
    export DRIVE='~/IRSMOUNT'
    mount /dev/disk/by-label/IRS_FILES $DRIVE # more like /dev/disk/by-label/xmb9 amiright
    export update="$DRIVE/update"
    export scripts="$DRIVE/shimscripts"
    export backups="$DRIVE/backups"
    export payloads="$DRIVE/payloads"
    export binaries="$DRIVE/binaries"
    read -p "Updating will delete the previous backups and overwrite them with the current files. Proceed? (Y/n): " confirmupdate
    case $confirmupdate in
        n|N) return ;;
        *) ;;
    esac

    mkdir -p "$update" "$backups"

    url="https://github.com/SSU-Development/IRS/archive/refs/heads/main.zip"
    path="$update/update.zip"
    echo "Downloading IRS..."
    curl -L "$url" -o "$path" 2>/dev/null
    echo "Extracting..."
    unzip -o "$path" -d "$update"
    mv "$scripts"/* "$backups/"
    mkdir -p "$scripts"
    cp -r "$update/IRS-main/shimscripts/"* "$scripts/"
    cp -r "$update/IRS-main/payloads/"* "$payloads/"
    cp -r "$update/IRS-main/binaries/"* "$binaries/"
    cp "$update/IRS-main/shimscripts/startirs.sh" "/usr/sbin/sh1mmer_main.sh"
    sync
    echo "Update complete."
}

echo "Are you in the shim itself or on an external device?"
options_install=(
    "In the shim"
    "On another device"
)

menu "Select an option (use ↑ ↓ arrows, Enter to select):" "${options_install[@]}"
install_choice=$?

case "$install_choice" in
    0) shimupdate ;;
    1) driveupdate ;;
    *) echo "Invalid choice, exiting." && exit ;;
esac
return
