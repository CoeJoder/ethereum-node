#!/bin/bash

# -------------------------- HEADER -------------------------------------------

set -e

tools_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
source "$tools_dir/../src/common.sh"
housekeeping

function show_usage() {
	cat >&2 <<-EOF
		Usage: $(basename ${BASH_SOURCE[0]}) [options]
			--dry-run   Perform a dry-run of the rsync transfers
			--usb       Deploy to the USB 'DATA' drive. Omit to deploy to the node server instead
			--help, -h  Show this message
	EOF
}

_parsed_args=$(getopt --options='h' --longoptions='help,dry-run,usb' \
	--name "$(basename ${BASH_SOURCE[0]})" -- "$@")
(($? != 0)) && exit 1
eval set -- "$_parsed_args"
unset _parsed_args

usb_mode=false
rsync_opts=''

while true; do
	case "$1" in
	-h | --help)
		show_usage
		exit 0
		;;
	--dry-run)
		rsync_opts='--dry-run'
		shift
		;;
	--usb)
		usb_mode=true
		shift
		;;
	--)
		shift
		break
		;;
	*)
		printerr "unknown argument: $1"
		exit 1
		;;
	esac
done

# -------------------------- PRECONDITIONS ------------------------------------

assert_not_on_node_server

check_is_defined dist_dirname

if [[ $usb_mode == true ]]; then
	check_directory_exists --sudo client_pc_usb_data_drive
	check_is_defined usb_dist_dir
	check_is_defined ethstaker_deposit_cli_version
	check_is_defined ethstaker_deposit_cli_sha256_checksum
	check_is_defined ethstaker_deposit_cli_url
	check_is_defined jq_bin
	check_is_defined jq_bin_sha256
	check_is_defined ethdo_version
	check_is_defined ethdo_sha256_checksum
	check_is_defined ethereal_version
	check_is_defined ethereal_sha256_checksum
else
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

print_failed_checks --error

# -------------------------- BANNER -------------------------------------------

echo -ne "${color_blue}${bold}"
cat <<'EOF'

      :::::::::  :::::::::: :::::::::  :::        ::::::::  :::   :::
     :+:    :+: :+:        :+:    :+: :+:       :+:    :+: :+:   :+: 
    +:+    +:+ +:+        +:+    +:+ +:+       +:+    +:+  +:+ +:+   
   +#+    +:+ +#++:++#   +#++:++#+  +#+       +#+    +:+   +#++:     
  +#+    +#+ +#+        +#+        +#+       +#+    +#+    +#+       
 #+#    #+# #+#        #+#        #+#       #+#    #+#    #+#        
#########  ########## ###        ########## ########     ###         
EOF
echo -ne "${color_reset}"

# -------------------------- PREAMBLE -----------------------------------------

preamble="[${theme_value}NORMAL${color_reset} mode] Copies the source scripts from the client PC to the node server."
if [[ $usb_mode == true ]]; then
	preamble="[${theme_value}USB${color_reset} mode] Copies the source scripts and offline tools to the USB 'DATA' drive on the client PC."
fi

cat <<EOF
$preamble
EOF
press_any_key_to_continue

# -------------------------- RECONNAISSANCE -----------------------------------

if [[ $usb_mode == true ]]; then
	get_latest_deposit_cli_version latest_deposit_cli_version

	if [[ $latest_deposit_cli_version != $ethstaker_deposit_cli_version ]]; then
		printerr "latest version is different than expected ($ethstaker_deposit_cli_version)"
		printerr "update the ${color_lightgray}ethstaker_deposit_cli_${color_reset} values in ${theme_filename}env.sh${color_reset} and relaunch this script"
		exit 1
	fi
	printf '\n'

	printinfo "Verifying ${theme_value}ethstaker-deposit-cli${color_reset} SHA256 checksum of the release page matches our saved value..."
	fetched_ethstaker_deposit_cli_sha265="$(wget -qO - "$ethstaker_deposit_cli_sha256_url" | cat)"
	if [[ $fetched_ethstaker_deposit_cli_sha265 != $ethstaker_deposit_cli_sha256_checksum ]]; then
		printerr "Found: $fetched_ethstaker_deposit_cli_sha265\nExpected: $ethstaker_deposit_cli_sha256_checksum\n" \
			"Ensure that ${theme_value}ethstaker_deposit_cli_${color_reset} values in ${theme_filename}env.sh${color_reset} are correct and relaunch this script"
		exit 1
	fi
	printf '\n'
fi

# -------------------------- EXECUTION ----------------------------------------

