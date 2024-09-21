#!/bin/bash

# -------------------------- PREAMBLE -----------------------------------------

# load constants and utility functions
this_dir="$(dirname "$(realpath "$0")")"
common_sh="$this_dir/common.sh"
source "$common_sh"

# -------------------------- BANNER -------------------------------------------

echo -e "\nSo, you've decided to... ${color_green}"
echo '                    $$\   $$\     '
echo '                    \__|  $$ |    '
echo ' $$$$$$\  $$\   $$\ $$\ $$$$$$\   '
echo '$$  __$$\ \$$\ $$  |$$ |\_$$  _|  '
echo '$$$$$$$$ | \$$$$  / $$ |  $$ |    '
echo '$$   ____| $$  $$<  $$ |  $$ |$$\ '
echo '\$$$$$$$\ $$  /\$$\ $$ |  \$$$$  |'
echo ' \_______|\__/  \__|\__|   \____/ '
echo "${color_reset}"
echo -e "To abort at any time, press ${color_green}ctrl + c${color_reset}"

# -------------------------- RECONNAISSANCE -----------------------------------

# eager authentication
assert_sudo

# ask for location of the wallet created during validator initialization
default_val="/var/lib/prysm/validator/prysm-wallet-v2"
read_default "\nValidator wallet (default: ${color_lightgray}$default_val${color_reset}): " "$default_val" wallet_dir
assert_sudo
if sudo test ! -d "$wallet_dir"; then
  printerr "directory not found"
  exit 1
fi


# ask for location of the file containing wallet password
default_val="/var/lib/prysm/validator/wallet-password.txt"
read_default "\nWallet password file (default: ${color_lightgray}$default_val${color_reset}): " "$default_val" wallet_password_file
assert_sudo
if sudo test ! -f "$wallet_password_file"; then
  printerr "file not found"
  exit 1
fi

# ask for comma-separated list of the public hex keys of the validators to exit
echo -e "\nEnter a comma-separated list of validator public keys (e.g. ${color_lightgray}0xABC123,0xDEF456${color_reset}) or ${color_lightgray}all${color_reset}."
read_default "Validators to exit (default: ${color_lightgray}all${color_reset}): " "all" public_keys
if [[ $public_keys == "all" ]]; then
  prysm_param_validators="--exit-all"
elif [[ $public_keys =~ $regex_hex_csv ]]; then
  prysm_param_validators="--public-keys $public_keys"
else
  printerr 'expected "all" or a comma-separated list of hexadecimal numbers'
  exit 1
fi

# ask for network
default_val="mainnet"
read_default "\nEthereum network (default: ${color_lightgray}$default_val${color_reset}): " $default_val eth_network
prysm_param_network="--${eth_network}"

# lookup the latest program version
echo -en "\nLooking up latest prysm version..."
prysm_version=$(get_latest_release "prysmaticlabs/prysm")
if [[ ! "$prysm_version" =~ v[0-9]\.[0-9]\.[0-9] ]]; then
  echo "${color_red}failed${color_reset}."
  printerr "malformed version string: \"$prysm_version\""
  exit 1
fi
echo -e "${color_green}${prysm_version}${color_reset}"

# -------------------------- COMMENCEMENT -------------------------------------

temp_dir=$(mktemp -d)
pushd "$temp_dir" >/dev/null

function cleanup_on_exit() {
  echo -en "\nCleaning up..."
  popd >/dev/null
  [[ -d $temp_dir ]] && rm -rf "$temp_dir" >/dev/null
  echo -e "${color_green}OK${color_reset}"
}

trap 'cleanup_on_exit' EXIT

echo -e "Downloading prysmctl-$prysm_version..."
prysmctl_bin="prysmctl-${prysm_version}-linux-amd64"
prysmctl_bin_sha256="prysmctl-${prysm_version}-linux-amd64.sha256"
wget -q "https://github.com/prysmaticlabs/prysm/releases/download/${prysm_version}/${prysmctl_bin}"
wget -q "https://github.com/prysmaticlabs/prysm/releases/download/${prysm_version}/${prysmctl_bin_sha256}"
echo "$(cat "$prysmctl_bin_sha256")" | shasum -a 256 -c - || exit 1

# need to invoke prysmctl as `prysmvalidator`, in a directory where both
# the current user and `prysmvalidator` have read/write/execute permissions
install_dir="/var/lib/prysm/prysmctl"
sudo mkdir -p "$install_dir"
sudo mv -f "$prysmctl_bin" "$install_dir"
sudo chown -R "${USER}:${prysmvalidator_user}" "$install_dir"
sudo chmod -R 770 "$install_dir"
popd >/dev/null
pushd "$install_dir" >/dev/null

echo -e "\nReady to invoke prysmctl the following way:"
echo -e "${color_lightgray}sudo -u \"${prysmvalidator_user}\" \"./${prysmctl_bin}\" validator exit \\
  --wallet-dir \"$wallet_dir\" \\
  --wallet-password-file \"$wallet_password_file\" \\
  --accept-terms-of-use \\
  --force-exit \\
  $prysm_param_network \\
  $prysm_param_validators \n${color_reset}"

read -p "Continue? (y/N): " confirm \
    && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || exit 0

sudo -u "${prysmvalidator_user}" "./${prysmctl_bin}" validator exit \
  --wallet-dir "$wallet_dir" \
  --wallet-password-file "$wallet_password_file" \
  --accept-terms-of-use \
  --force-exit \
  $prysm_param_network \
  $prysm_param_validators
retval="$?"

if [[ $retval -ne "0" ]]; then
  printf "\n"
  printerr "Something went wrong. Send screenshots of the terminal to the HGiC (Head Geek-in-Charge), or just try it again and don't screw it up this time ;)"
fi
exit $retval
