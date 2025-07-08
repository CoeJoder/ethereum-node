#!/bin/bash

# seal.sh
#
# Seals the USB-deployed files for security by changing owner and permissions.
#
# Should be `source`d to run in the caller's shell.

_dist_dirname='ethereum-node'
if [[ $(basename "$(pwd)") == "$_dist_dirname" ]]; then
	cd ..
fi
if [[ -d $_dist_dirname ]]; then
	sudo chown -R root:root "$_dist_dirname"
	sudo chmod 0 "$_dist_dirname"
else
	echo "folder not found: $_dist_dirname"
fi
unset _dist_dirname
