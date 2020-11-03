#!/bin/bash

# Switcher script for halcon-overlay
# Edits files in /etc/portage/repos.conf for switching between the remote "halcon-overlay" and local "localrepo" (enabling one, disabling another)
# Actual if you DON'T WANT at least one of those overlays be enabled or disabled automatically by `eselect repository` 
#   (if you configure at least one of those overlays in FILES OTHER than eselect-repo.conf,
#   and/or if you have NON-STANDARD ENTRIES for at least one of those overlays, such as for example sync-mercurial-pull-extra-opts)
# Yes, I know, it's re-inventing the wheel; I wrote it just as an exercise
# Should be called by root
#
# The script uses the following Environment Variables: ( HALCONOVERLAY_LOCAL_DIR HALCONOVERLAY_REMOTE_DIR )
#
# Copyright (C) 2020 Alexey Mishustin halcon@tuta.io
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; If not, see <https://www.gnu.org/licenses/>.

# Usage: 
# switcher_halconoverlay.sh local
# or
# switcher_halconoverlay.sh remote
_local_or_remote="${1}"

source /usr/local/bin/mclass_utilities.sh

if [[ -z "${_local_or_remote}" ]]; then
	exit_err_1 '_local_or_remote argument is not passed'
fi

# Example file: installer_halconoverlay.conf.example
_conf_file='/usr/local/bin/installer_halconoverlay.conf'

HALCONOVERLAY_LOCAL_DIR=$(read_env_or_conf_var 'HALCONOVERLAY_LOCAL_DIR' "${_conf_file}") || exit $?
HALCONOVERLAY_REMOTE_DIR=$(read_env_or_conf_var 'HALCONOVERLAY_REMOTE_DIR' "${_conf_file}") || exit $?

if [[ -z "${HALCONOVERLAY_LOCAL_DIR}" ]]; then
	exit_err_1 'HALCONOVERLAY_LOCAL_DIR is not set'
fi
if [[ -z "${HALCONOVERLAY_REMOTE_DIR}" ]]; then
	exit_err_1 'HALCONOVERLAY_REMOTE_DIR is not set'
fi

declare -A _repo_name
_repo_name['local']="${HALCONOVERLAY_LOCAL_DIR##*/}"
_repo_name['remote']="${HALCONOVERLAY_REMOTE_DIR##*/}"

declare -A _repo_enabled
_repo_enabled['local']=$(eselect repository list -i | grep ${_repo_name['local']} | wc -l)
_repo_enabled['remote']=$(eselect repository list -i | grep ${_repo_name['remote']} | wc -l)

# Set in function set_data_for_repo
declare -A _file_for_repo
_file_for_repo['local']=
_file_for_repo['remote']=

# Set in function set_data_for_repo
declare -A _first_line_for_repo
_first_line_for_repo['local']=
_first_line_for_repo['remote']=

# Set in function set_data_for_repo
declare -A _last_line_for_repo
_last_line_for_repo['local']=
_last_line_for_repo['remote']=

function check_both_repos {

	if [[ ${_repo_enabled['local']} -gt 1 ]]; then
		exit_err_1 'found more than 1 ESELECT entry ('"${_repo_enabled['local']}"') for repository '"${_repo_name['local']}"
	fi
	if [[ ${_repo_enabled['remote']} -gt 1 ]]; then
		exit_err_1 'found more than 1 ESELECT entry ('"${_repo_enabled['remote']}"') for repository '"${_repo_name['remote']}"
	fi

	if [[ ${_repo_enabled['local']} -eq 1 && ${_repo_enabled['remote']} -eq 1 ]]; then
		exit_err_1 'both repositories ('"${_repo_name['local']}"' and '"${_repo_name['remote']}"') are enabled'
	fi
	if [[ ${_repo_enabled['local']} -eq 0 && ${_repo_enabled['remote']} -eq 0 ]]; then
		exit_err_1 'both repositories ('"${_repo_name['local']}"' and '"${_repo_name['remote']}"') are disabled'
	fi

	if [[ "${_local_or_remote}" == 'local' && ${_repo_enabled['local']} -eq 1 ]]; then
		echo 'repository '"${_repo_name['local']}"' is already enabled'
		exit 0
	fi
	if [[ "${_local_or_remote}" == 'remote' && ${_repo_enabled['remote']} -eq 1 ]]; then
		echo 'repository '"${_repo_name['remote']}"' is already enabled'
		exit 0
	fi

}

