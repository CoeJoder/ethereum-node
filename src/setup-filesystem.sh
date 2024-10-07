#!/bin/bash

# -------------------------- HEADER -------------------------------------------

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
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
Creates the users, groups, directories required to run a self-managed Ethereum validator node.
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server
assert_sudo

sudo check_directory_exists node_server_secondary_storage

sudo check_user_does_not_exist geth_user
sudo check_user_does_not_exist prysm_beacon_user
sudo check_user_does_not_exist prysm_validator_user

sudo check_group_does_not_exist geth_group
sudo check_group_does_not_exist prysm_beacon_group
sudo check_group_does_not_exist prysm_validator_group

sudo check_directory_does_not_exist geth_datadir
sudo check_directory_does_not_exist geth_datadir_secondary
sudo check_directory_does_not_exist geth_datadir_secondary_ancient
sudo check_directory_does_not_exist prysm_beacon_datadir
sudo check_directory_does_not_exist prysm_validator_datadir

print_failed_checks --error || exit

exit 0

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

trap 'on_err_noretry' ERR

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

assert_sudo

sudo check_directory_exists node_server_secondary_storage

sudo check_user_exists geth_user
sudo check_user_exists prysm_beacon_user
sudo check_user_exists prysm_validator_user

sudo check_group_exists geth_group
sudo check_group_exists prysm_beacon_group
sudo check_group_exists prysm_validator_group

sudo check_directory_exists geth_datadir
sudo check_directory_exists geth_datadir_secondary
sudo check_directory_exists geth_datadir_secondary_ancient
sudo check_directory_exists prysm_beacon_datadir
sudo check_directory_exists prysm_validator_datadir

print_failed_checks --error

cat <<EOF

Success!  Now you are ready to install the Ethereum node software.
EOF
