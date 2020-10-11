#!/bin/bash

# Installer script for halcon-overlay
# Synchronizing a Gentoo overlay in a hg (Mercurial) repository, owned by user, with another location, owned by root and portage
# Checking that files/folders names are permitted in the overlay
# Should be called by root
#
# The script uses the following Environment Variables: ( HALCONOVERLAY_DIR HALCONHG_DIR )
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

source /usr/local/bin/mclass_utilities.sh

# Example file: installer_halconoverlay.conf.example
_conf_file='/usr/local/bin/installer_halconoverlay.conf'

HALCONOVERLAY_DIR=$(read_env_or_conf_var 'HALCONOVERLAY_DIR' "${_conf_file}") || exit $?
HALCONHG_DIR=$(read_env_or_conf_var 'HALCONHG_DIR' "${_conf_file}") || exit $?

if [[ -z "${HALCONOVERLAY_DIR}" ]]; then
	exit_err_1 'HALCONOVERLAY_DIR is not set'
fi
if [[ -z "${HALCONHG_DIR}" ]]; then
	exit_err_1 'HALCONHG_DIR is not set'
fi

if [[ ! -d "${HALCONOVERLAY_DIR}" ]]; then
	exit_err_1 'HALCONOVERLAY_DIR='"${HALCONOVERLAY_DIR}"': No such directory'
fi
if [[ ! -d "${HALCONHG_DIR}" ]]; then
	exit_err_1 'HALCONHG_DIR='"${HALCONHG_DIR}"': No such directory'
fi

_metadata_files=('layout.conf')
_metadata_portage_files=()

_overlay_files=('overlay.xml' 'README.md')
_overlay_portage_files=()

_profiles_files=('repo_name' 'use.desc' 'use.local.desc')
_profiles_portage_files=()

_tree_files=('Manifest' 'metadata.xml')
_tree_portage_files=('metadata.xml')

_keys_for_active_files=('metadata' 'overlay' 'profiles' 'tree')

# Set in function set_my_active_files
_active_files=()

_subfolders=('files')

# Set in functions add_to_my_active_path and clear_my_active_path
_active_path=''

_egrep_v_files=('\.hg')
_egrep_v_folders=('\.hg')
_egrep_v_diff=(': \.hg')

_egrep_v_files_joined=$(join_for_shell_regex "${_egrep_v_files[@]}")
_egrep_v_folders_joined=$(join_for_shell_regex "${_egrep_v_folders[@]}")
_egrep_v_diff_joined=$(join_for_shell_regex "${_egrep_v_diff[@]}")

_categories=$(find "${HALCONHG_DIR}" -maxdepth 1 -mindepth 1 -type d | egrep -v "${_egrep_v_folders_joined}" | sort)

function set_my_active_files {

	local __file_type="${1}"
	local __is_portage="${2}"

	local __find_in_keys_for_active_files=$(find_in_array "${__file_type}" "${_keys_for_active_files[@]}")
	if [[ ${__find_in_keys_for_active_files} -ne 1 ]]; then
		exit_err_1 'Wrong __file_type '"${__file_type}"
	fi

	local __evaling_portage=''
	if [[ "${__is_portage}" -eq 1 ]]; then
		__evaling_portage='_portage'
	fi

	eval _active_files=( '"${_'${__file_type}${__evaling_portage}'_files[@]}"' )

}

function add_to_my_active_path {

	local __adding_path="${1}"

	if [[ -z "${__adding_path}" || "${__adding_path}" =~ [\/] || "${__adding_path}" =~ [[:space:]] ]]; then
		exit_err_1 'Wrong __adding_path '"${__adding_path}"
	fi

	_active_path+='/'"${__adding_path}"

}

function clear_my_active_path {

	_active_path=''

}

function mkdir_n_chown {

	local __dir_owner="${1}"

	if [[ "${__dir_owner}" == 'root' || "${__dir_owner}" == 'portage' ]]; then
		echo

		set -x
		mkdir -p "${HALCONOVERLAY_DIR}${_active_path}"
		chown "${__dir_owner}":"${__dir_owner}" "${HALCONOVERLAY_DIR}${_active_path}"
		set +x
	else
		exit_err_1 'Wrong __dir_owner '"${__dir_owner}"
	fi

}

