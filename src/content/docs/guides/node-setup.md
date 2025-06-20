---
title: Node Setup
description: Setup the EL and CL of the Ethereum Node.
sidebar:
  order: 2
---
## Preconditions
- [ ] [initial setup](./initial-setup.md) has been completed
- [ ] node server is powered on and connected to the network
- [ ] client PC is powered on and able to SSH into the node server
- [ ] ***IMPORTANT: your ISP plan includes unlimited data***

## Postconditions
- client PC will have the [ethereum-node](https://github.com/CoeJoder/ethereum-node) helper scripts installed and configured
- node server will also have the helper scripts installed and configured
- node server will be running geth (EL), prysm-beacon (CL) as services
- you will be ready to [setup one or more validators](./validator-setup.md)

## Configurable Values
As in the initial setup guide, this guide is written using the following configurable values:
- node server SSH port: `55522`
- node server hostname: `eth-node-mainnet`

## Steps

All of these steps are performed on the client PC.  Most of the work is performed by helper scripts; you just need to run them in the correct order.

- [ ] download the `ethereum-node` helper scripts:
```bash
sudo apt install -y git
cd
git clone https://github.com/CoeJoder/ethereum-node.git
```

- [ ] configure the project environment variables:
	- **IMPORTANT:** ensure that `suggested_fee_recipient` and `withdrawal` are set now, if you're going to be running a validator.  This guide does not cover how to update these values later, so do it now.  The `suggested_fee_recipient` is the Ethereum wallet address which will receive tips from user transactions.  The `withdrawal` is the Ethereum wallet address which will receive validator income rewards and also the full withdrawal of funds upon exiting.  These can be set to the same address if you'd prefer:

```bash
cd ethereum-node

# generate `env.sh`
./tools/setup-env.sh

# change the default values as needed
# for example, you may need to customize the ports if multiple nodes are connected to the same router
# these values will be used throughout the rest of the project and should only be set this once
# `suggested_fee_recipient` and `withdrawal` should be set now if you plan on running a validator
nano ./src/env.sh
```

- [ ] deploy the helper scripts to the node server:

```bash
# copy the scripts to the node server, in directory `~/ethereum-node/`
./tools/deploy.sh
```

- [ ] login to the node server via SSH, and review the full list of project environment variables, including any customized values:

```bash
ssh -p 55522 eth-node-mainnet
cd ethereum-node

# display all environment variables and confirm they are correct
# if changes are needed, logout and make the changes in the client PC's `env.sh` and run `deploy.sh` again
./print-env.sh
# after reviewing, stay logged in for the next steps
```

- [ ] configure the software firewall and enable it:

```bash
# set firewall's rules and enable it
# answer "y" to any continuation prompts
./setup-firewall.sh
```

- [ ] login to your router via web browser, and manually configure port forwarding using the same configuration described by the output of the previous command
- [ ] install the Ethereum node software: **geth** (Execution Layer), **prysm-beacon** (Consensus Layer), **prysmctl**, **ethdo**, and **ethereal**:

```bash
# install EL and CL, and configure them to run as services
./setup-node.sh

# install prysmctl, a CLI utility for common node tasks
./setup-prysmctl.sh

# install ethdo & ethereal, CLI utilities for common Ethereum blockchain tasks
./setup-ethdo.sh
```

- [ ] enable the EL and CL services:

```bash
# start each service and follow its log
# press `ctrl + c` to exit the log
./enable-geth.sh
./enable-beacon.sh
```

## Next Steps
You are now ready for [validator setup](./validator-setup.md).
