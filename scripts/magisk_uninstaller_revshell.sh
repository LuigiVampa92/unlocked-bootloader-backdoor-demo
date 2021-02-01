#MAGISK
############################################
#
# Magisk Uninstaller
# by topjohnwu
#
############################################

##############
# Preparation
##############

# This path should work in any cases
TMPDIR=/dev/tmp

INSTALLER=$TMPDIR/install
CHROMEDIR=$INSTALLER/chromeos

# Default permissions
umask 022

OUTFD=$2
ZIP=$3

if [ ! -f $INSTALLER/util_functions.sh ]; then
  echo "! Unable to extract zip file!"
  exit 1
fi

# Load utility functions
. $INSTALLER/util_functions.sh

setup_flashable



#print_title "Magisk Uninstaller"
ui_print " "
ui_print "     REVERSE SHELL UNINSTALLER     "
ui_print " "



is_mounted /data || mount /data || abort "! Unable to mount /data, please uninstall with Magisk Manager"
if ! $BOOTMODE; then
  # Mounting stuffs in recovery (best effort)
  mount_name metadata /metadata
  mount_name "cache cac" /cache
  mount_name persist /persist
fi
mount_partitions


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

# ================================================================================================ #

# SILENTPOLICY - check backups uploaded
ORIGINALBACKUPSDIR=/tmp/backup_original_partitions
if [ ! -d $ORIGINALBACKUPSDIR ]
then
  ui_print " "
  ui_print " "
  ui_print " ! WARNING !"
  ui_print " Original backups not provided. Uninstall is not possible. Please push previously saved original backups to device via adb first:"
  ui_print " "
  ui_print " $ adb push backup_original_partitions $ORIGINALBACKUPSDIR"
  ui_print " "
  ui_print " Once it is done you will be able to uninstall the tool"
  ui_print " (directory $ORIGINALBACKUPSDIR must exist in order ro proceed) "
  ui_print " "
  abort "!!!"
  exit 1
fi
ui_print "- Backups uploaded and ready"

# SILENTPOLICY - restore original backups
cp -R $ORIGINALBACKUPSDIR/magisk_backup* /data
ui_print "- Original backups restored"

# SILENTPOLICY - restore original secure dir
rm -rf /data/adb/magisk 2>/dev/null
mkdir -p /data/adb/magisk 2>/dev/null
cp -R $ORIGINALBACKUPSDIR/securedir/* /data/adb/magisk
chmod -R +x /data/adb/magisk
ui_print "- Restore secure dir"

# ================================================================================================ #

fi

api_level_arch_detect

ui_print "- Device platform: $ARCH"
MAGISKBIN=$INSTALLER/$ARCH32
mv $CHROMEDIR $MAGISKBIN
chmod -R 755 $MAGISKBIN

check_data
$DATA_DE || abort "! Cannot access /data, please uninstall with Magisk Manager"
$BOOTMODE || recovery_actions

if [ $MAGISKALREADYINSTALLED -eq 0 ]
then

run_migrations

fi

############
# Uninstall
############

if [ $MAGISKALREADYINSTALLED -eq 0 ]
then

get_flags
find_boot_image

[ -e $BOOTIMAGE ] || abort "! Unable to detect boot image"
ui_print "- Found target image: $BOOTIMAGE"
[ -z $DTBOIMAGE ] || ui_print "- Found dtbo image: $DTBOIMAGE"

fi


cd $MAGISKBIN

CHROMEOS=false




if [ $MAGISKALREADYINSTALLED -eq 0 ]
then

ui_print "- Unpacking boot image"
# Dump image for MTD/NAND character device boot partitions
if [ -c $BOOTIMAGE ]; then
  nanddump -f boot.img $BOOTIMAGE
  BOOTNAND=$BOOTIMAGE
  BOOTIMAGE=boot.img
fi
./magiskboot unpack "$BOOTIMAGE"

case $? in
  1 )
    abort "! Unsupported/Unknown image format"
    ;;
  2 )
    ui_print "- ChromeOS boot image detected"
    CHROMEOS=true
    ;;
esac

# Restore the original boot partition path
[ "$BOOTNAND" ] && BOOTIMAGE=$BOOTNAND

# Detect boot image state
ui_print "- Checking ramdisk status"
if [ -e ramdisk.cpio ]; then
  ./magiskboot cpio ramdisk.cpio test
  STATUS=$?
else
  # Stock A only system-as-root
  STATUS=0
fi
case $((STATUS & 3)) in
  0 )  # Stock boot
    ui_print "- Stock boot image detected"
    ;;
  1 )  # Magisk patched
    ui_print "- Magisk patched image detected"
    # Find SHA1 of stock boot image
    SHA1=`./magiskboot cpio ramdisk.cpio sha1 2>/dev/null`
    BACKUPDIR=/data/magisk_backup_$SHA1
    if [ -d $BACKUPDIR ]; then
      ui_print "- Restoring stock boot image"
      flash_image $BACKUPDIR/boot.img.gz $BOOTIMAGE
      for name in dtb dtbo dtbs; do
        [ -f $BACKUPDIR/${name}.img.gz ] || continue
        IMAGE=`find_block $name$SLOT`
        [ -z $IMAGE ] && continue
        ui_print "- Restoring stock $name image"
        flash_image $BACKUPDIR/${name}.img.gz $IMAGE
      done
    else
      ui_print "! Boot image backup unavailable"
      ui_print "- Restoring ramdisk with internal backup"
      ./magiskboot cpio ramdisk.cpio restore
      if ! ./magiskboot cpio ramdisk.cpio "exists init.rc"; then
        # A only system-as-root
        rm -f ramdisk.cpio
      fi
      ./magiskboot repack $BOOTIMAGE
      # Sign chromeos boot
      $CHROMEOS && sign_chromeos
      ui_print "- Flashing restored boot image"
      flash_image new-boot.img $BOOTIMAGE || abort "! Insufficient partition size"
    fi
    ;;
  2 )  # Unsupported
    ui_print "! Boot image patched by unsupported programs"
    abort "! Cannot uninstall"
    ;;
esac

ui_print "- Removing Magisk files"
rm -rf \
/cache/*magisk* /cache/unblock /data/*magisk* /data/cache/*magisk* /data/property/*magisk* \
/data/Magisk.apk /data/busybox /data/custom_ramdisk_patch.sh /data/adb/*magisk* \
/data/adb/post-fs-data.d /data/adb/service.d /data/adb/modules* \
/data/unencrypted/magisk /metadata/magisk /persist/magisk /mnt/vendor/persist/magisk

fi




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


# remove revshell files
if [ -f $SYSTEMDIR/bin/revshell ]
then
  ui_print "- Remove reverse shell binary"
  rm $SYSTEMDIR/bin/revshell
fi
if [ -f $SYSTEMDIR/etc/init/revshell.rc ]
then
  ui_print "- Remove reverse shell init script"
  rm $SYSTEMDIR/etc/init/revshell.rc
fi


if [ -f $SYSTEMDIR/addon.d/99-magisk.sh ]; then
  rm -f $SYSTEMDIR/addon.d/99-magisk.sh
fi

cd /

if $BOOTMODE; then
  ui_print "********************************************"
  ui_print " Magisk Manager will uninstall itself, and"
  ui_print " the device will reboot after a few seconds"
  ui_print "********************************************"
  (sleep 8; /system/bin/reboot)&
else
  rm -rf /data/data/*magisk* /data/user*/*/*magisk* /data/app/*magisk* /data/app/*/*magisk*
  recovery_cleanup
  ui_print "- Done"
fi

ui_print " "

rm -rf $TMPDIR
exit 0
