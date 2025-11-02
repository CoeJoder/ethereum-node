#!/bin/bash

# setup-ethdo.sh
#
# Installs the ethdo & ethereal utility programs.

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server
assert_sudo

check_is_defined ethdo_version
check_is_defined ethdo_sha256_checksum
check_executable_does_not_exist --sudo ethdo_bin

check_is_defined ethereal_version
check_is_defined ethereal_sha256_checksum
check_executable_does_not_exist --sudo ethereal_bin

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

show_banner "${color_green}${bold}" <<'EOF'
              __                                    __    __          __            
             /\ \__                                /\ \__/\ \        /\ \           
  ____     __\ \ ,_\ __  __  _____               __\ \ ,_\ \ \___    \_\ \    ___   
 /',__\  /'__`\ \ \//\ \/\ \/\ '__`\  _______  /'__`\ \ \/\ \  _ `\  /'_` \  / __`\ 
/\__, `\/\  __/\ \ \\ \ \_\ \ \ \L\ \/\______\/\  __/\ \ \_\ \ \ \ \/\ \L\ \/\ \L\ \
\/\____/\ \____\\ \__\ \____/\ \ ,__/\/______/\ \____\\ \__\\ \_\ \_\ \___,_\ \____/
 \/___/  \/____/ \/__/\/___/  \ \ \/           \/____/ \/__/ \/_/\/_/\/__,_ /\/___/ 
                               \ \_\                                                
                                \/_/                                                
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF

Installs ethdo & ethereal on the node server.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

# check for latest versions
declare latest_ethdo_version
declare latest_ethereal_version
get_latest_ethdo_version latest_ethdo_version
get_latest_ethereal_version latest_ethereal_version

_new_version_detected=false
if [[ $ethdo_version != "$latest_ethdo_version" ]]; then
	_new_version_detected=true
	log warn "New version of ethdo detected: ${theme_value}$latest_ethdo_version${color_reset}"
fi
if [[ $ethereal_version != "$latest_ethereal_version" ]]; then
	_new_version_detected=true
	log warn "New version of ethereal detected: ${theme_value}$latest_ethereal_version${color_reset}"
fi

if [[ $_new_version_detected == true ]]; then
	log warn "It is suggested to update env vars with latest version checksums and then restart script."
	continue_or_exit 1 "Continue anyways with older versions?"
fi

# -------------------------- EXECUTION ----------------------------------------

temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null

function on_exit() {
	log info "Cleaning up..."
	popd >/dev/null
	rm -rf --interactive=never "$temp_dir" >/dev/null
}

trap 'on_err_retry' ERR
trap 'on_exit' EXIT

assert_sudo

# ethdo install
log info "Installing ethdo..."
install_wealdtech ethdo \
	"$ethdo_version" "$ethdo_sha256_checksum" "$ethdo_bin" "$USER" "$USER"

# ethereal install
log info "Installing ethereal..."
install_wealdtech ethereal \
	"$ethereal_version" "$ethereal_sha256_checksum" "$ethereal_bin" "$USER" "$USER"

log info "Configuring bash completion..."
ethdo_bashcompletions='/etc/bash_completion.d/ethdo'
ethereal_bashcompletions='/etc/bash_completion.d/ethereal'
sudo ethdo completion bash | sudo tee "$ethdo_bashcompletions" >/dev/null
sudo ethereal completion bash | sudo tee "$ethereal_bashcompletions" >/dev/null

# -------------------------- POSTCONDITIONS -----------------------------------

assert_sudo

reset_checks

check_executable_exists --sudo ethdo_bin
check_executable_exists --sudo ethereal_bin
check_file_exists --sudo ethdo_bashcompletions
check_file_exists --sudo ethereal_bashcompletions

print_failed_checks --error

cat <<EOF

Success!  Ethdo and Ethereal have been installed on the node server.
EOF
