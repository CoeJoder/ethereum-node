#!/bin/bash

# unseal.sh
#
# Unseals the USB-deployed files for use by changing owner and permissions.
#
# Should be `source`d to run in the caller's shell.

if [[ ${BASH_SOURCE[-1]} == "$0" ]]; then
	echo "script must be sourced, not run directly" >&2
	exit 1
fi

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