function handle_overlay_dir {

	if [[ -d "${HALCONOVERLAY_DIR}" ]]; then
		echo
		echo 'ATTENTION! Delete this directory?
   '"${HALCONOVERLAY_DIR}"'
(y/n)
If you choose '"'"'n'"'"', the script will be interrupted'
		local USER_CHOICE
		read USER_CHOICE

		if [[ "${USER_CHOICE}" == 'y' || "${USER_CHOICE}" == 'Y' ]]; then
			echo
			set -x
			rm -r "${HALCONOVERLAY_DIR}"
			mkdir -p "${HALCONOVERLAY_DIR}"
			chown root:root "${HALCONOVERLAY_DIR}"
			set +x
		else
			echo
			exit_err_1 'User interrupted the script'
		fi
	else
		set -x
		mkdir -p "${HALCONOVERLAY_DIR}"
		chown root:root "${HALCONOVERLAY_DIR}"
		set +x
	fi

}

function handle_overlay_files {

	local __find_files=$(find "${HALCONHG_DIR}${_active_path}" -maxdepth 1 -mindepth 1 -type f | egrep -v "${_egrep_v_files_joined}" |sort)

	local __find_file
	for __find_file in $(echo "${__find_files}"); do
		local __find_filename="${__find_file##*/}"
		echo

		local __full_file_name="${HALCONHG_DIR}${_active_path}"'/'"${__find_filename}"
		local __dest_dir="${HALCONOVERLAY_DIR}${_active_path}"

		set_my_active_files "overlay" 0
		local __find_in_my_files=$(find_in_array "${__find_filename}" "${_active_files[@]}")
		if [[ ${__find_in_my_files} -eq 1 ]]; then
			cp_n_chown_n_chmod "${__full_file_name}" 'portage:portage' 644 "${__dest_dir}" || exit $?
		else
			exit_err_1 'Wrong overlay file '"${_active_path}"'/'"${__find_filename}"
		fi

	done

}

function handle_service_files {

	local __category_name="${1}"

	local __find_files=$(find "${HALCONHG_DIR}${_active_path}" -maxdepth 1 -mindepth 1 -type f | sort)

	local __find_file
	for __find_file in $(echo "${__find_files}"); do
		local __find_filename="${__find_file##*/}"
		echo

		local __full_file_name="${HALCONHG_DIR}${_active_path}"'/'"${__find_filename}"
		local __dest_dir="${HALCONOVERLAY_DIR}${_active_path}"

		if [[ "${__category_name}" == 'eclass' ]]; then
			if [[ "${__find_filename}" =~ ^.+\.eclass$ ]]; then
				cp_n_chown_n_chmod "${__full_file_name}" 'portage:portage' 644 "${__dest_dir}" || exit $?
			else
				exit_err_1 'Wrong service file '"${_active_path}"'/'"${__find_filename}"
			fi
		elif [[ "${__category_name}" == 'licenses' ]]; then
				cp_n_chown_n_chmod "${__full_file_name}" 'portage:portage' 644 "${__dest_dir}" || exit $?
		else
			set_my_active_files "${__category_name}" 0
			local __find_in_my_files=$(find_in_array "${__find_filename}" "${_active_files[@]}")

			if [[ ${__find_in_my_files} -eq 1 ]]; then
				set_my_active_files "${__category_name}" 1
				local __found_in_my_portage_files=$(find_in_array "${__find_filename}" "${_active_files[@]}")

				if [[ ${__found_in_my_portage_files} -eq 1 ]]; then
					cp_n_chown_n_chmod "${__full_file_name}" 'portage:portage' 644 "${__dest_dir}" || exit $?
				else
					cp_n_chown_n_chmod "${__full_file_name}" 'root:root' 644 "${__dest_dir}" || exit $?
				fi
			else
				exit_err_1 'Wrong service file '"${_active_path}"'/'"${__find_filename}"
			fi
		fi
	done

}

