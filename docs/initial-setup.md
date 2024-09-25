# Initial Setup

## Preconditions
- all [required hardware](./hardware-requirements.md) is obtained
- router has [OpenWRT](https://openwrt.org/) installed and is connected to the internet
- LAN is secured by a strong WiFi encryption protocol and a strong password, or Wifi is disabled
- client PC has [Mint](https://linuxmint.com/) installed and is connected to the router by ethernet cable or WiFi
- client PC has a password manager installed, such as [KeePassXC](https://keepassxc.org/)
- node server is fully assembled with a mouse, keyboard, and monitor attached
- node server is connected to the router by ethernet cable
- node server is powered off (not just hibernating or sleeping)

## Postconditions
- node server will be running headless Ubuntu Server, with the latest firmware & software
- client PC user will be configured for secure login to the server via SSH terminal
- flash drives will have:
	- `Ubuntu Server` - the latest Ubuntu Server ISO disk image
	- `Mint` - the latest the Mint ISO disk image
	- `Data` - a single bootable FAT32 disk partition
- you will be ready to setup the Ethereum node software

## Configurable Values
This guide is written using the following configurable values:
- router IP address: `192.168.1.1`
- static IP address of the node server: `192.168.1.25`
- node server SSH port: `55522`
- node server hostname: `eth-node-mainnet`
- node server username: `coejoder`
- client PC username: `coejoder`

## Steps

### 1. Download Mint and Ubuntu Server

#### On the Client PC
- [ ] browse to the [Linux Mint download page](https://www.linuxmint.com/download.php) and download an .iso file of your choice
- [ ] plug-in a USB flash drive, launch the program `USB Image Writer`, select the .iso image, and select the flash drive.  Click `Verify` to verify the integrity of the .iso, and then click `Write`
- [ ] safely eject the flash drive, unplug it, and label it as `Mint`
- [ ] browse to the [Ubuntu Server download page](https://ubuntu.com/download/server) and download the latest .iso file
- [ ] plug-in the next flash drive and repeat same process as above using `USB Image Writer`, labeling this one as `Ubuntu Server`

### 2. Update BIOS of the Node Server
These are the steps for updating the BIOS of the `NUC10i7FNH`, the recommended node server device in [Full-Node Hardware Requirements](./hardware-requirements.md).

#### On the Client PC
- [ ] plug-in the next USB flash drive 
- [ ] wipe the drive and create a bootable `FAT32` partition:
```bash
# list all drives on the system and identify the USB flash drive
sudo fdisk -l
# e.g., /dev/xyz

# find any mounted partitions of the USB drive and unmount them
mount -l | grep /dev/xyz
# e.g., /dev/xyz1 and /dev/xyz2
sudo umount /dev/xyz1
sudo umount /dev/xyz2

# wipe the existing partitions & create a new bootable FAT32 partition
sudo fdisk /dev/xyz
# Command (m for help): o
# Command (m for help): n
# Select (default p): <Enter>
# Partition number (1-4, default 1): <Enter>
# First sector (2048-120164351, default 2048): <Enter>
# Do you want to remove the signature? [Y]es/[N]o: y
# Command (m for help): t
# Hex code or alias (type L to list all): b
# Command (m for help): a
# Command (m for help): w

# format the new partition
sudo mkfs.vfat /dev/xyz1

# safely eject the drive
sudo eject /dev/xyz
```

- [ ] unplug the flash drive and plug it back in.  It should be auto-mounted by the operating system
- [ ] browse to [BIOS & Firmware for NUC10i7FNH](https://www.asus.com/supportonly/nuc10i7fnh/helpdesk_bios/) and download the latest BIOS update
- [ ] extract the .zip file, open the extracted folder `Capsule File for BIOS Flash through F7` and copy the .CAP file to the flash drive
- [ ] safely eject the flash drive, unplug it, and label it as `Data`

#### On the Node Server
- [ ] plug the `Data` flash drive into the front USB port
- [ ] power-on the node server and immediately press <kbd>F7</kbd> repeatedly until the BIOS flash screen is displayed
- [ ] select the flash drive from the list, and select the .CAP file
- [ ] when the BIOS update is complete, shutdown the node server by holding the power button for about 12 seconds (until all lights go out), then remove the flash drive

### 3. Install Ubuntu Server

#### On the Node Server
- [ ] plug the `Ubuntu Server` flash drive into the front USB port
- [ ] power-on the node server and immediately press <kbd>F10</kbd> repeatedly until the Boot Menu appears
- [ ] select the USB flash drive from the options
- [ ] select `Try or Install Ubuntu Server`
- [ ] update the installer when prompted
- [ ] keep accepting the default options until you arrive at network configuration
- [ ] on the network configuration screen, select the `eth` adapter, choose `Edit IPv4`, choose `Manual`, then enter:
	- Subnet: `192.168.1.0/24`
	- Address: `192.168.1.25`
	- Gateway: `192.168.1.1`
	- Name servers: `192.168.1.1`
- [ ] keep accepting the default options until you arrive at storage configuration
- [ ] on the storage configuration screen, **select** `Use Entire Disk`, choose the NVMe disk, **deselect** `Setup this disk as an LVM group`, then go to the next screen
- [ ] confirm that the `Used Devices` section shows the NVMe disk with two partitions: a `FAT32` partition mounted at `/boot/efi`, and an `ext4` partition mounted at `/`, then go to next screen
- [ ] pick a username, password, and server name.  Save the password in your client PC's password manager, then go to next screen:
```
Your name: coejoder
Your server's name: eth-node-mainnet
Pick a username: coejoder
Choose a password: ********
Confirm your password: ********
```
- [ ] decline to use `Ubuntu Pro` when prompted and go to next screen
- [ ] **select**  `Install OpenSSH Server` and `Allow password authentication over SSH` and go to next screen
- [ ] decline to install additional software when prompted and go to next screen
- [ ] when installation is complete, follow the on-screen instructions. It will reboot and present a terminal command prompt.  Leave it there and begin the setup of the client PC.

### 4. SSH Configuration

#### On the Client PC
- [ ] login as the local user that will be interacting with the node server.  If this PC is your main Desktop computer, your existing user account is fine to use
- [ ] edit `/etc/hosts` and add an entry at the bottom which associates the node server's static IP address to its hostname:

```bash
sudo nano /etc/hosts

# append this entry to the file, then save and close it (ctrl+s, ctrl+x)
192.168.1.25 eth-node-mainnet
```

- [ ] try logging into the node server via SSH, entering the password for `coejoder@eth-node-mainnet` (the password chosen during Ubuntu Server installation) when prompted:

```bash
ssh coejoder@eth-node-mainnet
# Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
# coejoder@eth-node-mainnet's password: <password>

# you should now be logged into the node server `eth-node-mainnet` as `coejoder`
# logout and continue to next step (type `exit` or press `ctrl+d`)
exit
```

- [ ] simple password authentication is not secure.  Create a SSH public/private keypair secured with a passphrase and save the passphrase in your password manager:

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/eth-node-mainnet_ed25519
# Enter passphrase (empty for no passphrase): <passphrase>
# Enter same passphrase again: <passphrase>
```

- [ ] add the public key to the node server, entering the password for `coejoder@eth-node-mainnet` when prompted:

```bash
ssh-copy-id -i ~/.ssh/eth-node-mainnet_ed25519.pub coejoder@eth-node-mainnet
# coejoder@eth-node-mainnet's password: <password>
```

- [ ] create or edit `~/.ssh/config` and add a section to the bottom of the file:

```bash
nano ~/.ssh/config

# append this entry to the file, then save and close it (ctrl+s, ctrl+x)
Host eth-node-mainnet
	User coejoder
	IdentityFile ~/.ssh/eth-node-mainnet_ed25519
	IdentitiesOnly yes
	PreferredAuthentications publickey
	ForwardAgent yes
```

- [ ] try logging into the node server again via SSH, but this time without specifying the username.  Enter the SSH key passphrase when prompted:

```bash
ssh eth-node-mainnet
# coejoder@eth-node-mainnet's password: <password>

# you should be logged into the node server again
# stay logged in and continue to the next step
```

- [ ] now that secure key+passphrase authentication is working, disable password and non-passphrase key authentication and change the default SSH port as additional security measures:

```bash
sudo nano /etc/ssh/sshd_config

# find and change these options:

	#Port 22
	#PasswordAuthentication yes
	#PermitEmptyPasswords no
	
# to these:
	
	Port 55522
	PasswordAuthentication no
	PermitEmptyPasswords no

# then save and close the file (ctrl+s, ctrl+x)
```

- [ ] uninstall `cloud-init` and delete its configuration files, as it interferes with SSH settings:

```bash
sudo apt purge cloud-init
sudo rm -rf /etc/cloud/ && sudo rm -rf /var/lib/cloud/
sudo rm -f /etc/ssh/sshd_config.d/50-cloud-init.conf
```

- [ ] restart the node server

```bash
sudo reboot

# you will be kicked out as it reboots
# after a minute or so, log back in
ssh -p 55522 eth-node-mainnet
# coejoder@eth-node-mainnet's password: <password>

# you should now be logged in again
# the above ssh command is what you will use to login from now on
# for now, stay logged in and continue to the next step
```

- [ ] install the latest system updates:

```bash
sudo apt update && sudo apt upgrade -y
```

- [ ] ensure system timezone & time are correct

```bash
sudo timedatectl set-ntp on
sudo timedatectl set-timezone America/Los_Angeles
```

- [ ] shutdown the node server

```bash
sudo shutdown now
```

### 5. Finalize Initial Setup
- [ ] disconnect the mouse, keyboard, and monitor from the node server
- [ ] move the node server to its permanent home, likely near the router and UPS battery backup
- [ ] power-on the node server and try logging in from the client PC again
- [ ] logout and enjoy a refreshing beverage, you've earned it.  You are now ready to install the Ethereum node software
