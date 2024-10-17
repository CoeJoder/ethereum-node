# Node Setup

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
- node server username: `coejoder`

## Steps

All of these steps are performed on the client PC.  Most of the work is performed by helper scripts; you just need to run them in the correct order.

- [ ] download the `ethereum-node` helper scripts:
```bash
sudo apt install -y git
cd
git clone https://github.com/CoeJoder/ethereum-node.git
```

- [ ] configure the project environment variables:

```bash
cd ethereum-node

# generate `env.sh`
./tools/setup-env.sh

# change the default values as needed
# for example, you may need to customize the ports if multiple nodes are connected to the same router
# these values will be used throughout the rest of the project and should only be set this once
nano ./src/env.sh
```

- [ ] deploy the helper scripts to the node server:

```bash
# copy the scripts to the node server, in directory `~/ethereum-node`
./tools/deploy.sh
```

- [ ] login to the node server via SSH, and review the full list of project environment variables, including any customized values:

```bash
ssh -p 55522 eth-node-mainnet
cd ethereum-node

# display all environment variables
# after reviewing, stay logged in for the next steps
./print-env.sh
```

- [ ] configure the software firewall and enable it:

```bash
# set firewall's rules and enable it
# answer "y" to any continuation prompts
./setup-firewall.sh
```

- [ ] login to your router via web browser, and manually configure port forwarding using the same configuration described by the output of the previous command
- [ ] prepare the users, groups, and filesystem for the Ethereum node software:

```bash
# setup users, groups, directories
./setup-filesystem.sh
```

- [ ] install the Ethereum node software: **geth** (Execution Layer) and **prysm-beacon** (Consensus Layer):

```bash
# install EL and CL, and configure them to run as services
./setup-node.sh
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
