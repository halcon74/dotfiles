#!/bin/bash

# Collection of useful shell functions - utilities
#
# Copyright (C) 2020 Alexey Mishustin shumkar@shumkar.ru
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

# calling example: 
# exit_err_1 'Wrong category: '"${__category_name}"
function exit_err_1 {
	
	local __arg_error="${1}"

	echo "${__arg_error}"'.

Exiting 1.'
	exit 1

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
