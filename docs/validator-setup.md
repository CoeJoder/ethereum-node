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
- node server username: `coejoder`

## Steps

### 1. Generate Validator Keys

#### On the Client PC
- [ ] plug-in the USB flash drive labeled `DATA` which was formatted to FAT32 during [initial setup](./initial-setup.md)
- [ ] deploy to the flash drive:
```bash
cd ethereum-node
./tools/deploy.sh --offline
```
- [ ] safely eject the flash drive and plug it into the air-gapped PC

### TODO

## Next Steps

### TODO
