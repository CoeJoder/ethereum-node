#!/bin/bash

# -------------------------- HEADER -------------------------------------------

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../scripts/common.sh"
housekeeping

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
Copies the scripts and unit files from the client PC to the node server.
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

assert_not_on_node_server

# -------------------------- RECONNAISSANCE -----------------------------------

if [[ $1 == '-h' ]]; then
	echo "usage: deploy.sh [--dry-run]" >&2
	exit 0
fi

RSYNC_OPTS=''
if [[ $1 == '--dry-run' ]]; then
	RSYNC_OPTS="$RSYNC_OPTS --dry-run"
fi

# -------------------------- EXECUTION ----------------------------------------

trap 'printerr_trap $? "$errmsg_retry"; exit $?' ERR

# overwrite non-generated files and remove deleted files i.e. those listed in 
# `includes.txt` but not existing in source filesystem
rsync -avh -e "ssh -p $node_server_ssh_port" \
	--progress \
	--delete \
	--include-from="$tools_dir/non-generated.txt" \
	--exclude="*" \
	$RSYNC_OPTS \
	"$scripts_dir" ${node_server_username}@${node_server_hostname}:

# overwrite generated files only if source copy is newer
rsync -avhu -e "ssh -p $node_server_ssh_port" \
	--progress \
	--include-from="$tools_dir/generated.txt" \
	--exclude="*" \
	$RSYNC_OPTS \
	"$scripts_dir" ${node_server_username}@${node_server_hostname}:

# -------------------------- POSTCONDITIONS -----------------------------------
