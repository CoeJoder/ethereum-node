---
title: Partial Withdrawal
description: Sets a withdrawal address for one or more validators.
sidebar:
  order: 6
---
Also known as: &nbsp; ***Conversion to 0x01 credentials.***

Sets a withdrawal address for one or more validators.  A validator can have its withdrawal address set only once, so be careful!

## Preconditions
- [ ] [validator setup](../validator-setup) has been completed
- [ ] node server is powered on and running geth (EL), prysm-beacon (CL), and prysm-validator (validator(s)) as services
- [ ] EL and CL are fully synced to the Ethereum network and validator(s) are active
- [ ] client PC is powered on and able to SSH into the node server
- [ ] air-gapped PC is powered on and running live Linux from the `Mint` USB flash drive created during [initial setup](../initial-setup/#1-download-mint-and-ubuntu-server)
- [ ] `Data` USB drive formatted to EXT4 during [validator setup](../validator-setup/#2-format-the-data-flash-drive-to-ext4-and-deploy-to-it) is on-hand

## Postconditions
- validators will still be active, but their balances in excess of the staked 32 ETH will be periodically withdrawn to the wallet address specified by the `withdrawal` variable in `env.sh`

## Configurable Values
As in the initial setup guide, this guide is written using the following configurable values:
- node server SSH port: `55522`
- node server hostname: `eth-node-mainnet`

## Steps

### 1. Pick Which Validators to Withdraw

#### On the Client PC:

- [ ] plug-in the `Data` USB drive
- [ ] generate a validator status report:

```bash
cd ethereum-node

# deploy project files to USB drive
./tools/deploy.sh --usb

# generate validator status report and save it to USB drive
./tools/export.sh
```

- [ ] safely eject the USB drive

#### On the Air-Gapped PC:

- [ ] plug-in the USB drive
- [ ] pick the validators to withdraw and generate a signed `bls-to-execution-change` message: 

```bash
cd /media/mint/DATA/
source ./unseal.sh
./generate-bls-to-execution-change-message.sh
source ./seal.sh
```

- [ ] safely eject the USB drive

### 2. Broadcast the Signed Message to the Ethereum Network

#### On the Client PC:

- [ ] plug-in the USB drive
- [ ] submit the signed message via the node server:

```bash
cd ethereum-node

# submit signed message via node server
./tools/withdraw.sh
```

## Next Steps
- [Add validators](../add-validators/)
- [Withdraw validators](../partial-withdrawal/)
- [Exit validators](../voluntary-exit/)
- [Compound or Consolidate validators](../compound_or_consolidate/)
