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
$ lsblk
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
$ ssh-keygen -b 4096
```

Then copy the public key in the right folder of the overlay :
```
$ cp ~/.ssh/buildroot.pub board/raspberrypi3/overlay/root/.ssh/authorized_keys
```

`make` your project, flash your sdcard, and you should be able to ssh into the pi using the identity file :
```
$ ssh -i ~/.ssh/buildroot root@192.168.0.42
The authenticity of host '192.168.0.42 (192.168.0.42)' can't be established.
ECDSA key fingerprint is SHA256:LJHExFkbAg5q90oB/ZZzAPNDao32dsWu4KeGYL6iLwg.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.0.42' (ECDSA) to the list of known hosts.
# id
uid=0(root) gid=0(root) groups=0(root),10(wheel)
```

If you have a warning message, you might have to remove the last entry of your `~/.ssh/known_hosts` file because the identity (the ssh host keys) of the pi changes every time you flash
a new image and boot for the first time again.
In the future, to avoid having to remove the entry in `known_hosts` everytime, we will use `-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no` as parameter to ssh.

## Upgrade through network
Now that we can successfuly communicate with our raspberry, it would be great if we were able to flash the system remotely without having to unplug the sdcard, flash it from our computer,
plug it back to the raspberry and turn it on.
Such a thing is only possible because we are using a ramfs filesystem, it wouldn't be possible to hotpatch the sdcard if we were using it. But fortunatly we are not using it because the
whole system is loaded in RAM. Once the sdcard is patched, all we have to do to see the changes is reboot the raspberry.

We will see two different ways of altering our system remotly.

### Flash the whole sdcard
This method is the more drastic one, it will write the entire system image on the sdcard. It can be really time consuming depending on how big your system image is.
All we have to do is transfer the new sdcard.img to the pi using `scp` and execute `dd` remotly using `ssh`.

We write a small script to automate the task for us : see ![upgrade.sh](https://github.com/ShellCode33/SecuredEmbeddedSystem/blob/master/upgrade.sh)

We change the version file, create the system image with `make`, and execute our script to see if it worked :
```
$ ./upgrade.sh 
Usage: ./upgrade.sh [REMOTE IP] [SSH PRIVATE KEY] [IMAGE PATH]
$ ./upgrade.sh 192.168.0.42 ~/.ssh/buildroot output/images/sdcard.img
The host is currently running the following version : 1.2
Transfering system image to remote system...
sdcard.img                  100%   32MB   2.1MB/s   00:15
Writing system image on sdcard...
Rebooting remote system, waiting for it to be up...
The host is currently running the following version : 1.3
```

### Flash the zImage
The purpose of this is only to demonstrate that we are not forced to flash the whole sdcard. We can also replace the zImage (which contains the kernel and the initramfs). It enables us to
change the initial filesystem (add/remove/edit files) and update our remote sdcard without having to transfer all the other stuff the system image contains.
That other stuff includes (among other things) the `bootcode.bin`, the `start.elf` which are responsible for the loading of the system. The kernel's parameters which are in the `cmdline.txt`, etc.

We upgraded the script in order to do that.

```
$ ./upgrade.sh 192.168.0.42 ~/.ssh/buildroot output/images/zImage
Upgrading zImage only...
The host is currently running the following version : 1.3
Transfering system image to remote system...
zImage                      100%   24MB   1.8MB/s   00:13
Writing to sdcard...
Rebooting remote system, waiting for it to be up...
The host is currently running the following version : 1.4
```
As you can see, only 24MB are transmitted instead of the 32MB of our system image. At this scale, it's not a major improvement, we'll only gain 1 second or 2, but it could become more interesting with bigger project.

What our script does is that it detects the file type (using the `file` command) you want to flash and does the proper operation.

```bash
# If the file is a zImage
if echo "$FILE_TYPE" | grep zImage &> /dev/null
then
    echo "Upgrading zImage only..."
    upgrade_command="mkdir /tmp/mnt; mount ${REMOTE_SDCARD_DEVICE}${PART_NUM} /tmp/mnt; mv /tmp/zImage /tmp/mnt/"

