#!/bin/bash

# update.sh
#
# Updates to the latest version all node programs, if installed (geth,
# prysm-beacon, prysm-validator, prysmctl).
#
# Meant to be run on the node server.

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server
assert_sudo

reset_checks

check_is_defined geth_bin
check_is_defined prysm_beacon_bin
check_is_defined prysm_validator_bin

check_user_exists prysm_beacon_user
check_user_exists prysm_validator_user
check_user_exists prysmctl_user

check_group_exists prysm_beacon_group
check_group_exists prysm_validator_group
check_group_exists prysmctl_group

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

echo -en "${color_yellow}${bold}"
cat <<'EOF'
                   __      __     
  __  ______  ____/ /___ _/ /____ 
 / / / / __ \/ __  / __ `/ __/ _ \
/ /_/ / /_/ / /_/ / /_/ / /_/  __/
\__,_/ .___/\__,_/\__,_/\__/\___/ 
    /_/                           
EOF
echo -en "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Updates to the latest version all node programs, if installed (geth, prysm-beacon, prysm-validator, prysmctl).
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

get_latest_prysm_version latest_prysm_version

_update_prysmbeacon=false
_update_prysmvalidator=false
_update_prysmctl=false

reset_checks
check_executable_exists --sudo prysm_beacon_bin
if ! has_failed_checks; then
	_update_prysmbeacon=true
fi

reset_checks
check_executable_exists --sudo prysm_validator_bin
if ! has_failed_checks; then
	_update_prysmvalidator=true
fi

reset_checks
check_executable_exists --sudo prysmctl_bin
if ! has_failed_checks; then
	_update_prysmctl=true
fi

# -------------------------- EXECUTION ----------------------------------------

temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null

function on_exit() {
	printinfo -n "Cleaning up..."
	popd >/dev/null
	rm -rf --interactive=never "$temp_dir" >/dev/null
	print_ok
}

trap 'on_err_retry' ERR
trap 'on_exit' EXIT

assert_sudo

# system and app list updates (includes geth)
printinfo Running APT update and upgrade...
sudo apt-get -y update
sudo apt-get -y upgrade

if [[ $_update_prysmbeacon == true ]]; then
	printinfo "Updating prysm-beacon..."
	install_prysm beacon-chain \
		"$latest_prysm_version" "$prysm_beacon_bin" "$prysm_beacon_user" "$prysm_beacon_group"
fi

if [[ $_update_prysmvalidator == true ]]; then
	printinfo "Updating prysm-validator..."
	install_prysm validator \
		"$latest_prysm_version" "$prysm_validator_bin" "$prysm_validator_user" "$prysm_validator_group"
fi

if [[ $_update_prysmctl == true ]]; then
	printinfo "Updating prysmctl..."
	install_prysm prysmctl \
		"$latest_prysm_version" "$prysmctl_bin" "$prysmctl_user" "$prysmctl_group"
fi

# -------------------------- POSTCONDITIONS -----------------------------------
