#!/bin/bash

# mev-boost-relays.sh
#
# List of MEV Boost relays by network.
# See: https://github.com/ethstaker/ethstaker-guides/blob/main/MEV-relay-list.md
# 
# NOTE
# As this project is oriented towards US-based solo stakers, all relays listed
# here are OFAC-compliant, as required by US law.

# -------------------------- MAINNET ------------------------------------------

# https://bloxroute.max-profit.blxrbdn.com/
mevboost_relay_mainnet_bloxroute_maxprofit='https://0x8b5d2e73e2a3a55c6c87b8b6eb92e0149a125c852751db1422fa951e42a09b82c142c3ea98d0d9930b056a3bc9896b8f@bloxroute.max-profit.blxrbdn.com'

# https://bloxroute.regulated.blxrbdn.com/
mevboost_relay_mainnet_bloxroute_regulated='https://0xb0b07cd0abef743db4260b0ed50619cf6ad4d82064cb4fbec9d3ec530f7c5e6793d9f286c4e082c0244ffb9f2658fe88@bloxroute.regulated.blxrbdn.com'

# https://regional.titanrelay.xyz/
mevboost_relay_mainnet_titan_relay_us_regional='https://0x8c4ed5e24fe5c6ae21018437bde147693f68cda427cd1122cf20819c30eda7ed74f72dece09bb313f2a1855595ab677d@us-regional.titanrelay.xyz'

# https://boost-relay.flashbots.net/
mevboost_relay_mainnet_flashbots='https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net'

# -------------------------- HOODI --------------------------------------------

# https://boost-relay-hoodi.flashbots.net/
mevboost_relay_hoodi_flashbots='https://0xafa4c6985aa049fb79dd37010438cfebeb0f2bd42b115b89dd678dab0670c1de38da0c4e9138c9290a398ecd9a0b3110@boost-relay-hoodi.flashbots.net'

# -----------------------------------------------------------------------------

# all mainnet relays
declare -g mevboost_relays_mainnet
export mevboost_relays_mainnet=(
	"$mevboost_relay_mainnet_bloxroute_maxprofit"
	"$mevboost_relay_mainnet_bloxroute_regulated"
	"$mevboost_relay_mainnet_titan_relay_us_regional"
	"$mevboost_relay_mainnet_flashbots"
)

# all testnet relays
declare -g mevboost_relays_testnet
export mevboost_relays_testnet=(
	"$mevboost_relay_hoodi_flashbots"
)