# If the file is a system image
elif echo "$FILE_TYPE" | grep boot &> /dev/null
then
    echo "Upgrading the whole image..."
    upgrade_command="dd if=/tmp/sdcard.img of='${REMOTE_SDCARD_DEVICE}'"

else
    echo "Unknown file type. Please provide a system image or a zImage."
    exit 42
fi
```

If it's a system image we want to flash, we perform a `dd`, if it's a `zImage`, we just replace the existing one on the sdcard's partition.

## Manage version automatically
First, delete `board/raspberrypi3/overlay/version` and `output/target/version`.

Then append the following to the `board/raspberrypi3/post-build.sh` script :
```bash
if [ -e ${TARGET_DIR}/version ]; then
    CURRENT_VERSION="$(cat ${TARGET_DIR}/version)"
    NEW_VERSION=$((CURRENT_VERSION+1))
    echo ${NEW_VERSION} > "${TARGET_DIR}/version"
else
    echo 1 > "${TARGET_DIR}/version"
fi
```
It will just create/update the version number of the build.

## Give a purpose to our board
That's wonderful, we have an embedded system that we can flash remotly, but it's pointless for now because our raspberry doesn't offer any service.
So we will try here to give a purpose to our raspberry by making it a remote game machine. We will install [nInvaders](http://ninvaders.sourceforge.net/) to be able to play the Invaders game in the CLI through the network.

### Looking at nInvaders
First, download [the source code](https://sourceforge.net/projects/ninvaders/files/), we will tell buildroot to compile it for us and to install it in the initial ramfs.
The downloaded file is a compressed tar archive, we extract it and look at the `Makefile` :
```make
CC=gcc
CFLAGS=-O3 -Wall
LIBS=-lncurses

CFILES=globals.c view.c aliens.c ufo.c player.c nInvaders.c
HFILES=globals.h view.h aliens.h ufo.h player.h nInvaders.h
OFILES=globals.o view.o aliens.o ufo.o player.o nInvaders.o
all:            nInvaders

nInvaders:      $(OFILES) $(HFILES)
                $(CC) $(LDFLAGS) -o$@ $(OFILES) $(LIBS)

.c.o:
                $(CC) -c  -I. $(CFLAGS) $(OPTIONS) $<
clean:
                rm -f nInvaders $(OFILES)
```
We can see the package uses the `ncurses` library. It's a dependency we will also have to install.

### Create a buildroot package
You can find how to create a buildroot package [here](https://buildroot.org/downloads/manual/manual.html#adding-packages) on the online documentation.

Let's create a directory for our package :
```
$ mkdir package/ninvaders
```

And we create a basic config file :
```
$ cat package/ninvaders/Config.in
config BR2_PACKAGE_NINVADERS
        bool "nInvaders"
        help
          Ever wanted to play space invaders when you can't find a GUI?
          Now you can!
```

The online doc tells us :
```
Use a select type of dependency for dependencies on libraries. These dependencies are generally not obvious and it therefore make sense to have the kconfig system ensure that the dependencies are selected.
```

So just before the `help` statement in the `Config.in`, we will add a `select` statement to tell buildroot that by selecting the `nInvaders` package, you also have to select the `ncurses`
library. This ensures that when we install nInvaders, all requirements are met.

We first have to find the Kconfig name of ncurses, it can be done easily by looking at `package/ncurses/Config.in`.
So before the `help` statement, we add :
```
select BR2_PACKAGE_NCURSES
```

In order to tell buildroot to use that config, we have to edit the parent `Config.in` in the `package` folder.
We add the package under the `Games` category, for obvious reasons :)
```
$ grep Games package/Config.in -A 11
menu "Games"
        source "package/chocolate-doom/Config.in"
        source "package/doom-wad/Config.in"
        source "package/flare-engine/Config.in"
        source "package/flare-game/Config.in"
        source "package/gnuchess/Config.in"
        source "package/lbreakout2/Config.in"
        source "package/ltris/Config.in"
        source "package/lugaru/Config.in"
        source "package/minetest/Config.in"
        source "package/minetest-game/Config.in"
        source "package/ninvaders/Config.in"
