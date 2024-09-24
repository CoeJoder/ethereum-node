# Initial Setup
This guide will make the following assumptions.  Adjust as necessary:
- the router IP address is `192.168.1.1`
- the static IP for the node server will be `192.168.1.25`
- the username created on the node server will be `coejoder`
- the hostname of the node server will be `eth-node-mainnet`

## 1. Node Server Setup
This is the Mini PC that will be always-on.  During initial setup, you'll need a keyboard, mouse, and monitor plugged in.  Once initial setup is complete, you can remove these peripherals and move the Mini PC somewhere convenient, probably near the router and UPS battery backup.

Before beginning installation of Ubuntu Server, it is recommended to wipe the NVMe/SSD storage beforehand so that the installer will automatically configure the disk partitions.  You can do this by booting the Ubuntu Server ISO via USB and running `fdisk`, deleting any existing partitions and the partition table.  Those specifics are beyond the scope of this guide.

- [ ] ensure there is a connection from the node server to the LAN with an RJ-45 ethernet cable
- [ ] boot the latest Ubuntu Server ISO via USB and launch the installer
- [ ] decline to update the installer when prompted and go to next screen
- [ ] on the network configuration screen, select the main ethernet adapter, select "Edit IPv4", select "Manual", then:
	- Subnet: `192.168.1.0/24`
	- Address: `192.168.1.25`
	- Gateway: `192.168.1.1`
	- Name servers: `192.168.1.1`
- [ ] on the disk configuration screen, **deselect**  `Setup this disk as an LVM group` and go to the next screen
- [ ] for the primary NVMe, configure two partitions: a small boot partition, and a larger ext4 partition which takes up the rest of the space (this will be configured by default if you started with a wiped disk).  You don't need to partition or format the secondary SSD yet; it can be done after the initial setup.
- [ ] pick a username, password, and server name (hostname), then go to next screen:
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

## 2. Client PC Setup
This is your laptop or desktop computer, which you will use to remotely login to the node server and perform administrative duties.  This guide assumes that you have Linux installed as the O/S, but you could also use Windows with WSL (Windows Subsystem for Linux) or Apple O/S, but that is beyond the scope of this guide.

You should have a password manager like KeepassXC installed before continuing, with a folder dedicated to Ethereum node and validator-related entries.

- [ ] ensure that the client PC is connected to the LAN, by cable or WiFi
- [ ] login as the local user that will be interacting with the node server.  If this PC is your main Desktop computer, your existing user account is fine to use.
- [ ] edit `/etc/hosts` and add an entry at the bottom which associates the node server's static IP address to its hostname:
	```
	192.168.1.25 eth-node-mainnet
	```
- [ ] try logging into the node server via SSH, entering the remote user's password when prompted:
	```bash
	ssh coejoder@eth-node-mainnet
	# if successful, we're good. Logout and continue to next step.
	# (logout by typing `exit` or pressing `ctrl+d`)
	exit
	```
- [ ] create a new SSH key, specifying a passphrase when prompted.  Save the passphrase in your password manager:
	```bash
	ssh-keygen -t ed25519 -a 100 -f ~/.ssh/eth-node-mainnet_ed25519
	```
- [ ] add the public key to the node server, entering the node user's password when prompted (not the passphrase you just created):
	```bash
	ssh-copy-id -i ~/.ssh/eth-node-mainnet_ed25519 coejoder@eth-node-mainnet
	```
- [ ] create or edit the existing `~/.ssh/config` and add a section to the bottom of the file:
	```text
	Host eth-node-mainnet
		User coejoder
		IdentityFile ~/.ssh/eth-node-mainnet_ed25519
		IdentitiesOnly yes
		PreferredAuthentications publickey
		ForwardAgent yes
	```
- [ ] try logging into the node server again via SSH, but this time without specifying the remote username.  Enter the SSH key passphrase when prompted:
	```bash
	ssh eth-node-mainnet
	# if successful, stay logged in and continue
	```
- [ ] now that key-based authentication is working, while still logged into the node server, disable password and non-passphrase key authentication as an additional security measure:
	```bash
	sudo nano /etc/ssh/sshd_config
	```
	```text
	# scroll down to this section:
	
		# To disable tunneled clear text passwords, change to no here!
		#PasswordAuthentication yes
		#PermitEmptyPasswords no
		
	# uncomment both settings and set them to `no` like this:

		# To disable tunneled clear text passwords, change to no here!
		PasswordAuthentication no
		PermitEmptyPasswords no
	```
- [ ] after saving and closing the above file, while still logged into the node server, restart the SSH service
	```bash
	sudo systemctl restart ssh.service
	# after this, logout (`exit` or `ctrl+d`) and try logging back in
	# if successful, continue to next step
	```
- [ ] while still logged into the node server, install the latest system updates:
	```bash
	sudo apt update && sudo apt upgrade -y
	```
- [ ] ensure system timezone & time are correct
	```bash
	sudo timedatectl set-ntp on
	sudo timedatectl set-timezone America/Los_Angeles
	```

## 3. Initial Setup Complete
To shutdown the node server:
```bash
sudo shutdown now
```
(if it reboots instead of shutting down, it may be due to particular known bug of older Intel NUCs.  It can be fixed with a BIOS update, but for now, just press and hold the power button for about 10 seconds to force-shut down or unplug it).

At this point, you have the basic system setup complete, and a secure SSH tunnel configured between your PC and the node server.  You may disconnect the mouse & keyboard from the node server, and place the server somewhere convenient near the router and *definitely* connected to a UPS battery backup.
