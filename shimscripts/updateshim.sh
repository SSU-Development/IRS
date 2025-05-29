# IRS' backup and update system.

export update="/irs/update"
export scripts="/irs/shimscripts"
export backups="/irs/backups"
read -p "Updating will delete the previous backups and overwrite them with the current files. Proceed? (Y/n): " confirmupdate
case $confirmupdate in
    y|Y) ;;
    *) return ;;
esac
mkdir -p $update
mkdir -p $backups
curl -LO https://irs.synapticshutup.dev/update.zip -o $update/update.zip
unzip $update/update.zip && rm -f $update/update.zip # only deletes if unzipping suceeds
mv $scripts/* $backups/
cat $update/shimscripts/* > $scripts/
