#!/bin/bash

# -------------------------- HEADER -------------------------------------------

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
housekeeping

function show_usage() {
	echo "usage: deploy.sh [--dry-run]" >&2
}

if [[ $1 == '-h' ]]; then
	show_usage
	exit 0
fi

rsync_opts=''
if [[ $# -gt 0 ]]; then
	if [[ $1 == '--dry-run' ]]; then
		rsync_opts='--dry-run'
	else
		printerr "unknown argument: $1"
		show_usage
		exit 1
	fi
fi

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_blue}
      :::::::::  :::::::::: :::::::::  :::        ::::::::  :::   :::
     :+:    :+: :+:        :+:    :+: :+:       :+:    :+: :+:   :+: 
    +:+    +:+ +:+        +:+    +:+ +:+       +:+    +:+  +:+ +:+   
   +#+    +:+ +#++:++#   +#++:++#+  +#+       +#+    +:+   +#++:     
  +#+    +#+ +#+        +#+        +#+       +#+    +#+    +#+       
 #+#    #+# #+#        #+#        #+#       #+#    #+#    #+#        
#########  ########## ###        ########## ########     ###         
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Copies the source scripts from the client PC to the node server.
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

assert_not_on_node_server

check_is_valid_port node_server_ssh_port
check_is_defined node_server_username
check_is_defined node_server_hostname

# careful changing these as they are params to rsync
dist_dirname='ethereum-node'
includes_non_generated="$tools_dir/non-generated.txt"
includes_generated="$tools_dir/generated.txt"
deploy_src_dir="$(realpath "$src_dir")/"

check_is_defined dist_dirname
check_file_exists includes_non_generated
check_file_exists includes_generated
check_directory_exists deploy_src_dir

print_failed_checks --error || exit

# -------------------------- RECONNAISSANCE -----------------------------------

printinfo "Ready to deploy with the following commands:"
cat <<EOF
${color_lightgray}
# overwrite non-generated files and remove deleted files i.e. those listed in 
# includes-file but not existing in source filesystem
rsync -avh -e "ssh -p $node_server_ssh_port" \\
	--progress \\
	--delete \\
	--include-from="$includes_non_generated" \\
	--exclude="*" \\
	$rsync_opts \\
	"$deploy_src_dir" "${node_server_username}@${node_server_hostname}:$dist_dirname"

# overwrite generated files only if source copy is newer
rsync -avhu -e "ssh -p $node_server_ssh_port" \\
	--progress \\
	--include-from="$includes_generated" \\
	--exclude="*" \\
	$rsync_opts \\
	"$deploy_src_dir" "${node_server_username}@${node_server_hostname}:$dist_dirname"
${color_reset}
EOF

yes_or_no --default-yes "Continue?" || exit 0

# -------------------------- EXECUTION ----------------------------------------

trap 'on_err_retry' ERR

printinfo "Deploying..."

# overwrite non-generated files and remove deleted files i.e. those listed in 
# includes-file but not existing in source filesystem
rsync -avh -e "ssh -p $node_server_ssh_port" \
	--progress \
	--delete \
	--include-from="$includes_non_generated" \
	--exclude="*" \
	$rsync_opts \
	"$deploy_src_dir" "${node_server_username}@${node_server_hostname}:$dist_dirname"

# overwrite generated files only if source copy is newer
rsync -avhu -e "ssh -p $node_server_ssh_port" \
	--progress \
	--include-from="$includes_generated" \
	--exclude="*" \
	$rsync_opts \
	"$deploy_src_dir" "${node_server_username}@${node_server_hostname}:$dist_dirname"

# -------------------------- POSTCONDITIONS -----------------------------------
