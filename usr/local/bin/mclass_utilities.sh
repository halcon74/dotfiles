#!/bin/bash

# Collection of useful shell functions - utilities
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

# In the alphabet order:

# calling example: 
# cp_n_chown_n_chmod "${__my_script}" 'root:'"${_user_name}" 750 "${_my_dest_dir}"
function cp_n_chown_n_chmod {

	local __file_name="${1}"
	local __file_owners="${2}"
	local __file_mask="${3}"
	local __dest_dir="${4}"
	local __add_dot="${5}"
	
	if [[ -z "${__file_name}" || "${__file_name}" =~ [[:space:]] ]]; then
		exit_err_1 'Wrong __file_name '"${__file_name}"
	fi
	
	if [[ -z "${__file_owners}" || ! "${__file_owners}" =~ ^[a-zA-Z0-9._-]+:[a-zA-Z0-9._-]+$ ]]; then
		exit_err_1 'Wrong __file_owners '"${__file_owners}"
	fi
	
	if [[ -z "${__file_mask}" || ! "${__file_mask}" =~ ^[0124]?[0-7][0-7][0-7]$ ]]; then
		exit_err_1 'Wrong __file_mask '"${__file_mask}"
	fi
	
	if [[ ! -d "${__dest_dir}" ]]; then
		exit_err_1 '__dest_dir='"${__dest_dir}"': No such directory'
	fi
	
	local __base_name="${__file_name##*/}"
	local __new_full_path
	
	if [[ "${__add_dot}" -eq 1 ]]; then
		__new_full_path="${__dest_dir}"'/.'"${__base_name}"
	else
		__new_full_path="${__dest_dir}"'/'"${__base_name}"
	fi
	
	set -x
	# cp
	cp "${__file_name}" "${__new_full_path}"
	# chown
	chown "${__file_owners}" "${__new_full_path}"
	set +x
	
	# chmod
	if [[ -n "${__file_mask}" ]]; then
		set -x
		chmod "${__file_mask}" "${__new_full_path}"
		set +x
	fi

}

# calling example: 
# exit_err_1 'Wrong category: '"${__category_name}"
function exit_err_1 {
	
	local __arg_error="${1}"

	echo "${__arg_error}"'.

Exiting 1.' >&2
	exit 1

}

# calling example: 
# local __find_in_my_files=$(find_in_array "${__find_filename}" "${_active_files[@]}")
function find_in_array {
	
	local __arg_value="${1}"
	shift
	local __arg_array=("$@")
	
	local __found=0
	local __each
	for __each in ${__arg_array[@]}; do
		if [[ "${__arg_value}" == "${__each}" ]]; then
			__found=1
			break
		fi
	done
	
	echo ${__found}

}

function get_newest_dir {

	local __path="${1}"

	echo $(ls -t "${__path}") | awk '{print $1}'

}

function get_user_name_from_tty {

	local __user_name=$(ls -l `tty` | awk '{print $3}')
	
	echo "${__user_name}"

}

# calling example: 
# _egrep_v_files_joined=$(join_for_shell_regex "${_egrep_v_files[@]}")
function join_for_shell_regex {

	local __arg_array=("$@")
	
	local __joined

	local __each
	local __i=0
	for __each in ${__arg_array[@]}; do
		if [[ "${__i}" -eq 0 ]]; then
			__joined="${__each}"
		else
			__joined="${__joined}"'|'"${__each}"
		fi
		__i+=1
	done
	
	__joined='('"${__joined}"')'
	
	echo ${__joined}

}

# calling example: 
# HALCONHG_DIR=$(read_env_or_conf_var 'HALCONHG_DIR' "${_conf_file}")
function read_env_or_conf_var {

	local __the_name="${1}"
	local __the_conffile="${2}"
	
	local __the_value=$(grep "${__the_name}" "${__the_conffile}" | egrep -v '^[[:space:]]*#|^[[:space:]]*$' | sed -n '1p' | sed -r 's/'"${__the_name}"'=(.+)$/\1/')
	
	if [[ -z "${__the_value}" ]]; then
		__the_value=${!__the_name}
	fi
	
	echo "${__the_value}"

}

echo 'Inherited: mclass_utilities'