```

Start a `make menuconfig` nInvaders should be there under `Target packages -> Games`.
Now if you tick nInvaders and you go under `Target packages -> Libraries -> Text and terminal handling`, you should see ncurses ticked and in a special state that prevents the user from unticking it (because nInvaders needs it to work).

Now we have to create a `.mk` file, it describes how the package should be downloaded, configured, built, installed, etc.
We will create a generic package because nInvaders do not use any particular build system. The doc says :
`This typically includes packages whose build system is based on hand-written Makefiles or shell scripts.`
Which is exactly the case here.
You can find a tutorial on the online documentation [here](https://buildroot.org/downloads/manual/manual.html#generic-package-tutorial).

Here's what our `ninvaders.mk` file looks like :
```make
################################################################################
#
# nInvaders
#
################################################################################

NINVADERS_VERSION = 0.1.1
NINVADERS_SOURCE = ninvaders-$(NINVADERS_VERSION).tar.gz
NINVADERS_SITE = https://downloads.sourceforge.net/project/ninvaders/ninvaders/$(NINVADERS_VERSION)
NINVADERS_DEPENDENCIES = ncurses

define NINVADERS_BUILD_CMDS
    $(MAKE) $(TARGET_CONFIGURE_OPTS) -C $(@D) all
endef

define NINVADERS_INSTALL_TARGET_CMDS
    $(INSTALL) -D -m 0755 $(@D)/nInvaders $(TARGET_DIR)/usr/bin
endef

$(eval $(generic-package))
```

Then we upgrade our version file, do a `make BR2_JLEVEL=4`, and in its output, we can find the following steps :
```
>>> ninvaders 0.1.1 Downloading
>>> ninvaders 0.1.1 Extracting
>>> ninvaders 0.1.1 Patching
>>> ninvaders 0.1.1 Configuring
>>> ninvaders 0.1.1 Building
>>> ninvaders 0.1.1 Installing to target
```

In the `Downloading` step, we find the following :
```
Location: https://netix.dl.sourceforge.net/project/ninvaders/ninvaders/0.1.1/ninvaders-0.1.1.tar.gz
[...]
Resolving netix.dl.sourceforge.net (netix.dl.sourceforge.net)... 87.121.121.2
Connecting to netix.dl.sourceforge.net (netix.dl.sourceforge.net)|87.121.121.2|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 31275 (31K) [application/x-gzip]
Saving to: ‘/home/shellcode/Tools/buildroot-rpi3/output/build/.ninvaders-0.1.1.tar.gz.zytqI9/output’
```

So buildroot successfuly downloaded `nInvaders` from the provided URL in the `ninvaders.mk`.
We can now upgrade the zImage with our `upgrade.sh` script :
```
$ ./upgrade.sh 192.168.0.42 ~/.ssh/buildroot output/images/zImage
Upgrading zImage only...
The host is currently running the following version : 1.4
Transfering system image to remote system...
zImage                      100%   24MB   2.3MB/s   00:10
Writing to sdcard...
Rebooting remote system, waiting for it to be up...
The host is currently running the following version : 1.5
```

If you ssh into your raspberry, you should be able to use the `nInvaders` command and play.

### Make nInvaders playable remotely
SSH is not really convenient to expose a game on the network, because the user has to log in first. It would be great to be able to initiate a connection on a specific port of our device and being able to play the game immediatly.
So we will create a telnet server using `telnetd` which will start nInvader when we connect to it.
In order to install it, we will edit busybox's configuration. To do so, perform the following command :
```
$ make busybox-menuconfig
```

And under `Network utilities`, tick `telnetd`, `make` and upgrade the sdcard again.
Once the changes have been applied, you should be able to connect to your raspberry using telnet :
```
$ telnet 192.168.0.42
Trying 192.168.0.42...
Connected to 192.168.0.42.
Escape character is '^]'.

buildroot login:
```

We are able to gain a remote shell like SSH. Except that telnet is totally insecure, the communications aren't encrypted. Therefore it shouldn't be used to obtain a shell. However, it can be really great to access our game !
The telnet server daemon is started at boot thanks to the script `/etc/init.d/S50telnet` :
```bash
#!/bin/sh
#
# Start telnet....
#

