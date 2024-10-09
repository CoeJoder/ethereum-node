#!/bin/bash

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

enable_service geth_unit_file || exit
sudo journalctl -fu "$(basename "$geth_unit_file")"
