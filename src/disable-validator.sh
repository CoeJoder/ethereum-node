#!/bin/bash

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

disable_service prysm_validator_unit_file || exit
