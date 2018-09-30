# Linux Embedded
This paper demonstrates how to use buildroot to configure a secured embedded system using a Rasperry Pi 3.
In order to download buildroot, go to the [following page](https://buildroot.org/download.html). We suggest you take the latest stable release.

## Basic configuration
First, tell buildroot to use the default raspberrypi3 configuration :
```
$ make raspberrypi3_defconfig
```

Then start the configuration UI :
```
$ make menuconfig
```

Do the following changes :
- Use the external toolchain (Linero ARM).
- Use a ramfs filesystem, it will load the system (on the sdcard) into memory. If a change is made during runtime, everything will be lost at reboot.
- Don't use the ext root filesystem from the sdcard (both from the menuconfig and the `post-image.sh` script. We use ramfs so there's no need for it.
- Define a root password.
- Add the `dropbear` package to have an SSH server running.

Build the image for the first time :
```
$ make BR2_JLEVEL=4
```
The `BR2_JLEVEL` option tells buildroot to use multiple CPU cores to compile packages.


## Flash the system
Buildroot will output a system image named `sdcard.img` in the following folder : `output/images`.

Check the sdcard device location using lsblk :
```
$ $ lsblk
NAME                                          MAJ:MIN RM   SIZE RO TYPE  MOUNTPOINT
sda                                             8:0    0 465,8G  0 disk  
├─sda1                                          8:1    0   453G  0 part  
│ └─luks-791b8f35-23a1-41ad-a2c2-d1f68caf3bd4 254:0    0   453G  0 crypt /
└─sda2                                          8:2    0  12,8G  0 part  
  └─luks-4375caf9-481c-4f60-8e33-a70c27f1c2d4 254:1    0  12,8G  0 crypt [SWAP]
sdb                                             8:16   1  14,5G  0 disk  
└─sdb1                                          8:17   1    32M  0 part
```
As you can see, the 14,5GiB storage is the sdcard, it's `/dev/sdb`.

Flashing the system image is as simple as :
```
$ sudo dd if=output/images/sdcard.img of=/dev/sdb && sync
```

The `sync` command will ensure that buffered output will be written to the sdcard. Just to be sure it's safe to remove the sdcard from the computer.

## Overlay configuration
In order to overwrite configuration files, buildroot comes with a mechanism called `overlay` which does exactly that.
First, we specify in the `menuconfig` the path to our overlay folder, which will be the following relative path : `board/raspberrypi3/overlay/`.
Then, to test if it's working, we create a `version` file containing `1.0` in that overlay folder.
We `make` ~~America great~~ the projet again, plug the sdcard into our raspberry, turn it on, and check the existence of `/version` using a physical keyboard and a display monitor.

## Network configuration
Now that we have a working overlay, we can overwrite the network configuration in order to give our raspberry a static IP address.


## Upgrade through network


### Flash whole sdcard
sudo dd

### Flash specific files
We will create a custom script

## Kernel hardening

