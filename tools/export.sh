#!/bin/bash

# -------------------------- HEADER -------------------------------------------

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
housekeeping

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_blue}${bold}
      :::::::::: :::    ::: :::::::::   ::::::::  ::::::::: :::::::::::
     :+:        :+:    :+: :+:    :+: :+:    :+: :+:    :+:    :+:     
    +:+         +:+  +:+  +:+    +:+ +:+    +:+ +:+    +:+    +:+      
   +#++:++#     +#++:+   +#++:++#+  +#+    +:+ +#++:++#:     +#+       
  +#+         +#+  +#+  +#+        +#+    +#+ +#+    +#+    +#+        
 #+#        #+#    #+# #+#        #+#    #+# #+#    #+#    #+#         
########## ###    ### ###         ########  ###    ###    ###          
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Exports public data about the validators from the node server to the local 'DATA' flash drive.
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

assert_not_on_node_server
assert_sudo

check_is_defined ethereum_network
check_is_defined dist_dirname

check_is_valid_port node_server_ssh_port
check_is_defined node_server_username
check_is_defined node_server_hostname

check_is_defined prysm_validator_wallet_dir
check_is_defined prysm_validator_wallet_password_file
check_is_defined prysm_validator_user

check_is_defined client_pc_usb_data_drive
check_is_defined validator_statuses_json

usb_scripts_dir="$client_pc_usb_data_drive/$dist_dirname"
check_directory_exists --sudo usb_scripts_dir

print_failed_checks --error || exit

# -------------------------- RECONNAISSANCE -----------------------------------

node_server_ssh_endpoint="${node_server_username}@${node_server_hostname}"

# if validator accounts file already exists, confirm overwrite
reset_checks
check_file_does_not_exist --sudo validator_statuses_json
if ! print_failed_checks --warn; then
	continue_or_exit 1 "Overwrite?"
	printf '\n'
	# sudo rm -rf --interactive=never "$validator_statuses_json" 
fi

# -------------------------- EXECUTION ----------------------------------------

assert_sudo
set -e
trap 'on_err_retry' ERR

# create tempfiles
printinfo "Creating remote tempfile..."
remote_temp_file="$(ssh -p $node_server_ssh_port $node_server_ssh_endpoint "echo \"\$(mktemp)\"")"
local_temp_file="$(mktemp)"

# ensure that 'remote_temp_file' variable is set before interpolating remote commands
reset_checks
check_is_defined remote_temp_file
print_failed_checks --error

# delete remote temp file on exit
function on_exit() {
	printinfo -n "Cleaning up..."

	# delete remote tempfile if it exists
	ssh -p $node_server_ssh_port $node_server_ssh_endpoint "
		temp_file=\"$remote_temp_file\"
		[[ -f \$temp_file ]] && rm -rf --interactive=never \"\$temp_file\" &>/dev/null
	"

	# delete local tempfile if it exists
	if [[ -f $local_temp_file ]]; then
		rm -rf --interactive=never "$local_temp_file" &>/dev/null
	fi

	print_ok
}
trap 'on_exit' EXIT

# gather info about the validator server-side
ssh -p $node_server_ssh_port $node_server_ssh_endpoint -t "
	set -e
	source \"\$HOME/$dist_dirname/common.sh\"
	set_env
	printinfo \"Logged into node server.\"
	assert_sudo

	reset_checks
	temp_file=\"$remote_temp_file\"
	check_file_exists --sudo temp_file
	check_executable_exists --sudo prysm_validator_bin
	print_failed_checks --error

	printinfo "Fetching validator indices..."
	sudo -u \"\$prysm_validator_user\" \"\$prysm_validator_bin\" accounts list \\
		--wallet-dir=\"\$prysm_validator_wallet_dir\" \\
		--wallet-password-file=\"\$prysm_validator_wallet_password_file\" \\
		--list-validator-indices \\
		--accept-terms-of-use \\
		--\${ethereum_network} 2>/dev/null | tee -a \"\$temp_file\"
	
	printinfo \"Querying beacon chain for status of each validator...\"
	validator_indices=\"\$(awk 'NR>1 {print \$2}' \"\$temp_file\")\"
	validator_indices_csv=\"\${validator_indices//\$'\\n'/,}\"
	api_url=\"http://localhost:3500/eth/v1/beacon/states/head/validators?id=\$validator_indices_csv\"
	echo \"curl -X 'GET' \\\"\$api_url\\\" -H 'accept: application/json'\"
	curl -X 'GET' \"\$api_url\" -H 'accept: application/json' > \"\$temp_file\"
"

# copy the gathered server-side info to local tempfile
printinfo "Copying validator statuses to local tempfile..."
rsync -avh -e "ssh -p $node_server_ssh_port" \
	--progress \
	"${node_server_ssh_endpoint}:${remote_temp_file}" "$local_temp_file"

# prettify the tempfile and move it to local 'DATA' drive
printinfo "Transforming JSON and moving to 'DATA' drive..."
jq '.data' "$local_temp_file" | sudo tee "$validator_statuses_json"

# -------------------------- POSTCONDITIONS -----------------------------------

reset_checks
check_file_exists --sudo validator_statuses_json
print_failed_checks --error

cat <<-EOF

Validator statuses exported.
To view file: ${theme_command}less -R "$validator_statuses_json"${color_reset}
EOF
