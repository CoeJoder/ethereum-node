# Partial Withdrawal
Sets a withdrawal address for one or more validators.  A validator can have its withdrawal address set only once, so be careful!

## Preconditions
- [ ] [validator setup](./validator-setup.md) has been completed
- [ ] node server is powered on and running geth (EL), prysm-beacon (CL), and prysm-validator (validator(s)) as services
- [ ] EL and CL are fully synced to the Ethereum network and validator(s) are active
- [ ] client PC is powered on and able to SSH into the node server
- [ ] air-gapped PC is powered on and running live Linux from the `Mint` USB flash drive created during [initial setup](./initial-setup.md)
- [ ] `Data` USB drive formatted to EXT4 during [validator setup](./validator-setup.md) is on-hand

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
# change to USB drive and unseal deployment
cd /media/mint/DATA/
source ./unseal.sh

# pick validators to withdraw, generate signed message, then reseal deployment
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
- [Validator Exit](./voluntary-exit.md)
