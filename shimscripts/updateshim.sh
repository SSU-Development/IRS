#!/bin/bash

# IRS' backup and update system.

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