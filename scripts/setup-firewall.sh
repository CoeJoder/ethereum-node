#!/bin/bash

# -------------------------- HEADER -------------------------------------------

scripts_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$scripts_dir/common.sh"
log_start
log_timestamp

# -------------------------- BANNER -------------------------------------------

cat <<EOF
                               ${color_red} (                            (  (     ${color_reset}
                               ${color_red} )\ ) (  (     (  (  (      ) )\ )\    ${color_reset}
          _                    ${color_red}(()/( )\ )(   ))\ )\))(  ( /(((_|(_)   ${color_reset}
 ___  ___| |_ _   _ _ __       ${color_red}/(_)|(_|()\ /((_|(_)()\ )(_))_  _      ${color_reset}
/ __|/ _ \ __| | | | '_ \ ____${color_yellow}(_) _|(_)((_|_)) _(()((_|(_)_| || |  ${color_reset}
\__ \  __/ |_| |_| | |_) |____|${color_yellow}|  _|| | '_/ -_)\ V  V / _\` | || | ${color_reset}
|___/\___|\__|\__,_| .__/      |_|  |_|_| \___| \_/\_/\__,_|_||_|                               
                   |_|                                                                          

EOF

# -------------------------- PREAMBLE -----------------------------------------

cat <<EOF
Configures the firewall on the node server to allow only the ports needed for
the Ethereum node software and rate-limited SSH access.
To abort this process, press ${color_green}ctrl + c${color_reset}.

EOF

# -------------------------- PRECONDITIONS ------------------------------------

assert_on_node_server

# -------------------------- RECONNAISSANCE -----------------------------------

read_default "\nSSH port (TCP)" "$node_server_ssh_port" node_server_ssh_port
read_default "Geth port (TCP)" "$geth_port" geth_port
read_default "Geth discovery port (UDP)" "$geth_discovery_port" geth_discovery_port
read_default "Prysm Beacon P2P port (TCP)" "$prysm_beacon_p2p_tcp_port" prysm_beacon_p2p_tcp_port
read_default "Prysm Beacon P2P port (UDP)" "$prysm_beacon_p2p_udp_port" prysm_beacon_p2p_udp_port
read_default "Prysm Beacon quic port (UDP)" "$prysm_beacon_p2p_quic_port" prysm_beacon_p2p_quic_port

# -------------------------- EXECUTION ----------------------------------------

trap 'printerr_trap $? "$errmsg_retry"; exit $?' ERR

echo -e "\nReady to invoke the following ufw commands:${color_lightgray}
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
${color_reset}"

read -p "Continue? (y/N): " confirm &&
	[[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

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

# -------------------------- POSTCONDITIONS -----------------------------------

echo "Success!  Now you must configure your router for port forwarding..."
# TODO see if port forwarding can be automated in OpenWRT and make a script if so
