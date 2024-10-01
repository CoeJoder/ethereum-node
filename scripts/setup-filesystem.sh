#!/bin/bash

# -------------------------- HEADER -------------------------------------------

scripts_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$scripts_dir/common.sh"
housekeeping

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_cyan}
░█▀▀░█▀▀░▀█▀░█░█░█▀█░░░░░█▀▀░▀█▀░█░░░█▀▀░█▀▀░█░█░█▀▀░▀█▀░█▀▀░█▄█
░▀▀█░█▀▀░░█░░█░█░█▀▀░▄▄▄░█▀▀░░█░░█░░░█▀▀░▀▀█░░█░░▀▀█░░█░░█▀▀░█░█
░▀▀▀░▀▀▀░░▀░░▀▀▀░▀░░░░░░░▀░░░▀▀▀░▀▀▀░▀▀▀░▀▀▀░░▀░░▀▀▀░░▀░░▀▀▀░▀░▀
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Creates the users, groups, directories required to run a self-managed Ethereum
validator node.
EOF

press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server

check_directory_exists node_server_secondary_storage

check_user_does_not_exist geth_user
check_user_does_not_exist prysm_beacon_user
check_user_does_not_exist prysm_validator_user

check_group_does_not_exist geth_group
check_group_does_not_exist prysm_beacon_group
check_group_does_not_exist prysm_validator_group

check_directory_does_not_exist geth_datadir
check_directory_does_not_exist geth_datadir_secondary
check_directory_does_not_exist geth_datadir_secondary_ancient
check_directory_does_not_exist prysm_beacon_datadir
check_directory_does_not_exist prysm_validator_datadir

exit_if_failed_checks

# -------------------------- RECONNAISSANCE -----------------------------------

cat <<EOF

Ready to invoke the following commands:${color_lightgray}
# geth setup
sudo useradd --no-create-home --shell /bin/false "$geth_user"
sudo mkdir -p "$geth_datadir"
sudo mkdir -p "$geth_datadir_secondary_ancient"
sudo chown -R "${geth_user}:${geth_group}" ${geth_datadir}
sudo chown -R "${geth_user}:${geth_group}" ${geth_datadir_secondary}
sudo chmod -R 700 "${geth_datadir}"
sudo chmod -R 700 "${geth_datadir_secondary}"

# prysm-beacon setup
sudo useradd --no-create-home --shell /bin/false "$prysm_beacon_user"
sudo mkdir -p "$prysm_beacon_datadir"
sudo chown -R "${prysm_beacon_user}:${prysm_beacon_group}" "$prysm_beacon_datadir"
sudo chmod -R 700 "$prysm_beacon_datadir"

# prysm-validator setup
sudo useradd --no-create-home --shell /bin/false "$prysm_validator_user"
sudo mkdir -p "$prysm_validator_datadir"
sudo chown -R "${prysm_validator_user}:${prysm_validator_group}" "$prysm_validator_datadir"
sudo chmod -R 700 "$prysm_validator_datadir"
${color_reset}
EOF

continue_or_exit 1

# -------------------------- EXECUTION ----------------------------------------

trap 'printerr_trap $? "$errmsg_noretry"; exit $?' ERR

# geth setup
sudo useradd --no-create-home --shell /bin/false "$geth_user"
sudo mkdir -p "$geth_datadir"
sudo mkdir -p "$geth_datadir_secondary_ancient"
sudo chown -R "${geth_user}:${geth_group}" ${geth_datadir}
sudo chown -R "${geth_user}:${geth_group}" ${geth_datadir_secondary}
sudo chmod -R 700 "${geth_datadir}"
sudo chmod -R 700 "${geth_datadir_secondary}"

# prysm-beacon setup
sudo useradd --no-create-home --shell /bin/false "$prysm_beacon_user"
sudo mkdir -p "$prysm_beacon_datadir"
sudo chown -R "${prysm_beacon_user}:${prysm_beacon_group}" "$prysm_beacon_datadir"
sudo chmod -R 700 "$prysm_beacon_datadir"

# prysm-validator setup
sudo useradd --no-create-home --shell /bin/false "$prysm_validator_user"
sudo mkdir -p "$prysm_validator_datadir"
sudo chown -R "${prysm_validator_user}:${prysm_validator_group}" "$prysm_validator_datadir"
sudo chmod -R 700 "$prysm_validator_datadir"

# -------------------------- POSTCONDITIONS -----------------------------------

cat <<EOF

Success!  Now you are ready to install the Ethereum node software.

EOF
