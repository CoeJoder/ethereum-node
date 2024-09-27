#!/bin/bash

# -------------------------- HEADER -------------------------------------------

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../scripts/common.sh"

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

cat << EOF
Copies the scripts and unit files from the client PC to the node server.

EOF

# -------------------------- PRECONDITIONS ------------------------------------

assert_not_on_node_server

# -------------------------- RECONNAISSANCE -----------------------------------

if [[ $1 == '-h' ]]; then
  echo "usage: deploy.sh [--dry-run]" >&2
  exit 0
fi

if [[ $1 == '--dry-run' ]]; then
  RSYNC_OPTS='--dry-run'
fi

# -------------------------- EXECUTION ----------------------------------------

# deploy into `$HOME/scripts`
rsync -avh -e "ssh -p $node_server_ssh_port" \
  --progress \
  --include-from="$tools_dir/includes.txt" \
  --exclude="*" \
  $RSYNC_OPTS \
  "$scripts_dir" ${node_server_username}@${node_server_hostname}:
