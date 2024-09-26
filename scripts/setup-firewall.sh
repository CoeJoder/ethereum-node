#!/bin/bash

# -------------------------- PREAMBLE -----------------------------------------

this_dir="$(dirname "$(realpath "$0")")"
common_sh="$this_dir/common.sh"
env_sh="$this_dir/env.sh"
source "$common_sh"
source "$env_sh"

# -------------------------- BANNER -------------------------------------------

printf "\n"
echo "                               ${color_red} (                            (  (     ${color_reset}"
echo "                               ${color_red} )\ ) (  (     (  (  (      ) )\ )\    ${color_reset}"
echo "          _                    ${color_red}(()/( )\ )(   ))\ )\))(  ( /(((_|(_)   ${color_reset}"
echo " ___  ___| |_ _   _ _ __       ${color_red}/(_)|(_|()\ /((_|(_)()\ )(_))_  _      ${color_reset}"
echo "/ __|/ _ \ __| | | | '_ \ ____${color_yellow}(_) _|(_)((_|_)) _(()((_|(_)_| || |  ${color_reset}"
echo "\__ \  __/ |_| |_| | |_) |____|${color_yellow}|  _|| | '_/ -_)\ V  V / _\` | || | ${color_reset}"
echo "|___/\___|\__|\__,_| .__/      |_|  |_|_| \___| \_/\_/\__,_|_||_|                               "
echo "                   |_|                                                                          "
printf "\n"

# -------------------------- RECONNAISSANCE -----------------------------------

if [[ $(hostname) != $node_server_hostname ]]; then
  printerr "script must be run on the node server: $node_server_hostname"
  exit 1
fi

read_default "\nSSH port (TCP)" "$node_server_ssh_port" node_server_ssh_port
read_default "Geth port (TCP)" "$geth_port" geth_port
read_default "Geth discovery port (UDP)" "$geth_discovery_port" geth_discovery_port
read_default "Prysm Beacon P2P port (TCP)" "$prysm_beacon_p2p_tcp_port" prysm_beacon_p2p_tcp_port
read_default "Prysm Beacon P2P port (UDP)" "$prysm_beacon_p2p_udp_port" prysm_beacon_p2p_udp_port
read_default "Prysm Beacon quic port (UDP)" "$prysm_beacon_p2p_quic_port" prysm_beacon_p2p_quic_port

# -------------------------- COMMENCEMENT -------------------------------------

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

read -p "Continue? (y/N): " confirm \
  && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 1

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

echo "Success!  Now you must configure your router for port forwarding..."
# TODO see if port forwarding can be automated in OpenWRT and make a script if so
