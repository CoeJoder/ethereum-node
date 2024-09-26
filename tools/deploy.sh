#!/bin/bash

# -------------------------- PREAMBLE -----------------------------------------

this_dir="$(dirname "$(realpath "$0")")"
scripts_dir="$(realpath "${this_dir}/../scripts")"
common_sh="$scripts_dir/common.sh"
env_sh="$scripts_dir/env.sh"
source "$common_sh"
source "$env_sh"

# -------------------------- BANNER -------------------------------------------

echo "${color_blue}"
echo "      :::::::::  :::::::::: :::::::::  :::        ::::::::  :::   :::"
echo "     :+:    :+: :+:        :+:    :+: :+:       :+:    :+: :+:   :+: "
echo "    +:+    +:+ +:+        +:+    +:+ +:+       +:+    +:+  +:+ +:+   "
echo "   +#+    +:+ +#++:++#   +#++:++#+  +#+       +#+    +:+   +#++:     "
echo "  +#+    +#+ +#+        +#+        +#+       +#+    +#+    +#+       "
echo " #+#    #+# #+#        #+#        #+#       #+#    #+#    #+#        "
echo "#########  ########## ###        ########## ########     ###         "
echo "${color_reset}"

# -------------------------- RECONNAISSANCE -----------------------------------

if [[ $1 == '-h' ]]; then
    echo "usage: deploy.sh [--dry-run]" >&2
    exit 0
fi

if [[ $(hostname) == $node_server_hostname ]]; then
  printerr "script must be run on the client PC, not the node server"
  exit 1
fi

if [[ $1 == '--dry-run' ]]; then
  RSYNC_OPTS='--dry-run'
fi

# -------------------------- COMMENCEMENT -------------------------------------

# deploy into `$HOME/scripts`
rsync -avh -e "ssh -p $node_server_ssh_port" \
  --progress \
  --include-from="$this_dir/includes.txt" \
  --exclude="*" \
  $RSYNC_OPTS \
  "$scripts_dir" ${node_server_username}@${node_server_hostname}:
