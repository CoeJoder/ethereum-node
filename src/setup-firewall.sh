#!/bin/bash

# setup-firewall.sh
#
# Configures the firewall on the node server to allow only the ports needed for
# the Ethereum node software and rate-limited SSH access.
#
# Meant to be run on the node server.

# -------------------------- HEADER -------------------------------------------

set -e

this_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$this_dir/common.sh"
housekeeping

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server

reset_checks

for _command in ufw awk; do
	check_command_exists_on_path _command
done

check_is_valid_port node_server_ssh_port
check_is_valid_port geth_port
check_is_valid_port geth_discovery_port
check_is_valid_port prysm_beacon_p2p_tcp_port
check_is_valid_port prysm_beacon_p2p_udp_port
check_is_valid_port prysm_beacon_p2p_quic_port

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

show_banner "${bold}" <<EOF
                               ${color_red} (                            (  (     ${color_reset}${bold}
                               ${color_red} )\ ) (  (     (  (  (      ) )\ )\    ${color_reset}${bold}
          _                    ${color_red}(()/( )\ )(   ))\ )\))(  ( /(((_|(_)   ${color_reset}${bold}
 ___  ___| |_ _   _ _ __       ${color_red}/(_)|(_|()\ /((_|(_)()\ )(_))_  _      ${color_reset}${bold}
/ __|/ _ \ __| | | | '_ \ ____${color_yellow}(_) _|(_)((_|_)) _(()((_|(_)_| || |  ${color_reset}${bold}
\__ \  __/ |_| |_| | |_) |____|${color_yellow}|  _|| | '_/ -_)\ V  V / _\` | || | ${color_reset}${bold}
|___/\___|\__|\__,_| .__/      |_|  |_|_| \___| \_/\_/\__,_|_||_|                               
                   |_|                                                                          
EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Configures the firewall on the node server to allow only the ports needed for the Ethereum node software and rate-limited SSH access.
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

cat <<EOF
Ready to invoke the following ufw commands:${color_lightgray}
sudo ufw disable
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit ${node_server_ssh_port}/tcp comment 'Limit SSH port (TCP)'
sudo ufw allow ${geth_port}/tcp comment 'Allow Geth port (TCP)'
sudo ufw allow ${geth_discovery_port}/udp comment 'Allow Geth discovery port (UDP)'
sudo ufw allow ${prysm_beacon_p2p_tcp_port}/tcp comment 'Allow Prysm Beacon P2P port (TCP)'
sudo ufw allow ${prysm_beacon_p2p_quic_port}/udp comment 'Allow Prysm Beacon P2P port (UDP)'
sudo ufw allow ${prysm_beacon_p2p_udp_port}/udp comment 'Allow Prysm Beacon quic port (UDP)'
sudo ufw logging low
sudo ufw enable
sudo ufw status numbered
${color_reset}
EOF
continue_or_exit 0
printf '\n'

# -------------------------- EXECUTION ----------------------------------------

trap 'on_err_retry' ERR

sudo ufw disable
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit ${node_server_ssh_port}/tcp comment 'Limit SSH port (TCP)'
sudo ufw allow ${geth_port}/tcp comment 'Allow Geth port (TCP)'
sudo ufw allow ${geth_discovery_port}/udp comment 'Allow Geth discovery port (UDP)'
sudo ufw allow ${prysm_beacon_p2p_tcp_port}/tcp comment 'Allow Prysm Beacon P2P port (TCP)'
sudo ufw allow ${prysm_beacon_p2p_quic_port}/udp comment 'Allow Prysm Beacon P2P port (UDP)'
sudo ufw allow ${prysm_beacon_p2p_udp_port}/udp comment 'Allow Prysm Beacon quic port (UDP)'
sudo ufw logging low
sudo ufw enable
sudo ufw status

# -------------------------- POSTCONDITIONS -----------------------------------

assert_sudo
# shellcheck disable=SC2034  # suppress unused
ufw_status=$(sudo ufw status | awk -F' ' '{print $1" "$2}')

reset_checks
check_string_contains ufw_status "Status: active"
check_string_contains ufw_status "${node_server_ssh_port}/tcp LIMIT"
check_string_contains ufw_status "${geth_port}/tcp ALLOW"
check_string_contains ufw_status "${geth_discovery_port}/udp ALLOW"
check_string_contains ufw_status "${prysm_beacon_p2p_tcp_port}/tcp ALLOW"
check_string_contains ufw_status "${prysm_beacon_p2p_quic_port}/udp ALLOW"
check_string_contains ufw_status "${prysm_beacon_p2p_udp_port}/udp ALLOW"
print_failed_checks --error

cat <<EOF
Success!  Now you must configure your router for port forwarding...
EOF

# TODO see if port forwarding can be automated in OpenWRT and make a script if so
