#!/bin/bash

# withdraw.sh
#
# Uploads the `bls-to-execution-change` message from the `DATA` flash drive
# to the node server, then submits it via prysm-beacon, initiating withdrawal.
#
# Meant to be executed on the client PC.

# -------------------------- HEADER -------------------------------------------

set -e

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

assert_not_on_node_server
assert_sudo

check_is_defined ethereum_network
check_is_defined dist_dirname

check_is_valid_port node_server_ssh_port
check_is_defined node_server_username
check_is_defined node_server_hostname

check_is_defined prysm_validator_keys_dir
check_is_defined prysm_validator_wallet_dir
check_is_defined prysm_validator_wallet_password_file
check_is_defined prysm_validator_user
check_is_defined prysm_validator_group

check_is_defined client_pc_usb_data_drive

usb_bls_to_execution_changes_dir="$usb_dist_dir/bls_to_execution_changes"

check_directory_exists --sudo usb_dist_dir
check_directory_exists --sudo usb_bls_to_execution_changes_dir

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

echo -ne "${color_blue}${bold}"
cat <<'EOF'
           _ __  __        __                   
 _      __(_) /_/ /_  ____/ /________ __      __
| | /| / / / __/ __ \/ __  / ___/ __ `/ | /| / /
| |/ |/ / / /_/ / / / /_/ / /  / /_/ /| |/ |/ / 
|__/|__/_/\__/_/ /_/\__,_/_/   \__,_/ |__/|__/  
EOF
echo -ne "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

cat <<'EOF'

Uploads the `bls-to-execution-change` message from the `DATA` flash drive to the node server, then submits it via prysm-beacon, initiating withdrawal.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

node_server_ssh_endpoint="${node_server_username}@${node_server_hostname}"
bls_to_execution_change_message_format='bls_to_execution_change-*.json'

# chown the `DATA` dir and cd into it
printinfo "Chowning the source files..."
sudo chown -R "$USER:$USER" "$usb_dist_dir"
sudo chmod 700 "$usb_dist_dir"
cd "$usb_dist_dir" >/dev/null

# search for bls messages
printinfo "Searching for \`bls-to-execution-change\` messages on \`DATA\` drive..."
readarray -td '' bls_messages < <(LC_ALL=C find \
	"$usb_bls_to_execution_changes_dir" -maxdepth 1 -name \
	"$bls_to_execution_change_message_format" -type f -printf '%T@/%P\0' |
	sort -rzn | cut -zd/ -f2-)

# prompt for which bls message to submit if multiple found
if ((${#bls_messages[@]} == 0)); then
	printerr "No bls messages found in ${theme_filename}$usb_bls_to_execution_changes_dir${color_reset}"
	exit 1
elif ((${#bls_messages[@]} == 1)); then
	bls_message="${bls_messages[0]}"
	printinfo "Found ${theme_filename}$bls_message${color_reset}"
	continue_or_exit
else
	printwarn "Multiple bls messages found!"
	choose_from_menu "Please select one to submit:" bls_message "${bls_messages[@]}"
	continue_or_exit
fi

# -------------------------- EXECUTION ----------------------------------------

assert_sudo
trap 'on_err_retry' ERR

# 1. create remote tempdir
printinfo "Creating remote tempdir..."
remote_temp_dir="$(ssh -p $node_server_ssh_port $node_server_ssh_endpoint "echo \"\$(mktemp -d)\"")"

function on_exit() {
	printinfo -n "Cleaning up..."

	# 4. delete the remote tempdir if it exists
	ssh -p $node_server_ssh_port $node_server_ssh_endpoint "
		rm -rf --interactive=never \"$remote_temp_dir\" >/dev/null"

	# 5. reseal the USB deployment
	sudo chown -R root:root "$usb_dist_dir"
	sudo chmod 0 "$usb_dist_dir"
	
	print_ok
}
trap 'on_exit' EXIT

# ensure that 'remote_temp_dir' variable is set before interpolating remote commands
reset_checks
check_is_defined remote_temp_dir
print_failed_checks --error

# 2. copy into tempdir
printinfo "Copying \`bls-to-execution-change\` message to remote tempdir..."
rsync -avh -e "ssh -p $node_server_ssh_port" \
	--progress \
	"$usb_bls_to_execution_changes_dir/$bls_message" "${node_server_ssh_endpoint}:${remote_temp_dir}"

# 3. run the remote submission script
ssh -p $node_server_ssh_port $node_server_ssh_endpoint -t "
	\"\$HOME/$dist_dirname/submit-bls-to-execution-change-message.sh\" --path=\"$remote_temp_dir/$bls_message\"
"

# -------------------------- POSTCONDITIONS -----------------------------------
