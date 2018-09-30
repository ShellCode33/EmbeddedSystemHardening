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

We create the directories to the config file we want to overwrite :
```
$ mkdir -p board/raspberrypi3/overlay/etc/network
```

Then we edit the `interfaces` file to set a static IP :
```
$ vim board/raspberrypi3/overlay/etc/network/interfaces
$ cat board/raspberrypi3/overlay/etc/network/interfaces
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    pre-up /etc/network/nfs_check
    wait-delay 15
    address 192.168.0.42
    netmask 255.255.255.0
    gateway 192.168.0.1
```
The `wait-delay` statement is important because the IP address will not be set properly otherwise.

If your Raspberry is directly connected to the ethernet port of your computer, you might want to set a temporary ip address to your eth0 interface :
```
$ sudo ip addr add 192.168.0.1/24 dev eth0
```

Now install the `dropbear` package using `make menuconfig`, you can untick the `client programs` because we only need a server and we want to keep our image as small as possible.

`make` the project, flash the raspberry, and you should be able to ssh into your pi :

```
$ ssh root@192.168.0.42
The authenticity of host '192.168.0.42 (192.168.0.42)' can't be established.
ECDSA key fingerprint is SHA256:r5vN8rC+rL/K9Scyw/CYN6cHpBpcsaQljFuHYCc87po.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.0.42' (ECDSA) to the list of known hosts.
root@192.168.0.42's password: 
# cat /version
1.1
```

## Create SSH keys
To allow our future scripts to work without asking the password every single time we perform an `ssh` or `scp` command, we will generate a set of public and private keys to authenticate.

To do so, perform the following command :
```
ssh-keygen -b 4096
```

Then copy the public key in the right folder of the overlay :
```
cp ~/.ssh/buildroot.pub board/raspberrypi3/overlay/root/.ssh/authorized_keys
```

`make` your project, flash your sdcard, and you should be able to ssh into the pi using the identity file :
```
$ ssh -i ssh/id_rsa root@192.168.0.42
The authenticity of host '192.168.0.42 (192.168.0.42)' can't be established.
ECDSA key fingerprint is SHA256:LJHExFkbAg5q90oB/ZZzAPNDao32dsWu4KeGYL6iLwg.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.0.42' (ECDSA) to the list of known hosts.
# id
uid=0(root) gid=0(root) groups=0(root),10(wheel)
```

If you have a warning message, you might have to remove the last entry of your `~/.ssh/known_hosts` file because the identity of the pi changes every time you flash a new image.

## Upgrade through network
Now that we can successfuly communicate with our raspberry, it would be great if we were able to flash the system remotely without having to unplug the sdcard, flash it from our computer,
plug it back to the raspberry and turn it on.
Such a thing is only possible because we are using a ramfs filesystem, it wouldn't be possible to hotpatch the sdcard if we were using it. But fortunatly we are not using it because the
whole system is loaded in RAM. Once the sdcard is patched, all we have to do to see the changes is reboot the raspberry.

We will see two different ways of altering our system remotly.

### Flash whole sdcard
This method is the more drastic one, it will write every single byte of the sdcard. It can be really time consuming depending on how big your system image is.
All we have to do is transfer the new sdcard.img to the pi using `scp` and execute `dd` remotly using `ssh`.

We write a small script to automate the task for us : see ![full_upgrade.sh](https://github.com/ShellCode33/SecuredEmbeddedSystem/blob/master/full_upgrade.sh)

We change the version file, create the system image with `make`, and execute our script to see if it worked :
```
$ ./full_upgrade.sh 
Usage: ./full_upgrade.sh [REMOTE IP] [SSH PRIVATE KEY] [IMAGE PATH]
$ ./full_upgrade.sh 192.168.0.42 ~/.ssh/buildroot output/images/sdcard.img
The host is currently running the following version : 1.2
Transfering system image to remote system...
sdcard.img                  100%   32MB   2.1MB/s   00:15
Writing system image on sdcard...
Rebooting remote system, waiting for it to be up...
The host is currently running the following version : 1.3
```

### Flash specific files
We will create a custom script

## Kernel hardening

