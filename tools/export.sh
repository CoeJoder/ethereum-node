#!/bin/bash

# export.sh
#
# Exports public data about the validators from the node server to the local
# 'DATA' flash drive.
#
# Meant to be run on the client PC.

# -------------------------- HEADER -------------------------------------------

set -e

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

assert_not_on_node_server
assert_sudo

check_is_valid_port node_server_ssh_port
check_is_defined node_server_username
check_is_defined node_server_hostname

check_is_defined dist_dirname
check_is_defined validator_statuses_json

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

show_banner "${color_blue}${bold}" <<'EOF'
      :::::::::: :::    ::: :::::::::   ::::::::  ::::::::: :::::::::::
     :+:        :+:    :+: :+:    :+: :+:    :+: :+:    :+:    :+:     
    +:+         +:+  +:+  +:+    +:+ +:+    +:+ +:+    +:+    +:+      
   +#++:++#     +#++:+   +#++:++#+  +#+    +:+ +#++:++#:     +#+       
  +#+         +#+  +#+  +#+        +#+    +#+ +#+    +#+    +#+        
 #+#        #+#    #+# #+#        #+#    #+# #+#    #+#    #+#         
########## ###    ### ###         ########  ###    ###    ###          
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Exports public data about the validators from the node server to the local 'DATA' flash drive.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

node_server_ssh_endpoint="${node_server_username}@${node_server_hostname}"

# make the dist dir in case deployment of scripts hasn't been done yet
sudo mkdir -p "$usb_dist_dir"

# if validator statuses file already exists, confirm overwrite
reset_checks
check_file_does_not_exist --sudo validator_statuses_json
if ! print_failed_checks --warn; then
	continue_or_exit 1 "Overwrite?"
	printf '\n'
fi

# -------------------------- EXECUTION ----------------------------------------

assert_sudo
trap 'on_err_retry' ERR

# create local & remote temp files
remote_temp_file="$(ssh -p $node_server_ssh_port $node_server_ssh_endpoint "echo \"\$(mktemp)\"")"
local_temp_file="$(mktemp)"

# ensure that 'remote_temp_file' variable is set before interpolating remote commands
reset_checks
check_is_defined remote_temp_file
print_failed_checks --error

# delete remote temp file on exit
function on_exit() {
	printinfo -n "Cleaning up..."
	ssh -p $node_server_ssh_port $node_server_ssh_endpoint "
		rm -f --interactive=never \"$remote_temp_file\" &>/dev/null"
	rm -f --interactive=never "$local_temp_file" &>/dev/null
	print_ok
}
trap 'on_exit' EXIT

# run the remote getter script
ssh -p $node_server_ssh_port $node_server_ssh_endpoint -t "
	\"\$HOME/$dist_dirname/get-validator-statuses.sh\" \"$remote_temp_file\"
"

printinfo "Transferring remote output to local 'DATA' drive..."
rsync -avh -e "ssh -p $node_server_ssh_port" \
	--progress \
	"${node_server_ssh_endpoint}:${remote_temp_file}" "$local_temp_file"
sudo mv -fv "$local_temp_file" "$validator_statuses_json"

# -------------------------- POSTCONDITIONS -----------------------------------

reset_checks
check_file_exists --sudo validator_statuses_json
print_failed_checks --error

cat <<-EOF

	Saved as:
	${theme_command}$validator_statuses_json${color_reset}
EOF
