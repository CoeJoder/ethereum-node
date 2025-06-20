# Validator Setup

## Preconditions
- [ ] you have at least 32 ETH available to stake per validator in your MetaMask wallet
- [ ] [node setup](./node-setup.md) has been completed
- [ ] node server is powered on and running geth (EL) and prysm-beacon (CL) as services
- [ ] EL and CL are fully synced to the Ethereum network
- [ ] client PC is powered on and able to SSH into the node server
- [ ] air-gapped PC is powered on and running live Linux from the `Mint` USB flash drive created during [initial setup](./initial-setup.md)
- [ ] the `Data` USB flash drive created during initial setup is on-hand

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

### 2. Format the `Data` flash drive to EXT4 and Deploy to it

#### On the Client PC:
- [ ] plug-in the USB flash drive labeled `DATA` which was formatted to FAT32 during [initial setup](./initial-setup.md)
- [ ] wipe the drive and create an EXT4 partition:

```bash
# get the device path of the USB 'DATA' drive
flashdrive="/dev/$(lsblk -I 8 --json | jq --arg USER "$USER" -r '.blockdevices | 
	map(select(.children[].mountpoints[] | contains("/media/\($USER)/DATA" ))) |
	first | .name')" && echo $flashdrive

# unmount any mounted partitions of the USB flash drive
sudo umount ${flashdrive}?*

# wipe the existing partitions & create a new EXT4 partition
sudo fdisk $flashdrive
# Command (m for help): g
# Command (m for help): n
# Select (default p): <Enter>
# Partition number (1-4, default 1): <Enter>
# First sector (2048-120164351, default 2048): <Enter>
# Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-120164351, default 120164351): <Enter>
# Do you want to remove the signature? [Y]es/[N]o: y
# Command (m for help): w

# format the new partition and label it "DATA"
sudo mkfs.ext4 -L DATA -E lazy_itable_init=0 ${flashdrive}1

# safely eject the drive
sudo eject $flashdrive
```

- [ ] unplug the flash drive and plug it back in.  It should be auto-mounted by the operating system
- [ ] change into the project directory and deploy to the flash drive:
```bash
cd ethereum-node
./tools/deploy.sh --usb
```
- [ ] safely eject the flash drive and unplug it

### 3. Generate Mnemonic and Validator Keys

#### On the Air-Gapped PC:
- [ ] plug-in the flash drive
- [ ] open a terminal and generate a mnemonic seed & validator keys:

```bash
cd /media/mint/DATA/
source ./unseal.sh
./generate-keys.sh new-mnemonic
source ./seal.sh
```

- [ ] save the passphrase in your client PC's password manager
- [ ] save the seedphrase/mnemonic offline, e.g. engraved on metal plates in a fireproof safe, with encrypted off-site backups
- [ ] safely eject the flash drive and unplug it

### 4. Import Validator Keys and Create Wallet

#### On the Client PC:
- [ ] login to the node server via SSH and set the wallet password:

```bash
ssh -p 55522 eth-node-mainnet
cd ethereum-node

./set-wallet-password.sh
# when prompted, choose a wallet password and save it in your client PC's password manager

# logout and continue to next step (type `exit` or press `ctrl+d`)
exit
```

- [ ] plug-in the flash drive
- [ ] open a terminal and import the validator keys:
```bash
./tools/import-keys.sh
# ignore the following warnings: 
#   "error creating directory"
#   "accept-terms-of-use"
#   "You are using an insecure gRPC connection"
# when prompted for a wallet password, enter the one created during `set-wallet-password.sh`
# when prompted for the account password, enter the passphrase created during `generate-keys.sh`
```

### 5. Deposit 32 ETH Per Validator

- [ ] unseal the USB files and explore the `validator_keys` directory:

```bash
cd /media/$USER/DATA/
source ./unseal.sh
(nemo ./validator_keys/ &>/dev/null &)
```

- [ ] browse to the Ethereum Staking Launchpad page:
	- [mainnet](https://launchpad.ethereum.org/en/overview) or [hoodi](https://hoodi.launchpad.ethereum.org/en/overview)
- [ ] keep clicking <kbd>Continue</kbd> and <kbd>I Accept</kbd> until you reach the `Upload deposit data` page (no need to fill out the forms along the way)
- [ ] drag-and-drop the `deposit_data-XYZ.json` file from the `validator_keys` directory onto the webpage when prompted
- [ ] follow the website instructions to connect your MetaMask wallet and complete the deposits: one for each validator
	- if any of the deposit transactions fail, make a copy of `deposit_data-XYZ.json` and edit it, deleting the validators from the top-level array whose deposits were successful.  Submit this edited copy to the launchpad website.  Repeat as necessary until all deposits are complete.  Any copies of `deposit_data-XYZ.json` made in this way should be deleted afterwards, retaining only the original.  Seek support on the "ethstaker" Discord server if needed.
- [ ] close the file explorer
- [ ] reseal the USB files:

```bash
source ./seal.sh
```

### 6. Enable Validator Service

It can take over a week for the deposit(s) to arrive in the balance of your validator(s), signaling your official entry as a validating Ethereum node.  At the moment of entry, your validator(s) will be expected to be up-and-running, along with your EL & CL, so start the validator service now and leave it running.

#### On the Client PC
- [ ] login to the node server via SSH and start the validator:

```bash
ssh -p 55522 eth-node-mainnet
cd ethereum-node

# start the service and follow its log
./enable-validator.sh
# press `ctrl + c` to exit the log
```

## Next Steps

- [Add validators](./add-validators.md)
- [Withdraw validators](./partial-withdrawal.md)
- [Exit validators](./voluntary-exit.md)
- [Compound or Consolidate validators](./compound_or_consolidate.md)
