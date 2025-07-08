#!/bin/bash

# lint.sh
#
# Runs `shellcheck` on all of the bash scripts in this project.

set -eu

shellcheck_min_version_required='0.9.0'
shellcheck_version_regex='version: ([[:digit:]]\.[[:digit:]]\.[[:digit:]])'

# assert shellcheck is installed
if ! type -P 'shellcheck' &>/dev/null; then
	echo "shellcheck not found on path; install it and relaunch" >&2
	exit 1
fi

# assert shellcheck meets the minimum version requirement
while IFS= read -r line; do
	if [[ $line =~ $shellcheck_version_regex ]]; then
		version="${BASH_REMATCH[1]}"
	fi
done < <(shellcheck --version)

if [[ -z $version ]]; then
	echo "failed to parse the version string from \`shellcheck --version\`" >&2
	exit 1
fi

if [[ $shellcheck_min_version_required != "$version" ]]; then
	if [[ "$(printf '%s\n' "$shellcheck_min_version_required" "$version" | sort -rV | head -n1)" == "$shellcheck_min_version_required" ]]; then
		echo "installed version of shellcheck ($version) does not meet the minumum requirement ($shellcheck_min_version_required); upgrade it and relaunch" >&2
		exit 1
	fi
fi

# source: https://github.com/koalaman/shellcheck/issues/143#issuecomment-909009632
function is_bash() {
	local file="$1"
	[[ $file == *.sh ]] && return 0
	[[ $file == */bash-completion/* ]] && return 0
	[[ $(file -b --mime-type "$file") == text/x-shellscript ]] && return 0
	return 1
}

# source: https://github.com/koalaman/shellcheck/issues/143#issuecomment-909009632
function recursive_bash_lint() {
	local script_dir="$1"
	while IFS= read -r -d $'' file; do
		if is_bash "$file"; then
			shellcheck -s bash "$file" || continue
		fi
	done < <(find "$script_dir" -type f -print0 \
		! -path "./.git/*" \
		! -path "./.node_modules/*")
}

# lint all bash scripts in the project
proj_dir="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"
recursive_bash_lint "$proj_dir/src"
recursive_bash_lint "$proj_dir/tools"
recursive_bash_lint "$proj_dir/test"
