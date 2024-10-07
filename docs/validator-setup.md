# Validator Setup

## Preconditions
- the [node setup](./node-setup.md) has been completed
- node server is powered on and running geth (EL) and prysm-beacon (CL) as services
- the EL and CL are fully synced to the Ethereum network
- client PC is powered on and able to SSH into the node server
- you have at least 32 ETH available to stake per validator

## Postconditions
- node server will be running the EL, the CL, and prysm-validator (validator(s)) as a service
- validator(s) will be attesting, aggregating, and proposing blocks, thus earning ETH income over time
- ETH income will be added to its respective validator's balance as it is earned
- for any validator, you will be ready to set a withdrawal address at a future time of your choosing, thus beginning automatic, periodic withdrawals of its balance in excess of the staked 32 ETH

## Configurable Values
As in the initial setup guide, this guide is written using the following configurable values:
- router IP address: `192.168.1.1`
- node server IP address: `192.168.1.25`
- node server timezone: `America/Los_Angeles`
- node server SSH port: `55522`
- node server hostname: `eth-node-mainnet`
- node server username: `coejoder`

## Steps

### TODO

## Next Steps

### TODO
