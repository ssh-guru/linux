# Install Linux on Asus T100HA ##

This is a fully documented guide on how to install Arch Linux on Asus T100HA/Cherry Trail device. This guide comes WITHOUT ANY WARRANTY, use it on your own risk.


## 1. Use Arch Linux #

Download the most recent Arch Linux arch.iso from the official repository and burn it to the USB drive using the following command

> dd if=arch.iso of=/dev/sdX status=progress

On Windows you can use software like Rufus to do the same.


## 2. Prepare Installation #

Restart your device. At boot press [F2], then go to Security and then Secure Boot Menu. Choose the option 'Disabled'. This is needed to enable EFI boot for the up-to-date (unknown signed) kernel. Leave BIOS with [F10] -> [Return]. 
At reboot press [Esc] and choose the USB drive. It is going to be lsited under its model name. Start with [Enter].


### 2.1 Screen Rotation #

As you can see, the display is stuck in the portrait mode. To fix that, use the following command:

> echo 3 | sudo tee /sys/class/graphics/fbcon/rotate


### 2.2 Network #

You will need internet access in order to install Arch Linux. As the wifi is down at this stage, a ether dongle or USB tethering is a must.
After connecting the WAN (either by Ethernet or USB), you need to enable DHCP on the adapter to get the internet access. 

Run this command to get the adapter number i.e. enp20s2u4u4u4
> ip link			

Replace enpXXXXXX with your adapter number
> dhcpcd enpXXXXXX


## 3. System Setup #

Use the following commands in the exact same order to avoid mistakes

Load your keyboard settings. Look up name of the setup you need on the Internet and replace pl with it
> loadkeys pl			

etup the timezone
> timedatectl set-ntp true	

Start the disk format; use the next commands in the exact same order
> fdisk /dev/mmcblk0		

d			# Use it as many times as you need and confirm the default. It is going to delete the existing partition table
n			# Creates boot partition. Press [Enter] two times to accept the defaults and put +512M as the last parameter
t			# Sets the newly created partition as boot. Put 1 as the parameter
n			# Creates swap partition. Press [Enter] two times to accept the defaults and put +4G as the last parameter
t			# Sets the newly created partition as swap. Put 19 as the parameter
n			# Creates data partition. Press [Enter] three times to accept the defaults
w 		# Writes the changes to the partition table
Formats the partition 1 (boot) to FAT
> mkfs.fat /dev/mmcblk0p1	

Creates swap at partition 2
> mkswap /dev/mmcblk0p2	 

Formats the partition 3 (data) to ext4	
> mkfs.ext4 /dev/mmcblk0p3	

Starts swap at partition 2
> swapon /dev/mmcblk0p2	

Mounts the data partition at /mnt point
> mount /dev/mmcblk0p3 /mnt	

Creates the boot directory at /mnt
> mkdir /mnt/boot		

Mounts the boot partition at /mnt/boot
> mount /dev/mmcblk0p1 /mnt/boot 

Installs the base system on /mnt
> pacstrap /mnt base

> genfstab -U /mnt >> /mnt/etc/fstab

> arch-chroot /mnt	

At this point you should be logged in as root to the base system


### 3.1 System Configuration #

Now it's time to configure the basic settings on the system. Let's start with locale (system language)

> ln -s /usr/share/zoneinfo/Region/City /etc/localtime

Sets the hardware clock to UTC. Change the parameter to match your timezone
> hwclock --systohc --utc		

Uncomment the locale you need. Save with [Ctrl]+[O], quit with [Ctrl]+[X]
> nano /etc/locale.gen	

This will apply your selection from the command above to the system
> locale-gen					

Change en_EN.UTF-8 to your locale name	
> echo LANG=en_EN.UTF-8 > /etc/locale.conf

Change pl to your keymap name
> echo KEYMAP=pl > /etc/vconsole.conf		

Change myhostname to your desired hostname
> echo myhostname > /etc/hostname		

Insert 127.0.0.1 myhostname.localdomain myhostname (replace myhostname with your desited hostname)
> nano /etc/hosts			

Set root password
> passwd					

Confiure boot sequence
> bootctl --path=/boot install			

In the next few steps, we will apply a pernament fix to the display rotation and finish the boot configuration. First, we need to run the following command to copy the data disk UUID to the arch.conf (boot config file)

> blkid -s PARTUUID -o value /dev/mmcblk0p3 > /boot/loader/entries/arch.conf

Next, lets edit the boot configuration file

> nano /boot/loader/entries/arch.conf

and manipulate the content, so it looks like:

> title Arch Linux

> linux /vmlinuz-linux

> initrd /initramfs-linux.img

> options root=PARTUUID=XXXXXXX rw video=LVDS-1:d fbcon=rotate:3

Remember to preserve the PARTUUID (disk ID) which should already be in that file and use it to replace the XXXXXXX

Now it's time to configure the user. Replace uname with your desired username:

> useradd -m -G wheel -s /bin/bash uname

> passwd uname


### 3.2 Finish up the setup #

Installs iasl and wget
> pacman -S iasl wget		

Exits the system and goes back to the installation media
> exit	

Unmounts the /mnt from the installation media
> umount -R /mnt		

Remember to remove the installation media before the BIOS starts up
> reboot			


## 4. WLAN (wi-fi) Fix #

After the reboot, log into the system as root. Ignore any errors before the login prompt by pressing [ENTER] (it might warn you about backlight and USB drivers failure)

Copies the DSDT to dsdt.dat for easier patching
> cat /sys/firmware/acpi/tables/DSDT > dsdt.dat		

> iasl -d dsdt.dat

> nano dsdt.dsl		

Search for the following two lines and apply the changes

*DefinitionBlock ("", "DSDT", 2, "_ASUS_", "Notebook", 0x1072009) -> DefinitionBlock ("", "DSDT", 2, "_ASUS_", "Notebook", 0x107200A)*

*Device (SDHB)
{
Name (_ADR, Zero) // _ADR: Address -> Name (WADR, Zero) // _ADR: Address*

Apply the change
> iasl -tc dsdt.dsl				

Creates a directory in the kernel for the patch
> mkdir -p kernel/firmware/acpi		

Copeis the patch to the kernel folder
> cp dsdt.aml kernel/firmware/acpi			

Creates a boot note for the patch
> find kernel | cpio -H newc --create > acpi_override	

Creates a boot record for the patch
> cp acpi_override /boot				

Insert initrd /acpi_override before initrd /initramfs-linux.img
> nano /boot/loader/entries/arch.conf			

> reboot

Log back in as root and download the driver package

> wget https://android.googlesource.com/platform/hardware/broadcom/wlan/+archive/master/bcmdhd/firmware/bcm43341.tar.gz

Unpack the driver
> tar xf bcm43341.tar.gz						

Copy the driver to kernel
> cp fw_bcm43341.bin /lib/firmware/brcm/brcmfmac43340-sdio.bin		

> cp /sys/firmware/efi/efivars/nvram* /lib/firmware/brcm/brcmfmac43340-sdio.txt

Gnome or another DE is needed for the NetworkManager; accept all defaults
> pacman -S gnome gnome-extra						

> systemctl restart NetworkManager				

> systemctl restart gdm						

At this point, log into the DE using the user account you created before. The Wi-Fi icon should appear in the upper right corner of your screen.