TELNETD_ARGS=-F
[ -r /etc/default/telnet ] && . /etc/default/telnet

start() {
      printf "Starting telnetd: "
      start-stop-daemon -S -q -m -b -p /var/run/telnetd.pid \
                        -x /usr/sbin/telnetd -- $TELNETD_ARGS
      [ $? = 0 ] && echo "OK" || echo "FAIL"
}

stop() {
        printf "Stopping telnetd: "
        start-stop-daemon -K -q -p /var/run/telnetd.pid \
                          -x /usr/sbin/telnetd
        [ $? = 0 ] && echo "OK" || echo "FAIL"
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart|reload)
        stop
        start
        ;;
  *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
esac

exit $?
```

As we can see in this script, `/usr/sbin/telnetd` is started and its arguments are stored in the `$TELNETD_ARGS`.

Here's the help of that telnet server :
```
BusyBox v1.29.2 (2018-09-27 18:10:08 CEST) multi-call binary.

Usage: telnetd [OPTIONS]

Handle incoming telnet connections

        -l LOGIN        Exec LOGIN on connect
        -f ISSUE_FILE   Display ISSUE_FILE instead of /etc/issue
        -K              Close connection as soon as login exits
                        (normally wait until all programs close slave pty)
        -p PORT         Port to listen on
        -b ADDR[:PORT]  Address to bind to
        -F              Run in foreground
        -i              Inetd mode
        -w SEC          Inetd 'wait' mode, linger time SEC
        -S              Log to syslog (implied by -i or without -F and -w)
```

So all we have to do is change the login program (thanks to `-l`) like that :
```bash
TELNETD_ARGS="-F -l /usr/bin/nInvaders"
```

We restart the telnet daemon :
```
# /etc/init.d/S50telnet restart
```

And now when we telnet the pi, the game starts :)

We have to make thoses changes permanent, we will use buildroot's overlay to overwrite telnet's config. I will not explain that once again, we've done that already previously.
Do not forget to make your script executable in the overlay, otherwise it will not start at boot :
```
$ chmod +x board/raspberrypi3/overlay/etc/init.d/S50telnet
```
Now `make`, flash and try to telnet your pi.
Unfortunatly, the colors are not working. That's because of the `TERM` variable which by default is set to `vt102` which seems not to support colors...
So before the telnetd daemon start, we have to change the `TERM` variable to a terminal emulator which supports colors. We will use `xterm`.

Juste before the call to `start-stop-daemon` we add the following :
```
TERM=xterm
```

Rebuild and flash the zImage. The colors are now working properly when telneting the raspberry.

## Hardening
### New user
We will create a new user to run nInvaders. Currently nInvaders is started by telnetd which runs as root. nInvaders could be vulnerable and if someone were able to exploit it, he would be root on the system. That's why we create a restricted user to lower the privileges of a potential attacker who exploited the binary.

Buildroot can create that user automatically by specifying in `ninvaders.mk` the following :
```
define NINVADERS_USERS
    ninvaders -1 ninvaders -1 !=ninvaders /home - -
endef
```
Unfortunatly telnet binds the port 23 by default, but you have to be root to bind a port below 1024.
In order to allow non-root users to bind those ports, we will have to perform the following command :
```
sysctl net.ipv4.ip_unprivileged_port_start=0
```
It's a huge security issue to do that on a classic system (laptops, servers, ...) but it's totally acceptable on an embedded system because we control everything we do and there will be nobody using the system (installing programs, ...), only a specific service will be accessible from the outside.

Add the command above to the telnetd start up script `board/raspberrypi3/overlay/etc/init.d/S50telnet` just before the daemon starts.

### Firewalling
By default, the raspberry has no network limitations, if we install a package that binds a port and we didn't notice , it could be possible to hack the service behind and gain access to the system.
To be sure that no communication other than the ones we want are possible, we will use *iptables* to block everything. We only need to be able to communicate on ports 22 (SSH) and 23 (telnet ninvaders).
We will even block the outgoing traffic. It can prevent an attacker from using our embedded system to contribute to DDOS attacks for example.

First we have to enable the *iptables* package under `Target packages -> Networking applications`.

Then we have to create a script that will set iptables rules for us.
To do so, create a script called `S41iptables` containing the following :
```bash
#!/bin/bash

