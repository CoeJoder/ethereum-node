#!/bin/bash

# update.sh
#
# Updates to the latest version of all installed node programs (geth, prysm-
# beacon, prysm-validator, prysmctl, ethdo, ethereal, MEV-Boost).
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
check_is_defined mevboost_bin

check_is_defined prysm_beacon_user
check_is_defined prysm_validator_user
check_is_defined prysmctl_user
check_is_defined mevboost_user

check_is_defined prysm_beacon_group
check_is_defined prysm_validator_group
check_is_defined prysmctl_group
check_is_defined mevboost_group

# TODO use version-locking for the others too
check_is_defined ethdo_version
check_is_defined ethdo_sha256_checksum
check_is_defined ethereal_version
check_is_defined ethereal_sha256_checksum
check_is_defined mevboost_version
check_is_defined mevboost_sha256_checksum

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
Updates to the latest version all node programs, if installed (geth, prysm-beacon, prysm-validator, prysmctl, ethdo, ethereal, MEV-Boost).
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

declare latest_prysm_version
get_latest_prysm_version latest_prysm_version

_update_prysmbeacon=false
_update_prysmvalidator=false
_update_prysmctl=false
_update_ethdo=false
_update_ethereal=false
_update_mevboost=false

reset_checks
check_executable_exists --sudo prysm_beacon_bin
check_user_exists prysm_beacon_user
check_group_exists prysm_beacon_group
if ! has_failed_checks; then
	_update_prysmbeacon=true
fi

reset_checks
check_executable_exists --sudo prysm_validator_bin
check_user_exists prysm_validator_user
check_group_exists prysm_validator_group
if ! has_failed_checks; then
	_update_prysmvalidator=true
fi

reset_checks
check_executable_exists --sudo prysmctl_bin
check_user_exists prysmctl_user
check_group_exists prysmctl_group
if ! has_failed_checks; then
	_update_prysmctl=true
fi

reset_checks
check_executable_exists --sudo ethdo_bin
if ! has_failed_checks; then
	_ethdo_current_version="$(sudo "$ethdo_bin" version)"
	if [[ "v$_ethdo_current_version" != "$ethdo_version" ]]; then
		printinfo "ethdo v${_ethdo_current_version} is installed"
		if yes_or_no --default-no "Replace with ${ethdo_version}?"; then
			_update_ethdo=true
		fi
	fi
fi

reset_checks
check_executable_exists --sudo ethereal_bin
if ! has_failed_checks; then
	_ethereal_current_version="$(sudo "$ethereal_bin" version)"
	if [[ "v$_ethereal_current_version" != "$ethereal_version" ]]; then
		printinfo "ethereal v${_ethereal_current_version} is installed"
		if yes_or_no --default-no "Replace with ${ethereal_version}?"; then
			_update_ethereal=true
		fi
	fi
fi

reset_checks
check_executable_exists --sudo mevboost_bin
if ! has_failed_checks; then
	IFS= read -r _ _mevboost_current_version < <(sudo "$mevboost_bin" --version)
	if [[ "v$_mevboost_current_version" != "$mevboost_version" ]]; then
		printinfo "mevboost v${_mevboost_current_version} is installed"
		if yes_or_no --default-no "Replace with ${mevboost_version}?"; then
			_update_mevboost=true
		fi
	fi
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

if [[ $_update_ethdo == true ]]; then
	printinfo "Updating ethdo..."
	install_wealdtech ethdo \
		"$ethdo_version" "$ethdo_sha256_checksum" "$ethdo_bin" "$USER" "$USER"
fi

if [[ $_update_ethereal == true ]]; then
	printinfo "Updating ethereal..."
	install_wealdtech ethereal \
		"$ethereal_version" "$ethereal_sha256_checksum" "$ethereal_bin" "$USER" "$USER"
fi

if [[ $_update_mevboost == true ]]; then
	printinfo "Updating mevboost..."
	install_mevboost \
		"$mevboost_version" "$mevboost_sha256_checksum" "$mevboost_bin" "$mevboost_user" "$mevboost_group"
fi

# -------------------------- POSTCONDITIONS -----------------------------------
