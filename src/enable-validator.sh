#!/bin/bash

src_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$src_dir/common.sh"
housekeeping

enable_service prysm_validator_unit_file prysm_validator_bin