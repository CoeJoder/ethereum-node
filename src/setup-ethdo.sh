#!/bin/bash

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server
assert_sudo

check_user_does_not_exist ethdo_user
check_group_does_not_exist ethdo_group

check_is_defined ethdo_version
check_is_defined ethdo_sha256_checksum
check_executable_does_not_exist --sudo ethdo_bin

check_is_defined ethereal_version
check_is_defined ethereal_sha256_checksum
check_executable_does_not_exist --sudo ethereal_bin

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

echo -en "${color_green}${bold}"
cat <<'EOF'
              __                               
             /\ \__                            
  ____     __\ \ ,_\  __  __  _____            
 /',__\  /'__`\ \ \/ /\ \/\ \/\ '__`\  _______ 
/\__, `\/\  __/\ \ \_\ \ \_\ \ \ \L\ \/\______\
\/\____/\ \____\\ \__\\ \____/\ \ ,__/\/______/
 \/___/  \/____/ \/__/ \/___/  \ \ \/          
                                \ \_\          
                                 \/_/          
      __    __          __                     
     /\ \__/\ \        /\ \                    
   __\ \ ,_\ \ \___    \_\ \    ___            
 /'__`\ \ \/\ \  _ `\  /'_` \  / __`\          
/\  __/\ \ \_\ \ \ \ \/\ \L\ \/\ \L\ \         
\ \____\\ \__\\ \_\ \_\ \___,_\ \____/         
 \/____/ \/__/ \/_/\/_/\/__,_ /\/___/          
EOF
echo -en "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF

Installs ethdo & ethereal on the node server.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

# check for latest versions
get_latest_ethdo_version latest_ethdo_version
get_latest_ethereal_version latest_ethereal_version

_new_version_detected=false
if [[ $ethdo_version != $latest_ethdo_version ]]; then
	_new_version_detected=true
	printwarn "New version of ethdo detected: ${theme_value}$latest_ethdo_version${color_reset}"
fi
if [[ $ethereal_version != $latest_ethereal_version ]]; then
	_new_version_detected=true
	printwarn "New version of ethereal detected: ${theme_value}$latest_ethereal_version${color_reset}"
fi

if [[ $_new_version_detected == true ]]; then
	printwarn "It is suggested to update env vars with latest version checksums and then restart script."
	continue_or_exit 1 "Continue anyways with older versions?"
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

# ethdo user, group, filesystem
printinfo "Creating user, group, and datadir for ethdo & ethereal..."
sudo useradd --no-create-home --shell /bin/false "$ethdo_user"
sudo mkdir -p "$ethdo_datadir"
sudo chown -R "${ethdo_user}:${ethdo_group}" "$ethdo_datadir"
sudo chmod -R 700 "$ethdo_datadir"
sudo usermod --home "$ethdo_datadir" "$ethdo_user"

# ethdo install
printinfo "Installing ethdo..."
install_wealdtech ethdo \
	"$ethdo_version" "$ethdo_sha256_checksum" "$ethdo_bin" "$ethdo_user" "$ethdo_group"

# ethereal install
printinfo "Installing ethereal..."
install_wealdtech ethereal \
	"$ethereal_version" "$ethereal_sha256_checksum" "$ethereal_bin" "$ethdo_user" "$ethdo_group"

# -------------------------- POSTCONDITIONS -----------------------------------

assert_sudo

reset_checks

check_user_exists ethdo_user
check_group_exists ethdo_group
check_executable_exists --sudo ethdo_bin
check_executable_exists --sudo ethereal_bin

print_failed_checks --error

cat <<EOF

Success!  Ethdo and Ethereal have been installed on the node server.
EOF
