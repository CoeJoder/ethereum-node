#!/bin/bash

# unseal.sh
#
# Unseals the USB-deployed files for use by changing owner and permissions.
#
# Should be `source`d to run in the caller's shell.

_dist_dirname='ethereum-node'
if [[ -d $_dist_dirname ]]; then
	sudo chown -R "$USER:$USER" "$_dist_dirname"
	sudo chmod 700 "$_dist_dirname"
	# shellcheck disable=SC2164  # failed `cd` is OK
	cd "$_dist_dirname"
else
	echo "folder not found: $_dist_dirname"
fi
unset _dist_dirname
