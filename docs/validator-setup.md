# Validator Setup

## Preconditions
- [ ] you have at least 32 ETH available to stake per validator
- [ ] [node setup](./node-setup.md) has been completed
- [ ] node server is powered on and running geth (EL) and prysm-beacon (CL) as services
- [ ] EL and CL are fully synced to the Ethereum network
- [ ] client PC is powered on and able to SSH into the node server
- [ ] air-gapped PC is powered on and running live Linux from the `Mint` USB flash drive created during [initial setup](./initial-setup.md)

## Postconditions
- node server will be running the EL, the CL, and prysm-validator (validator(s)) as a service
- validator(s) will be attesting, aggregating, and proposing blocks, thus earning ETH income over time
- ETH income will be added to its respective validator's balance as it is earned
- for any validator, you will be ready to set a withdrawal address at a future time of your choosing, thus beginning automatic, periodic withdrawals of its balance in excess of the staked 32 ETH

## Configurable Values
As in the initial setup guide, this guide is written using the following configurable values:
- node server SSH port: `55522`
- node server hostname: `eth-node-mainnet`

## Steps

### 1. Install Validator Software

#### On the Client PC:

- [ ] login to the node server via SSH and install **prysm-validator**:

```bash
ssh -p 55522 eth-node-mainnet
cd ethereum-node

# install prysm-validator, and configure it to run as a service
./setup-validator.sh

# logout and continue to next step (type `exit` or press `ctrl+d`)
exit
```

### 2. Generate Validator Keys

#### On the Client PC:
- [ ] plug-in the USB flash drive labeled `DATA` which was formatted to FAT32 during [initial setup](./initial-setup.md)
- [ ] wipe the drive and create an `EXT4` partition:

```bash
# list all drives on the system and identify the USB flash drive
sudo fdisk -l
# e.g., /dev/xyz

# find any mounted partitions of the USB drive and unmount them
mount -l | grep /dev/xyz
# e.g., /dev/xyz1 and /dev/xyz2
sudo umount /dev/xyz1
sudo umount /dev/xyz2

# wipe the existing partitions & create a new EXT4 partition
sudo fdisk /dev/xyz
# Command (m for help): g
# Command (m for help): n
# Select (default p): <Enter>
# Partition number (1-4, default 1): <Enter>
# First sector (2048-120164351, default 2048): <Enter>
# Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-120164351, default 120164351): <Enter>
# Do you want to remove the signature? [Y]es/[N]o: y
# Command (m for help): w

# format the new partition and label it "DATA"
sudo mkfs.ext4 -L DATA -E lazy_itable_init=0 /dev/xyz1

# safely eject the drive
sudo eject /dev/xyz
```

- [ ] unplug the flash drive and plug it back in.  It should be auto-mounted by the operating system
- [ ] deploy to the flash drive:
```bash
cd ethereum-node
./tools/deploy.sh --offline
```
- [ ] safely eject the flash drive and unplug it

#### On the Air-Gapped PC:
- [ ] plug-in the flash drive
- [ ] open a terminal and run the Ethereum Staking Deposit CLI:

```bash
# change to the flash drive's `ethereum-node` directory and chown it
cd /media/mint/DATA/ethereum-node/
sudo chown -R $USER:$USER ./

# generate the validator key(s)
./ethereum-node/run-staking-deposit-cli.sh

# save the passphrase in a password manager, e.g. KeePassXC on the client PC
# save the seedphrase offline, e.g. engraved on metal plates in a fireproof safe, with encrypted off-site backups
```
- [ ] safely eject the flash drive and unplug it

### 3. Import Validator Keys

#### On the Client PC:
- [ ] plug-in the flash drive
- [ ] open a terminal and import the validator keys
```bash
cd ethereum-node
./tools/import-keys.sh
```

## Next Steps

### TODO
