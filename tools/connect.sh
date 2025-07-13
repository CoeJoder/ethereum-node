#!/bin/bash

# connect.sh
#
# Starts an interactive SSH session with the node server.

# -------------------------- HEADER -------------------------------------------

set -e

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
set_env

# -------------------------- PRECONDITIONS ------------------------------------

# -------------------------- BANNER -------------------------------------------

# -------------------------- PREAMBLE -----------------------------------------

# -------------------------- RECONNAISSANCE -----------------------------------

# -------------------------- EXECUTION ----------------------------------------

ssh -t -p "$node_server_ssh_port" "${node_server_username}@${node_server_hostname}"

# -------------------------- POSTCONDITIONS -----------------------------------
