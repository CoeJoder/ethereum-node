#!/bin/bash

# -------------------------- HEADER -------------------------------------------

src_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$src_dir/common.sh"
housekeeping

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_green}
              __                                                 __            
             /\ \__                                             /\ \           
  ____     __\ \ ,_\  __  __  _____              ___     ___    \_\ \     __   
 /',__\  /'__\`\ \ \/ /\ \/\ \/\ '__\`\  _______ /' _ \`\  / __\`\  /'_\` \  /'__\`\ 
/\__, \`\/\  __/\ \ \_\ \ \_\ \ \ \L\ \/\______\/\ \/\ \/\ \L\ \/\ \L\ \/\  __/ 
\/\____/\ \____\\\ \__\\\ \____/\ \ ,__/\/______/\ \_\ \_\ \____/\ \___,_\ \____\\
 \/___/  \/____/ \/__/ \/___/  \ \ \/           \/_/\/_/\/___/  \/__,_ /\/____/
                                \ \_\                                          
                                 \/_/                                          
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Installs geth (Execution Layer), prysm-beacon (Consensus Layer), prysm-validator, and generates the JWT secret shared between the EL and CL.
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

# assert_on_node_server

check_command_does_not_exist_on_path geth_bin
check_executable_does_not_exist prysm_beacon_bin
check_executable_does_not_exist prysm_validator_bin
check_file_does_not_exist eth_jwt_file

print_failed_checks --error || exit

# -------------------------- RECONNAISSANCE -----------------------------------

get_latest_prysm_version latest_prysm_version || exit 1

# display the env vars used in this script for confirmation
cat <<EOF

Ready to install the following:
  Geth: ${color_green}$geth_bin${color_reset}
  Prysm-beacon ${latest_prysm_version}: ${color_green}$prysm_beacon_bin${color_reset}
  Prysm-validator ${latest_prysm_version}: ${color_green}$prysm_validator_bin${color_reset}
  JWT secret: ${color_green}$eth_jwt_file${color_reset}
EOF
continue_or_exit 1

# -------------------------- EXECUTION ----------------------------------------

temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null

function on_exit() {
	printinfo -n "Cleaning up..."
	popd >/dev/null
	[[ -d $temp_dir ]] && rm -rf --interactive=never "$temp_dir" >/dev/null
	print_ok
}

trap 'on_err_retry' ERR
trap 'on_exit' EXIT

assert_sudo

# JWT secret
printinfo -n "Generating JWT secret..."
openssl rand -hex 32 | tr -d "\n" > "jwt.hex"
sudo mkdir -p "$(dirname "$eth_jwt_file")"
sudo mv -vf jwt.hex "$eth_jwt_file"
sudo chmod 644 "$eth_jwt_file"

# geth
printinfo "Installing geth..."
sudo add-apt-repository -y ppa:ethereum/ethereum
sudo apt-get update
sudo apt-get install ethereum

# prysm
printinfo "Downloading prysm-beacon and prysm-validator..."
latest_beacon_chain_bin="beacon-chain-${latest_prysm_version}-linux-amd64"
latest_beacon_chain_bin_sha256="beacon-chain-${latest_prysm_version}-linux-amd64.sha256"
latest_validator_bin="validator-${latest_prysm_version}-linux-amd64"
latest_validator_bin_sha256="validator-${latest_prysm_version}-linux-amd64.sha256"

rm -v --interactive=never "$latest_beacon_chain_bin" 2>/dev/null
rm -v --interactive=never "$latest_beacon_chain_bin_sha256" 2>/dev/null
rm -v --interactive=never "$latest_validator_bin" 2>/dev/null
rm -v --interactive=never "$latest_validator_bin_sha256" 2>/dev/null

wget -q "https://github.com/prysmaticlabs/prysm/releases/download/${latest_prysm_version}/${latest_beacon_chain_bin}"
wget -q "https://github.com/prysmaticlabs/prysm/releases/download/${latest_prysm_version}/${latest_beacon_chain_bin_sha256}"
wget -q "https://github.com/prysmaticlabs/prysm/releases/download/${latest_prysm_version}/${latest_validator_bin}"
wget -q "https://github.com/prysmaticlabs/prysm/releases/download/${latest_prysm_version}/${latest_validator_bin_sha256}"

echo "$(cat "$latest_beacon_chain_bin_sha256")" | shasum -a 256 -c - || (
	printerr $? "prysm-beacon checksum failed; supply-chain may be compromised"
	exit 1
)
echo "$(cat "$latest_validator_bin_sha256")" | shasum -a 256 -c - || (
	printerr $? "prysm-validator checksum failed; supply-chain may be compromised"
	exit 1
)

sudo chown -v ${prysm_beacon_user}:${prysm_beacon_group} "$latest_beacon_chain_bin"
sudo chown -v ${prysm_validator_user}:${prysm_validator_group} "$latest_validator_bin"
sudo chmod -v 550 "$latest_beacon_chain_bin"
sudo chmod -v 550 "$latest_validator_bin"
sudo mv -vf "$latest_beacon_chain_bin" "$prysm_beacon_bin" \
  && sudo rm -v --interactive=never "$latest_beacon_chain_bin_sha256"
sudo mv -vf "$latest_validator_bin" "$prysm_validator_bin" \
  && sudo rm -v --interactive=never "$latest_validator_bin_sha256"

sudo "$prysm_beacon_bin" --version
sudo "$prysm_validator_bin" --version

# -------------------------- POSTCONDITIONS -----------------------------------

reset_checks
check_file_exists eth_jwt_file
check_command_exists_on_path geth_bin
check_executable_exists prysm_beacon_bin
check_executable_exists prysm_validator_bin
print_failed_checks --error || exit

cat <<EOF

Success!  Now you are ready to setup the unit files.
EOF
