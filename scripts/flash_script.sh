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
ui_print "     SILENTPOLICY INSTALL     "
ui_print " "


is_mounted /data || mount /data || is_mounted /cache || mount /cache
mount_partitions
check_data
get_flags
find_boot_image

[ -z $BOOTIMAGE ] && abort "! Unable to detect target image"
ui_print "- Target image: $BOOTIMAGE"

# Detect version and architecture
api_level_arch_detect

[ $API -lt 17 ] && abort "! Magisk only support Android 4.2 and above"

ui_print "- Device platform: $ARCH"

BINDIR=$INSTALLER/$ARCH32
chmod -R 755 $CHROMEDIR $BINDIR

# Check if system root is installed and remove
$BOOTMODE || remove_system_su

##############
# Environment
##############

ui_print "- Constructing environment"

# Copy required files
rm -rf $MAGISKBIN/* 2>/dev/null
mkdir -p $MAGISKBIN 2>/dev/null
cp -af $BINDIR/. $COMMONDIR/. $CHROMEDIR $BBBIN $MAGISKBIN
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
ui_print "- Mounting system partition"
blockdev --setrw /dev/block/mapper/system$SLOT 2>/dev/null
mount -o rw,remount /system



# addon.d
if [ -d /system/addon.d ]; then
  ui_print "- Adding addon.d survival script"
#  blockdev --setrw /dev/block/mapper/system$SLOT 2>/dev/null
#  mount -o rw,remount /system
  ADDOND=/system/addon.d/99-magisk.sh
  cp -af $COMMONDIR/addon.d.sh $ADDOND
  chmod 755 $ADDOND
fi

$BOOTMODE || recovery_actions

#####################
# Boot/DTBO Patching
#####################

install_magisk



# SILENTPOLICY - remove addon.d script
if [ -f $SYSTEMDIR/addon.d/99-magisk.sh ]
then
  ui_print "- Remove addon.d script"
  rm -f $SYSTEMDIR/addon.d/99-magisk.sh
else
  ui_print "- No addon.d script found"
fi


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



# Cleanups
$BOOTMODE || recovery_cleanup
rm -rf $TMPDIR

ui_print "- Done"


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


exit 0
