# Partial Withdrawal
Sets a withdrawal wallet address for all validators running on the node.  This triggers automatic, periodic withdrawals of ETH income until the validators are exited.  Upon exit, each validator's 32 ETH stake is withdrawn to this same address.  The withdrawal address can only be set once.

## Preconditions
- [ ] [validator setup](./validator-setup.md) has been completed
- [ ] node server is powered on and running geth (EL), prysm-beacon (CL), and prysm-validator (validator(s)) as services
- [ ] EL and CL are fully synced to the Ethereum network and validator(s) are active
- [ ] client PC is powered on and able to SSH into the node server
- [ ] air-gapped PC is powered on and running live Linux from the `Mint` USB flash drive created during [initial setup](./initial-setup.md)
- [ ] `Data` USB flash drive formatted to EXT4 during the [validator setup](./validator-setup.md) is on-hand and has the deployed files

## Postconditions
- validators will still be active, but their balances in excess of the staked 32 ETH will be periodically withdrawn to the wallet address specified in the `withdrawal` project environment variable (see `env.sh`)

## Configurable Values
As in the initial setup guide, this guide is written using the following configurable values:
- node server SSH port: `55522`
- node server hostname: `eth-node-mainnet`

## Steps

### 1. Gather Validator Information 
Gather information on the particular validators you with to set a withdrawal address for at this time.

#### On the Client PC:

- [ ] generate a validator status report:

```bash
cd ethereum-node

# export validator status to the `DATA` flash drive
./tools/export.sh

# install `jq` if not already
sudo apt install jq

# review the exported status file, displaying only the relevant fields
jq '.[] | {index, pubkey: .validator.pubkey, bls_withdrawal_credentials: .validator.withdrawal_credentials}' "/media/$USER/DATA/ethereum-node/validator_statuses.json"
```

- [ ] open the Mint `Text Editor` and copy some information from the displayed validator statuses, but only from the validators you wish to partially-withdrawal.
	
For example, let's say you want to withdraw only the first two validators, and you have the following status file showing three validators:

```json
{
	"index": "1803793",
	"pubkey": "0x7838d5005b46fd5780d1a365430637fe08f8d58474d8284a61914fa99789fbd4716d0bed0f966692ec8f59b3076231d5",
	"bls_withdrawal_credentials": "0x000754de2ba6f50cee7610ca6fb73a8725f69b5c07cff510697e03e9c0b78422"
}
{
	"index": "1803784",
	"pubkey": "0x9ce2acdd3104b2721921c696807b194f0e16ea74ea931760eb27c51f4c6456f6bee4f71c114369733f3d6d69581c4ba3",
	"bls_withdrawal_credentials": "0x00654328d68c10206d878633bd65b3bf01289ba217f184cefc8b063bb13574bc"
}
{
	"index": "1803790",
	"pubkey": "0x7ca3bbcd3104b2721921c696807b194f0e16ea74ea931760eb27c51f4c6456f6bee4f71c114369733f3d6d695713f2ac",
	"bls_withdrawal_credentials": "0x00243128d78c10206d878633bd65b3bf01289ba227f184cefc8b063bb13464bc"
}
```
In `Text Editor`, you would write down the following **comma-separated** values of the two target validators like so:

```
Validator indices:
1803793,1803784

Validator pubkeys:
0x7838d5005b46fd5780d1a365430637fe08f8d58474d8284a61914fa99789fbd4716d0bed0f966692ec8f59b3076231d5,0x9ce2acdd3104b2721921c696807b194f0e16ea74ea931760eb27c51f4c6456f6bee4f71c114369733f3d6d69581c4ba3

BLS Withdrawal Credentials:
0x000754de2ba6f50cee7610ca6fb73a8725f69b5c07cff510697e03e9c0b78422,0x00654328d68c10206d878633bd65b3bf01289ba217f184cefc8b063bb13574bc
```

Save this file somewhere (or just keep `Text Editor` open).


### 2. Determine the ERC-2334 Start Index
Whereas the indices of the previous step refer to the beacon chain indices of your validators, we now need to find the ERC-2334 starting index of the validators that you are trying to withdraw.

- If you are withdrawing all of your validators, use index `0`.

- If you are withdrawing a subset of your validators, there is a script you can run to find out their ERC-2334 indices, using your mnemonic seed and a comma-separated list of validator pubkeys:

	#### On the Air-Gapped PC:
	```bash
	# change to the flash drive and unseal the deployment
	cd /media/mint/DATA/
	source ./unseal.sh

	# find ERC-2334 indices of your validators
	./get-validator-indices.sh

	# the above command will display an index for every pubkey entered
	# use the lowest value as the start index
	```

Once the ERC-2334 start index is determined, add it to the `Text Editor` file.  For example:
```
Validator start index: 0
```

### 3. TODO
