#!/bin/bash

src_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$src_dir/common.sh"
housekeeping

enable_service prysm_beacon_unit_file prysm_beacon_bin