iptables-restore <<EOF
*filter
# By default, we drop everything, no traffic allowed.
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT DROP [0:0]

# Allow loopback
-A INPUT -i lo -j ACCEPT

# Drop invalid packages
-A INPUT -m conntrack --ctstate INVALID -j DROP

# Allow incoming connections when established already
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow outgoing traffic on existing connections
-A OUTPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow ping
-A INPUT -p icmp -j ACCEPT

# Allow new connections on SSH and Telnet ports
-A INPUT -p tcp -m tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
-A INPUT -p tcp -m tcp --dport 23 -m conntrack --ctstate NEW -j ACCEPT
COMMIT
EOF

exit $?
```
And place it in `board/raspberrypi3/overlay/etc/init.d/`. Don't forget to `chmod +x` the script.

### SSH
We decided to keep SSH running on our embedded system to still be able to provide updates. But in theory, it would be better to completely uninstall SSH and therefore, lock the device.

For a better security level with SSH we have to disable password authentication. From now, we will always connect using the SSH key. Enter the `menuconfig -> System Configuration` and untick "Enable root login with password".

### Binary protections
In the menuconfig, it is possible to enable binary protections by going to `Build-options` and then activate all three options under `*** Security Hardenning Option ***`. You should set those options to the maximum level of security unless it significantly affects the performance or throw compilation errors.

**fstack-protector** emit extra code to check for buffer overflows by adding canaries onto the stack. Setting it to ALL will protect all functions.

**RELRO (RELocation Read Only)** is a security measure which makes some binary sections read-only. Setting it to FULL will make the Global Offset Table read-only preventing from GOT overwrite attack.

**Forfity_source** add additional checks to detect buffer-overflows. Setting it to AGRESSIVE will add checks at compile-time and at run-time.
 
### Seccomp

First go in the menuconfig and tick `Target packages -> Libraries -> Other -> libseccomp`.

Download nInvaders and `make` it.
Then, in order to list which syscalls nInvaders uses, we will use `strace` and redirect its output (on stderr) into a file :
```
$ strace ./nInvaders 2> syscalls
```
Play a little to be sure all the used syscalls are listed.

The `syscalls` file will contain lines such as :
```
write(1, " / _ \\_/ // _ \\ |/ / _ `/ _  / -"..., 48) = 48
```
It means nInvaders performed a `write` syscall.

Here's a small script to parse the output file and generate the seccomp C code :
```python
# coding: utf-8

if __name__ == "__main__":

    syscalls = set()

    with open("syscalls", "r") as file:
        for line in file:
            if "(" in line:
                syscall = line.split("(")[0]
                syscalls.add(syscall)

    if len(syscalls) == 0:
        print("No syscall detected. Is it a program ??")
        exit(1)

    print("scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_KILL);")

    for syscall in syscalls:
        print(f"seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS({syscall}), 0);")

    print("seccomp_load(ctx);")
```

And here's the output :
```
$ python extract.py
scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_KILL);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(rt_sigaction), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(brk), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(mmap), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(mprotect), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(rt_sigreturn), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(fstat), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(access), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(stat), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(poll), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(openat), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(setitimer), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(munmap), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(lseek), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(read), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(close), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(execve), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(arch_prctl), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(ioctl), 0);
seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(write), 0);
seccomp_load(ctx);
```

Create a backup of nInvaders.c :
```
$ cp nInvaders.c nInvaders.c.original
```

And add the C code above at the beginning of the main function inside nInvaders.c (don't forget to include seccomp.h at the top of the file).

Then create a patch from the old and the new version of nInvaders :
```
$ diff -Naur nInvaders.c nInvaders.c.original > ninvaders.patch
```

Place the patch file in `package/ninvaders` and that's it !
Rebuild nInvaders and you're good to go !
