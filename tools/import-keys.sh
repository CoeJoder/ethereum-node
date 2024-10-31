#!/bin/bash

# -------------------------- HEADER -------------------------------------------

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
housekeeping

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_blue}${bold}
      :::::::::::   :::   :::   :::::::::   ::::::::  ::::::::: :::::::::::
         :+:      :+:+: :+:+:  :+:    :+: :+:    :+: :+:    :+:    :+:     
        +:+     +:+ +:+:+ +:+ +:+    +:+ +:+    +:+ +:+    +:+    +:+      
       +#+     +#+  +:+  +#+ +#++:++#+  +#+    +:+ +#++:++#:     +#+       
      +#+     +#+       +#+ +#+        +#+    +#+ +#+    +#+    +#+        
     #+#     #+#       #+# #+#        #+#    #+# #+#    #+#    #+#         
########### ###       ### ###         ########  ###    ###    ###          
                    :::    ::: :::::::::: :::   :::  ::::::::              
                   :+:   :+:  :+:        :+:   :+: :+:    :+:              
                  +:+  +:+   +:+         +:+ +:+  +:+                      
   +#++:++#++:++ +#++:++    +#++:++#     +#++:   +#++:++#++                
                +#+  +#+   +#+           +#+           +#+                 
               #+#   #+#  #+#           #+#    #+#    #+#                  
              ###    ### ##########    ###     ########                    
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Imports the validator keys from the local 'DATA' flash drive to the node server.
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

check_is_defined prysm_validator_keys_dir
check_is_defined prysm_validator_wallet_dir
check_is_defined prysm_validator_wallet_password_file
check_is_defined prysm_validator_user
check_is_defined prysm_validator_group

check_is_defined client_pc_usb_data_drive

# careful changing these as they are params to rsync
usb_validator_keys="$usb_dist_dir/validator_keys"

check_directory_exists --sudo usb_dist_dir
check_directory_exists --sudo usb_validator_keys

print_failed_checks --error || exit

# -------------------------- RECONNAISSANCE -----------------------------------

node_server_ssh_endpoint="${node_server_username}@${node_server_hostname}"

# -------------------------- EXECUTION ----------------------------------------

# STRATEGY
# The file transfer and other tasks require elevated remote permissions, but we
# don't want to compromise security with passwordless SSH root creds or altered
# sudoer rules.  Thus we will perform the copy in multiple steps. Despite
# requiring multiple sessions, ssh-agent makes this approach seamless.
#
# ALGORITHM
# 1. create a non-root tempdir in the remote filesystem
# 2. file transfer into the tempdir via rsync/SSH
# 3. perform elevated tasks (copy, chown, chmod) via pseudo-TTY/SSH
# 4. delete the tempdir on shell-exit

assert_sudo
trap 'on_err_retry' ERR

# chown the `DATA` dir and pushd into it
printinfo "Chowning the source files..."
sudo chown -R "$USER:$USER" "$usb_dist_dir"
pushd "$usb_dist_dir" >/dev/null

# 1. create remote tempdir
printinfo "Creating remote tempdir..."
remote_temp_dir="$(ssh -p $node_server_ssh_port $node_server_ssh_endpoint "echo \"\$(mktemp -d)\"")"

function on_exit() {
	printinfo -n "Cleaning up..."
	popd >/dev/null

	# 4. delete the remote tempdir if it exists
	ssh -p $node_server_ssh_port $node_server_ssh_endpoint "
		temp_dir=\"$remote_temp_dir\"
		[[ -d \$temp_dir ]] && rm -rf --interactive=never \"\$temp_dir\" >/dev/null"
	print_ok
}
trap 'on_exit' EXIT

# ensure that 'remote_temp_dir' variable is set before interpolating remote commands
reset_checks
check_is_defined remote_temp_dir
print_failed_checks --error # trapped

# 2. copy into tempdir
printinfo "Copying validator keys to remote tempdir..."
rsync -avh -e "ssh -p $node_server_ssh_port" \
	--progress \
	"$usb_validator_keys" "${node_server_ssh_endpoint}:${remote_temp_dir}"

# 3. copy to the target dir, set ownership, set permissions, and import
ssh -p $node_server_ssh_port $node_server_ssh_endpoint -t "
	set -e
	source \"\$HOME/$dist_dirname/common.sh\"
	printinfo \"Logged into node server.\"
	
	assert_sudo
	if sudo test -d \"$prysm_validator_keys_dir\"; then
		printwarn \"Destination already exists: $prysm_validator_keys_dir\"
		continue_or_exit 1 \"Overwrite?\"
		sudo rm -rfv --interactive=never \"$prysm_validator_keys_dir\"
	fi

	printinfo \"Copying validator keys from tempdir to prysm-validator dir...\"
	sudo cp -rfv \"$remote_temp_dir\" \"$prysm_validator_keys_dir\"

	printinfo \"Setting validator keys ownership...\"
	sudo chown -R \"${prysm_validator_user}:${prysm_validator_group}\" \"$prysm_validator_keys_dir\"

	printinfo \"Setting validator keys permission bits...\"
	sudo chmod -R 700 \"$prysm_validator_keys_dir\"

	printinfo \"Importing validator keys...\"
	sudo -u \"$prysm_validator_user\" validator accounts import \\
		--keys-dir=\"$prysm_validator_keys_dir\" \\
		--wallet-dir=\"$prysm_validator_wallet_dir\" \\
		--accept-terms-of-use \\
		--${ethereum_network}
"

# -------------------------- POSTCONDITIONS -----------------------------------

printinfo "Verify that the new accounts are listed here:"
ssh -p $node_server_ssh_port $node_server_ssh_endpoint "
	sudo -u \"$prysm_validator_user\" validator accounts list \\
		--wallet-dir=\"$prysm_validator_wallet_dir\" \\
		--wallet-password-file=\"$prysm_validator_wallet_password_file\" \\
		--accept-terms-of-use \\
		--${ethereum_network}
"

cat <<-EOF

After verifying the above, you are ready to upload your deposit data.
EOF