if [[ $usb_mode == true ]]; then
	temp_dir=$(mktemp -d)
	pushd "$temp_dir" >/dev/null

	function on_exit() {
		printinfo -n "Cleaning up..."
		popd >/dev/null
		rm -rf --interactive=never "$temp_dir" >/dev/null
		print_ok
	}

	trap 'on_err_retry' ERR
	trap 'on_exit' EXIT

	assert_sudo

	printinfo "Downloading EthStaker Deposit CLI..."
	download_file "$ethstaker_deposit_cli_url"

	# construct a .sha256 file from the value we saved from the release page and perform checksum
	echo "$ethstaker_deposit_cli_sha256_checksum  $ethstaker_deposit_cli_basename" >"$ethstaker_deposit_cli_basename_sha256"
	if ! sha256sum -c "$ethstaker_deposit_cli_basename_sha256"; then
		printerr "checksum failed; expected: ${theme_value}$ethstaker_deposit_cli_sha256_checksum${color_reset}"
		exit 1
	fi

	printinfo "Downloading ${jq_version}..."
	download_jq "$jq_bin" "$jq_bin_sha256" "$jq_version"
	chmod +x "$jq_bin"

	printinfo "Downloading ethdo ${ethdo_version}..."
	download_wealdtech ethdo \
		"$ethdo_version" "$ethdo_sha256_checksum" ethdo_bin

	printinfo "Downloading ethereal ${ethereal_version}..."
	download_wealdtech ethereal \
		"$ethereal_version" "$ethereal_sha256_checksum" ethereal_bin
	
	# construct ethdo & ethereal .sha256 files for add'l offline verification
	ethdo_bin_sha256="${ethdo_bin}.sha256"
	ethereal_bin_sha256="${ethereal_bin}.sha256"
	echo "$ethdo_sha256_checksum  $ethdo_bin" >"$ethdo_bin_sha256"
	echo "$ethereal_sha256_checksum  $ethereal_bin" >"$ethereal_bin_sha256"

	printinfo "Deploying..."

	# create the usb dist dir if necessary and copy over 3rd party software and checksums
	sudo mkdir -p "$usb_dist_dir"
	sudo chown -R "$USER:$USER" "$usb_dist_dir"
	sudo chmod 775 "$usb_dist_dir"
	cp -vf "$ethstaker_deposit_cli_basename" "$usb_dist_dir"
	cp -vf "$ethstaker_deposit_cli_basename_sha256" "$usb_dist_dir"
	cp -vf "$jq_bin" "$usb_dist_dir"
	cp -vf "$jq_bin_sha256" "$usb_dist_dir"
	cp -vf "$ethdo_bin" "$usb_dist_dir"
	cp -vf "$ethdo_bin_sha256" "$usb_dist_dir"
	cp -vf "$ethereal_bin" "$usb_dist_dir"
	cp -vf "$ethereal_bin_sha256" "$usb_dist_dir"

	# overwrite non-generated files and remove deleted files i.e., those listed in
	# includes-file but not existing in source filesystem
	rsync -avh \
		--progress \
		--delete \
		--include-from="$includes_non_generated" \
		--include-from="$includes_offline" \
		--exclude="*" \
		$rsync_opts \
		"$deploy_src_dir" "$usb_dist_dir"

	# overwrite generated files only if source copy is newer
	rsync -avhu \
		--progress \
		--include-from="$includes_generated" \
		--exclude="*" \
		$rsync_opts \
		"$deploy_src_dir" "$usb_dist_dir"

	# deploy the unseal.sh script to the dist parent dir
	unseal_dest="$client_pc_usb_data_drive/unseal.sh"
	sudo cp -fv "$tools_dir/unseal.sh" "$unseal_dest"

	# seal the deployment
	printinfo "Sealing the deployment..."
	sudo chown -R root:root "$usb_dist_dir"
	sudo chown root:root "$unseal_dest"
	sudo chmod 0 "$usb_dist_dir"
	sudo chmod +rx "$unseal_dest"
else
	trap 'on_err_retry' ERR

	printinfo "Deploying..."

	# overwrite non-generated files and remove deleted files i.e., those listed in
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

if [[ $usb_mode == true ]]; then
	reset_checks
	deposit_cli_dest="$usb_dist_dir/$ethstaker_deposit_cli_basename"
	deposit_cli_sha256_dest="$usb_dist_dir/$ethstaker_deposit_cli_basename_sha256"
	jq_bin_dest="$usb_dist_dir/$jq_bin"
	jq_bin_sha256_dest="$usb_dist_dir/$jq_bin_sha256"
	ethdo_bin_dest="$usb_dist_dir/$ethdo_bin"
	ethdo_bin_sha256_dest="$usb_dist_dir/$ethdo_bin_sha256"
	ethereal_bin_dest="$usb_dist_dir/$ethereal_bin"
	ethereal_bin_sha256_dest="$usb_dist_dir/$ethereal_bin_sha256"
	check_file_exists --sudo deposit_cli_dest
	check_file_exists --sudo deposit_cli_sha256_dest
	check_file_exists --sudo jq_bin_dest
	check_file_exists --sudo jq_bin_sha256_dest
	check_file_exists --sudo ethdo_bin_dest
	check_file_exists --sudo ethdo_bin_sha256_dest
	check_file_exists --sudo ethereal_bin_dest
	check_file_exists --sudo ethereal_bin_sha256_dest
	check_file_exists --sudo unseal_dest
	print_failed_checks --error

	cat <<-EOF

		Success!  Downloaded the offline tools to the USB 'DATA' drive.
	EOF
fi
