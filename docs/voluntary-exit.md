# Voluntary Exit

## Preconditions
- [ ] [partial withdrawal](./partial-withdrawal.md) has been completed
- [ ] node server is powered on and running geth (EL) and prysm-beacon (CL) as services
- [ ] EL and CL are fully synced to the Ethereum network
- [ ] client PC is powered on and able to SSH into the node server

## Postconditions
- validator(s) will be exited and their stakes sent to their respective withdrawal addressses
- if all validators are exited, node server can be wiped & decommissioned

## Configurable Values
As in the initial setup guide, this guide is written using the following configurable values:
- node server SSH port: `55522`
- node server hostname: `eth-node-mainnet`

## Steps

### 1. Send Exit Message to Beacon

#### On the Client PC:

- [ ] deploy latest scripts, SSH into node server and run exit script:

```bash
cd ethereum-node
./tools/deploy.sh

ssh -p 55522 eth-node-mainnet
cd ethereum-node
./exit.sh
```

- [ ] verify that `beaconcha.in` website reflects exiting status (may take several minutes):
```
mainnet: https://beaconcha.in/validator/[index or pubkey]
holesky: https://holesky.beaconcha.in/validator/[index or pubkey]
```

### Next Steps
If all validators have been exited, you may safely shutdown and decommission the node server.  Otherwise:

- [Add Validators](./add-validators.md)

