# Add Validators
Adds new validators to your existing validator node service using an existing mnemonic.

## Preconditions
- [ ] [validator setup](./validator-setup.md) has been completed
- [ ] you have at least 32 ETH available to stake in your MetaMask wallet per new validator
- [ ] EL and CL are fully synced to the Ethereum network
- [ ] client PC is powered on and able to SSH into the node server
- [ ] air-gapped PC is powered on and running live Linux from the `Mint` USB flash drive created during [initial setup](./initial-setup.md)
- [ ] the `Data` USB flash drive formatted to EXT4 during [validator setup](./validator-setup.md) is on-hand

## Postconditions
- the new validator(s) will be running on your validator node service

## Configurable Values
As in the initial setup guide, this guide is written using the following configurable values:
- node server SSH port: `55522`
- node server hostname: `eth-node-mainnet`

## Steps

### 1. Generate New Validator Keys

#### On the Client PC:

- [ ] plug-in the `Data` USB drive
- [ ] generate a validator status report:

```bash
cd ethereum-node
./tools/deploy.sh --usb
./tools/export.sh
```

- [ ] safely eject the USB drive

#### On the Air-Gapped PC:

- [ ] plug-in the flash drive
- [ ] open a terminal and generate the next validator keys:

```bash
cd /media/mint/DATA/
source ./unseal.sh
./generate-next-keys.sh
source ./seal.sh
```

- [ ] safely eject the flash drive and unplug it

### 2. Import New Validator Keys

#### On the Client PC:

- [ ] plug-in the flash drive
- [ ] open a terminal and import the validator keys:

```bash
cd ethereum-node
./tools/deploy.sh
./tools/import-keys.sh
# ignore the following warnings: 
#   "error creating directory"
#   "accept-terms-of-use"
#   "You are using an insecure gRPC connection"
# when prompted for a wallet password, enter the one created during `set-wallet-password.sh` during initial validator setup
# when prompted for the account password, enter the passphrase just created during `generate-next-keys.sh`
```

### 3. Deposit 32 ETH Per New Validator

- [ ] unseal the USB files:

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

## Next Steps

- [Add validators](./add-validators.md)
- [Withdraw validators](./partial-withdrawal.md)
- [Exit validators](./voluntary-exit.md)
- [Compound or Consolidate validators](./compound_or_consolidate.md)
