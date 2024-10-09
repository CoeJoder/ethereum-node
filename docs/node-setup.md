# Node Setup

## Preconditions
- the [initial setup](./initial-setup.md) has been completed
- node server is powered on and connected to the network
- client PC is powered on and able to SSH into the node server
- ***IMPORTANT: your ISP plan includes unlimited data***

## Postconditions
- node server will be running geth (EL), prysm-beacon (CL) as services
- you will be ready to [setup one or more validators](./validator-setup.md)

## Configurable Values
As in the initial setup guide, this guide is written using the following configurable values:
- router IP address: `192.168.1.1`
- node server IP address: `192.168.1.25`
- node server timezone: `America/Los_Angeles`
- node server SSH port: `55522`
- node server hostname: `eth-node-mainnet`
- node server username: `coejoder`

## Steps

As the node server is now running headless (no mouse, keyboard, monitor), all of these steps are performed on the client PC.

- [ ] configure the project environment variables:

```bash
cd ethereum-node

# generate the configurable env vars
./tools/setup-env.sh

# now change its default values as needed
nano ./src/env.sh
# these values will be used throughout the rest of the project and should only
# be set once
```

- [ ] deploy the scripts to the node server:

```bash
./tools/deploy.sh
```

- [ ] login to the node server via SSH, and review the full list of project environment variables, including your configured values:

```bash
ssh -p 55522 eth-node-mainnet
cd ethereum-node

./print-env.sh
# after reviewing, stay logged in for the next steps
```

- [ ] configure the software firewall and enable it:

```bash
# answer "y" to any continuation prompts
./setup-firewall.sh
```

- [ ] login to your router via web browser, and manually configure port forwarding using the same configuration described by the output of the previous command
- [ ] prepare the users, groups, and filesystem for the Ethereum node software:

```bash
./setup-filesystem.sh
```

- [ ] install the Ethereum node software: **geth** (Execution Layer) and **prysm-beacon** (Consensus Layer):

```bash
./setup-node.sh
```

- [ ] enable the EL and CL services:

```bash
./enable-geth.sh
./enable-beacon.sh
```

## Next Steps
You are now ready for [validator setup](./validator-setup.md).
