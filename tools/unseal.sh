#!/bin/bash

# unseal.sh
#
# The first script run on the air-gapped PC, which changes the owner and
# permissions of the deployed dir on the USB drive.
#
# Meant to be `source`d on the air-gapped PC.

dist_dirname='ethereum-node'
if [[ ! -d $dist_dirname ]]; then
	echo "folder not found: $dist_dirname"
	exit 1
fi
sudo chown -R "$USER:$USER" "$dist_dirname"
sudo chmod 700 "$dist_dirname"
cd "$dist_dirname"
unset dist_dirname
