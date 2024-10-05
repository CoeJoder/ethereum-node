#!/bin/bash

src_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$src_dir/common.sh"
housekeeping

disable_service geth_unit_file geth_bin