function handle_tree_files {

	local __no_tree_check="${1}"

	local __find_files=$(find "${HALCONHG_DIR}${_active_path}" -maxdepth 1 -mindepth 1 -type f | sort)

	local __find_file
	for __find_file in $(echo "${__find_files}"); do
		local __find_filename="${__find_file##*/}"
		echo

		local __full_file_name="${HALCONHG_DIR}${_active_path}"'/'"${__find_filename}"
		local __dest_dir="${HALCONOVERLAY_DIR}${_active_path}"

		if [[ -n "${__no_tree_check}" && "${__no_tree_check}" == 'no_check' ]]; then
			local __find_in_my_files=$(find_in_array "${__find_filename}" "${_active_files[@]}")

			cp_n_chown_n_chmod "${__full_file_name}" 'root:root' 644 "${__dest_dir}" || exit $?
		else
			set_my_active_files 'tree' 0
			local __find_in_my_files=$(find_in_array "${__find_filename}" "${_active_files[@]}")

			if [[ ${__find_in_my_files} -eq 1 ]]; then
				set_my_active_files 'tree' 1
				local __found_in_my_portage_files=$(find_in_array "${__find_filename}" "${_active_files[@]}")

				if [[ ${__found_in_my_portage_files} -eq 1 ]]; then
					cp_n_chown_n_chmod "${__full_file_name}" 'portage:portage' 644 "${__dest_dir}" || exit $?
				else
					cp_n_chown_n_chmod "${__full_file_name}" 'root:root' 644 "${__dest_dir}" || exit $?
				fi
			elif [[ "${__find_filename}" =~ ^.+\.ebuild$ ]]; then
				cp_n_chown_n_chmod "${__full_file_name}" 'root:root' 644 "${__dest_dir}" || exit $?
			else
				exit_err_1 'Wrong tree file '"${_active_path}"'/'"${__find_filename}"
			fi
		fi
	done

}

function handle_folders {

	local __find_folders=$(find "${HALCONHG_DIR}${_active_path}" -maxdepth 1 -mindepth 1 -type d | sort)

	local __find_folder
	for __find_folder in $(echo "${__find_folders}"); do
		local __find_foldername="${__find_folder##*/}"

		add_to_my_active_path "${__find_foldername}"
		mkdir_n_chown 'portage'
		handle_tree_files ''

		local __find_subfolders=$(find "${HALCONHG_DIR}${_active_path}" -maxdepth 1 -mindepth 1 -type d | sort)

		local __find_subfolder
		for __find_subfolder in $(echo "${__find_subfolders}"); do
			local __find_subfoldername="${__find_subfolder##*/}"
			echo

			local __found_in_my_subfolders=$(find_in_array "${__find_subfoldername}" "${_subfolders[@]}")

			if [[ ${__found_in_my_subfolders} -eq 1 ]]; then
				add_to_my_active_path "${__find_subfoldername}"
				mkdir_n_chown 'root'
				handle_tree_files 'no_check'
			else
				add_to_my_active_path "${__find_subfoldername}"
				exit_err_1 'Wrong subfolder '"${_active_path}"
			fi
		done
	done

}

function check_diff {

	echo
	echo

	local __diff_ur=$(diff -ur "${HALCONHG_DIR}" "${HALCONOVERLAY_DIR}" | egrep -v "${_egrep_v_diff_joined}")

	if [[ "${__diff_ur}" != '' ]]; then
		exit_err_1 '__diff_ur non-empty: 
'"${__diff_ur}"
	fi

}

function main {

	handle_overlay_dir
	handle_overlay_files

	local __my_category
	for __my_category in $(echo "${_categories}"); do
		local __category_name="${__my_category##*/}"
		echo

		clear_my_active_path
		add_to_my_active_path "${__category_name}"
		mkdir_n_chown 'portage'

		if [[ "${__category_name}" == 'metadata' || "${__category_name}" == 'profiles' || "${__category_name}" == 'eclass' || "${__category_name}" == 'licenses' ]]; then
			handle_service_files "${__category_name}"
		elif [[ "${__category_name}" =~ ^[^\-]+\-[^\-]+$ ]]; then
			handle_folders
		else
			exit_err_1 'Wrong category: '"${__category_name}"
		fi
	done

	check_diff

}

main

exit 0