function set_data_for_repo {

	local __repo="${1}"

	local __find_repo=$(find /etc/portage/repos.conf -maxdepth 1 -type f -regextype egrep -regex "^.*[\.]conf$" -exec grep -Hn "\[${_repo_name[${__repo}]}\]" {} \;)
	local __find_repo_check=$(echo "${__find_repo}" | wc -l)
	if [[ ${__find_repo_check} -eq 0 ]]; then
		exit_err_1 'repository '"${_repo_name[${__repo}]}"' not found'
	fi
	if [[ ${__find_repo_check} -gt 1 ]]; then
		exit_err_1 'found more than 1 TEXT entry ('"${__find_repo_check}"') for repository '"${_repo_name[${__repo}]}"
	fi

	_file_for_repo["${__repo}"]=$(echo "${__find_repo}" | cut -d: -f1)
	_first_line_for_repo["${__repo}"]=$(echo "${__find_repo}" | cut -d: -f2)
	local __all_repos_in_file=$(grep -n "\[.*\]" "${_file_for_repo[${__repo}]}" | grep -v "\[${_repo_name[${__repo}]}\]")
	
	_last_line_for_repo["${__repo}"]=$(cat "${_file_for_repo[${__repo}]}" | wc -l)
	local __repo_line=
	local __line
	while IFS= read -r __line ; do
		__repo_line=$(echo "${__line}" | cut -d: -f1)
		if [[ ${__repo_line} -gt ${__repo_found_in_line} ]]; then
			local __previous_line
			let "__previous_line=${__repo_line}-1"
			_last_line_for_repo["${__repo}"]="${__previous_line}"
			break
		fi
	done <<< "${__all_repos_in_file}"

	echo "_file_for_repo[${__repo}]=${_file_for_repo[${__repo}]}"
	echo "_first_line_for_repo[${__repo}]=${_first_line_for_repo[${__repo}]}"
	echo "_last_line_for_repo[${__repo}]=${_last_line_for_repo[${__repo}]}"
	echo

}

function comment_repo {

	local __repo="${1}"

	local __new_lines=''
	local __line_number=0
	local __line
	while IFS= read -r __line ; do
		let "__line_number+=1"
		if [[ ${__line_number} -lt ${_first_line_for_repo[${__repo}]} || ${__line_number} -gt ${_last_line_for_repo[${__repo}]} ]]; then
			if [[ ${__line_number} -eq 1 ]]; then
				__new_lines="${__line}"
			else
				__new_lines="${__new_lines}"'
'"${__line}"
			fi
		else
			if [[ ${__line_number} -eq 1 ]]; then
				__new_lines='#'"${__line}"
			else
				__new_lines="${__new_lines}"'
#'"${__line}"
			fi
		fi
	done < "${_file_for_repo[${__repo}]}"

	echo "comment_repo ${__repo} : ${__new_lines}"
	echo
	echo "${__new_lines}" > "${_file_for_repo[${__repo}]}"

}

function uncomment_repo {

	local __repo="${1}"
	
	local __new_lines=''
	local __new_line=
	local __line_number=0
	local __line
	while IFS= read -r __line ; do
		let "__line_number+=1"
		if [[ ${__line_number} -lt ${_first_line_for_repo[${__repo}]} || ${__line_number} -gt ${_last_line_for_repo[${__repo}]} ]]; then
			if [[ ${__line_number} -eq 1 ]]; then
				__new_lines="${__line}"
			else
				__new_lines="${__new_lines}"'
'"${__line}"
			fi
		else
		__new_line=$(echo "${__line}" | sed -r 's/^[[:space:]]*#(.*)$/\1/' )
			if [[ ${__line_number} -eq 1 ]]; then
				__new_lines="${__new_line}"
			else
				__new_lines="${__new_lines}"'
'"${__new_line}"
			fi
		fi
	done < "${_file_for_repo[${__repo}]}"

	echo "comment_repo ${__repo} : ${__new_lines}"
	echo
	echo "${__new_lines}" > "${_file_for_repo[${__repo}]}"

}

function main {

	check_both_repos

	set_data_for_repo 'local'
	set_data_for_repo 'remote'

	if [[ "${_local_or_remote}" == 'local' ]]; then
		comment_repo 'remote'
		uncomment_repo 'local'
	elif [[ "${_local_or_remote}" == 'remote' ]]; then
		comment_repo 'local'
		uncomment_repo 'remote'
	fi

}

main

exit 0
