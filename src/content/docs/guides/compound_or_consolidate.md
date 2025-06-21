---
title: Compound or Consolidate
description: Convert a validator into a compounding type, or consolidate into another.
sidebar:
  order: 5
---
The Pectra upgrade has enabled two additional validator operations:

### Compound
Also known as: &nbsp; ***Conversion to 0x02 credentials.***

Converts a **0x01** validator to **0x02**, thereby halting "sweeping" withdrawals and enabling compounding staking rewards.  This is an irreversible operation, so be careful!

### Consolidate
Transfers the balance of a **0x01** or **0x02** validator to a **0x02** validator.  This will exit the source validator and move its remaining balance to the balance of the target validator.  This is also irreversible.

## Preconditions
See [Pectra maxEB docs](https://ethereum.org/en/roadmap/pectra/maxeb) for full list of validator preconditions.
- [ ] node server is powered on and running geth (EL), prysm-beacon (CL), and prysm-validator (validator(s)) as services
- [ ] EL and CL are fully synced to the Ethereum network and validator(s) are active
- [ ] client PC is powered on and able to SSH into the node server


## Steps

### 1. Time the conversion carefully
If you want to go straight from **0x00** to compounding without receiving any ETH at your withdrawal address, you must complete the **0x00** → **0x01** → **0x02** sequence before the first **0x01** automatic sweep occurs.  You should thus time the conversion carefully, with as much lead time as possible.

You can estimate the automatic sweep intervals for a particular validator like this:

#### On the Client PC:

```bash
cd ethereum-node
./tools/estimate-withdrawal-sweep.sh <validator-index-or-pubkey>
```

Keep in mind that it will take at least **27.3 hours** to complete the conversion, plus queue time.

### 2. Convert source validator to **0x01** if not already

See [conversion to 0x01 credentials](../partial-withdrawal/).

Wait for the **0x01** conversion to be finalized.  In the meantime, move a small amount of ETH to the withdrawal address to pay for the gas of the `ConsolidationRequest`.

### 3.  Compound or Consolidate via Launchpad page
[Launchpad page (mainnet)](https://launchpad.ethereum.org/en/validator-actions)<br/>
[Launchpad page (hoodi)](https://hoodi.launchpad.ethereum.org/en/validator-actions)
- connect withdrawal account via MetaMask
- follow the directions on-page

## Next Steps
- [Add validators](../add-validators/)
- [Withdraw validators](../partial-withdrawal/)
- [Exit validators](../voluntary-exit/)
- [Compound or Consolidate validators](../compound_or_consolidate/)
