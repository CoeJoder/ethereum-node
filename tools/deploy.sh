#!/bin/bash

# -------------------------- HEADER -------------------------------------------

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF 
	usage: deploy.sh [-h|--help] [--dry-run] [--offline]
	
	Default mode deploys to node server via SSH.
	Offline mode deploys to USB 'DATA' drive.
	EOF
}

offline_mode=false
rsync_opts=''

function parse_arg() {
	if [[ $1 == '--dry-run' ]]; then
		rsync_opts='--dry-run'
	elif [[ $1 == '--offline' ]]; then
		offline_mode=true
	elif [[ $1 == '-h' || $1 == '--help' ]]; then
		show_usage
		exit 0
	else
		printerr "unknown argument: $1"
		show_usage
		exit 1
	fi
}

if [[ $# -gt 0 ]]; then
	parse_arg "$1"
	shift
	if [[ $# -gt 0 ]]; then
		parse_arg "$1"
		shift
		if [[ $# -gt 0 ]]; then
			show_usage
			exit 1
		fi
	fi
fi

# -------------------------- BANNER -------------------------------------------

cat <<EOF
${color_blue}${bold}
      :::::::::  :::::::::: :::::::::  :::        ::::::::  :::   :::
     :+:    :+: :+:        :+:    :+: :+:       :+:    :+: :+:   :+: 
    +:+    +:+ +:+        +:+    +:+ +:+       +:+    +:+  +:+ +:+   
   +#+    +:+ +#++:++#   +#++:++#+  +#+       +#+    +:+   +#++:     
  +#+    +#+ +#+        +#+        +#+       +#+    +#+    +#+       
 #+#    #+# #+#        #+#        #+#       #+#    #+#    #+#        
#########  ########## ###        ########## ########     ###         
${color_reset}
EOF

# -------------------------- PREAMBLE -----------------------------------------

preamble="[${theme_value}NORMAL${color_reset} mode] Copies the source scripts from the client PC to the node server."
if [[ $offline_mode == true ]]; then
	preamble="[${theme_value}OFFLINE${color_reset} mode] Copies the source scripts and offline tools to the USB 'DATA' drive on the client PC."
fi

cat <<EOF
$preamble
EOF
press_any_key_to_continue

# -------------------------- PRECONDITIONS ------------------------------------

assert_not_on_node_server

check_is_defined dist_dirname

if [[ $offline_mode == true ]]; then
	# ---------- OFFLINE MODE
	check_directory_exists --sudo client_pc_usb_data_drive
	check_is_defined ethereum_staking_deposit_cli_version
	check_is_defined ethereum_staking_deposit_cli_sha256_checksum
	check_is_defined ethereum_staking_deposit_cli_url
else
	# ---------- NORMAL MODE
	check_is_valid_port node_server_ssh_port
	check_is_defined node_server_username
	check_is_defined node_server_hostname
fi

# careful changing these as they are params to rsync
includes_non_generated="$tools_dir/non-generated.txt"
includes_generated="$tools_dir/generated.txt"
includes_offline="$tools_dir/offline.txt"
deploy_src_dir="$(realpath "$src_dir")/"

check_file_exists includes_non_generated
check_file_exists includes_generated
check_file_exists includes_offline
check_directory_exists deploy_src_dir

print_failed_checks --error || exit

# -------------------------- RECONNAISSANCE -----------------------------------

if [[ $offline_mode == true ]]; then
	# ---------- OFFLINE MODE
	get_latest_deposit_cli_version latest_deposit_cli_version || exit 1

	if [[ $latest_deposit_cli_version != $ethereum_staking_deposit_cli_version ]]; then
		printerr "latest version is different than expected ($ethereum_staking_deposit_cli_version)"
		printerr "update the ${color_lightgray}ethereum_staking_deposit_cli_${color_reset} values in ${theme_filename}env.sh${color_reset} and relaunch this script"
		exit 1
	fi

	deposit_cli_basename="$(basename "$ethereum_staking_deposit_cli_url")"
	deposit_cli_basename_sha256="${deposit_cli_basename}.sha256"

	printf '\n'
	printf '%s' \
		"Please navigate to " \
		"${color_blue}https://github.com/ethereum/staking-deposit-cli/releases/tag/${ethereum_staking_deposit_cli_version}${color_reset} " \
		"and verify the ${theme_value}SHA256 Checksum${color_reset} of ${theme_filename}$deposit_cli_basename${color_reset}"
	printf '\n\n'
	if ! yes_or_no --default-no "Does it match this? ${theme_value}$ethereum_staking_deposit_cli_sha256_checksum${color_reset}"; then
		printerr "unexpected checksum; ensure that ${theme_value}ethereum_staking_deposit_cli_${color_reset} values in ${theme_filename}env.sh${color_reset} are correct and relaunch this script"
		exit 1
	fi
	
	printinfo "Ready to deploy with the following commands:"
	cat <<-EOF
	${color_lightgray}
	# overwrite non-generated files and remove deleted files i.e. those listed in 
	# includes-file but not existing in source filesystem
	rsync -avh \\
		--progress \\
		--delete \\
		--include-from="$includes_non_generated" \\
		--include-from="$includes_offline" \\
		--exclude="*" \\
		$rsync_opts \\
		"$deploy_src_dir" "$client_pc_usb_data_drive/$dist_dirname"

	# overwrite generated files only if source copy is newer
	rsync -avhu \\
		--progress \\
		--include-from="$includes_generated" \\
		--exclude="*" \\
		$rsync_opts \\
		"$deploy_src_dir" "$client_pc_usb_data_drive/$dist_dirname"

	# now that destination dir exists, copy the .sha256 and the tarball over
	sudo cp -vf "$deposit_cli_basename_sha256" "$client_pc_usb_data_drive/$dist_dirname"
	sudo cp -vf "$deposit_cli_basename" "$client_pc_usb_data_drive/$dist_dirname"
	${color_reset}
	EOF
	yes_or_no --default-yes "Continue?" || exit 1
else
	# ---------- NORMAL MODE
	printinfo "Ready to deploy with the following commands:"
	cat <<-EOF
	${color_lightgray}
	# overwrite non-generated files and remove deleted files i.e. those listed in 
	# includes-file but not existing in source filesystem
	rsync -avh -e "ssh -p $node_server_ssh_port" \\
		--progress \\
		--delete \\
		--include-from="$includes_non_generated" \\
		--exclude="*" \\
		$rsync_opts \\
		"$deploy_src_dir" "${node_server_username}@${node_server_hostname}:$dist_dirname"

	# overwrite generated files only if source copy is newer
	rsync -avhu -e "ssh -p $node_server_ssh_port" \\
		--progress \\
		--include-from="$includes_generated" \\
		--exclude="*" \\
		$rsync_opts \\
		"$deploy_src_dir" "${node_server_username}@${node_server_hostname}:$dist_dirname"
	${color_reset}
	EOF
	yes_or_no --default-yes "Continue?" || exit 1
fi

# -------------------------- EXECUTION ----------------------------------------

if [[ $offline_mode == true ]]; then
	# ---------- OFFLINE MODE
	temp_dir=$(mktemp -d)
	pushd "$temp_dir" >/dev/null

	function on_exit() {
		printinfo -n "Cleaning up..."
		popd >/dev/null
		[[ -d $temp_dir ]] && rm -rf --interactive=never "$temp_dir" >/dev/null
		print_ok
	}

	trap 'on_err_retry' ERR
	trap 'on_exit' EXIT

	assert_sudo

	printinfo "Downloading Ethereum Staking Deposit CLI..."
	download_file "$ethereum_staking_deposit_cli_url"

	# construct a .sha256 file from the value listed on the release page and run shasum with it
	echo "$ethereum_staking_deposit_cli_sha256_checksum  $deposit_cli_basename" > "$deposit_cli_basename_sha256"
	if ! sha256sum -c "$deposit_cli_basename_sha256"; then
		printerr "checksum failed; expected: ${theme_value}$ethereum_staking_deposit_cli_sha256_checksum${color_reset}"
		exit 1
	fi

	printinfo "Deploying..."

	# create the dist dir if necessary and copy over the tarball and .sha256
	dist_dir="$client_pc_usb_data_drive/$dist_dirname"
	sudo mkdir -p "$dist_dir"
	sudo chown -R "$USER:$USER" "$dist_dir"
	cp -vf "$deposit_cli_basename" "$dist_dir"
	cp -vf "$deposit_cli_basename_sha256" "$dist_dir"

	# overwrite non-generated files and remove deleted files i.e. those listed in 
	# includes-file but not existing in source filesystem
	rsync -avh \
		--progress \
		--delete \
		--include-from="$includes_non_generated" \
		--include-from="$includes_offline" \
		--exclude="*" \
		$rsync_opts \
		"$deploy_src_dir" "$dist_dir"

	# overwrite generated files only if source copy is newer
	rsync -avhu \
		--progress \
		--include-from="$includes_generated" \
		--exclude="*" \
		$rsync_opts \
		"$deploy_src_dir" "$dist_dir"
else
	# ---------- NORMAL MODE
	trap 'on_err_retry' ERR

	printinfo "Deploying..."

	# overwrite non-generated files and remove deleted files i.e. those listed in 
	# includes-file but not existing in source filesystem
	rsync -avh -e "ssh -p $node_server_ssh_port" \
		--progress \
		--delete \
		--include-from="$includes_non_generated" \
		--exclude="*" \
		$rsync_opts \
		"$deploy_src_dir" "${node_server_username}@${node_server_hostname}:$dist_dirname"

	# overwrite generated files only if source copy is newer
	rsync -avhu -e "ssh -p $node_server_ssh_port" \
		--progress \
		--include-from="$includes_generated" \
		--exclude="*" \
		$rsync_opts \
		"$deploy_src_dir" "${node_server_username}@${node_server_hostname}:$dist_dirname"
fi

# -------------------------- POSTCONDITIONS -----------------------------------

if [[ $offline_mode == true ]]; then
	reset_checks
	deposit_cli_dest="$dist_dir/$deposit_cli_basename"
	deposit_cli_sha256_dest="$dist_dir/$deposit_cli_basename_sha256"
	check_file_exists --sudo deposit_cli_dest
	check_file_exists --sudo deposit_cli_sha256_dest
	print_failed_checks --error

	cat <<-EOF

	Success!  Downloaded the Ethereum Staking Deposit CLI and verified its checksum, and copied to USB 'DATA' drive.
	Now you are ready to generate your validator key(s) on the offline PC.
	EOF
fi
