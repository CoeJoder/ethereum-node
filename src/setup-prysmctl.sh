#!/bin/bash

# setup-prysmctl.sh
#
# Installs & configures the prysmctl utility program.
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

check_executable_does_not_exist --sudo prysmctl_bin
check_user_does_not_exist prysmctl_user
check_group_does_not_exist prysmctl_group
check_directory_does_not_exist --sudo prysmctl_datadir

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

show_banner "${color_green}${bold}" <<'EOF'
              __                                                                               __    ___      
             /\ \__                                                                           /\ \__/\_ \     
  ____     __\ \ ,_\ __  __  _____            _____   _ __   __  __    ____    ___ ___     ___\ \ ,_\//\ \    
 /',__\  /'__`\ \ \//\ \/\ \/\ '__`\  _______/\ '__`\/\`'__\/\ \/\ \  /',__\ /' __` __`\  /'___\ \ \/ \ \ \   
/\__, `\/\  __/\ \ \\ \ \_\ \ \ \L\ \/\______\ \ \L\ \ \ \/ \ \ \_\ \/\__, `\/\ \/\ \/\ \/\ \__/\ \ \_ \_\ \_ 
\/\____/\ \____\\ \__\ \____/\ \ ,__/\/______/\ \ ,__/\ \_\  \/`____ \/\____/\ \_\ \_\ \_\ \____\\ \__\/\____\
 \/___/  \/____/ \/__/\/___/  \ \ \/           \ \ \/  \/_/   `/___/> \/___/  \/_/\/_/\/_/\/____/ \/__/\/____/
                               \ \_\            \ \_\            /\___/                                       
                                \/_/             \/_/            \/__/                                        
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Installs prysmctl on the node server.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

declare latest_prysm_version
get_latest_prysm_version latest_prysm_version

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

# prysmctl filesystem
log info "Setting up prysmctl user, group, datadir..."
sudo useradd --no-create-home --shell /bin/false "$prysmctl_user"
sudo mkdir -p "$prysmctl_datadir"
sudo chown -R "${prysmctl_user}:${prysmctl_group}" "$prysmctl_datadir"
sudo chmod -R 770 "$prysmctl_datadir"

# prysmctl install
log info "Downloading prysmctl..."
install_prysm prysmctl \
	"$latest_prysm_version" "$prysmctl_bin" "$prysmctl_user" "$prysmctl_group"

# -------------------------- POSTCONDITIONS -----------------------------------

assert_sudo

reset_checks

check_executable_exists --sudo prysmctl_bin
check_user_exists prysmctl_user
check_group_exists prysmctl_group
check_directory_exists --sudo prysmctl_datadir

print_failed_checks --error

cat <<EOF

Success!  You are now ready to enable EL and CL services.
EOF
