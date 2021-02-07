#!/bin/bash

# Manifester script for halcon-overlay
# Regenerating manifests and synchronizing a Gentoo overlay in a location, owned by root and portage, with a hg (Mercurial) repository, owned by user
# Should be called by root (got by user with `su`, in a terminal/console opened by user, see _user_name)
#
# The script uses the following Environment Variables: ( MVAR_DIR_EREPO_LOCAL MVAR_DIR_MYPROG_HOV )
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

_conf_file='/usr/local/bin/installer_halconoverlay.conf'
MVAR_DIR_EREPO_LOCAL=$(read_env_or_conf_var 'MVAR_DIR_EREPO_LOCAL' "${_conf_file}") || exit $?
MVAR_DIR_MYPROG_HOV=$(read_env_or_conf_var 'MVAR_DIR_MYPROG_HOV' "${_conf_file}") || exit $?

if [[ -z "${MVAR_DIR_EREPO_LOCAL}" ]]; then
	exit_err_1 'MVAR_DIR_EREPO_LOCAL is not set'
fi
if [[ -z "${MVAR_DIR_MYPROG_HOV}" ]]; then
	exit_err_1 'MVAR_DIR_MYPROG_HOV is not set'
fi

if [[ ! -d "${MVAR_DIR_EREPO_LOCAL}" ]]; then
	exit_err_1 'MVAR_DIR_EREPO_LOCAL='"${MVAR_DIR_EREPO_LOCAL}"': No such diectory'
fi
if [[ ! -d "${MVAR_DIR_MYPROG_HOV}" ]]; then
	exit_err_1 'MVAR_DIR_MYPROG_HOV='"${MVAR_DIR_MYPROG_HOV}"': No such diectory'
fi

_user_name=$(get_user_name_from_tty)

# Set in functions add_to_my_active_path and clear_my_active_path
_active_path=''

_categories=$(find "${MVAR_DIR_EREPO_LOCAL}" -maxdepth 1 -mindepth 1 -type d | sort)

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

function set_my_active_path {

	local __setting_path="${1}"

	_active_path="${__setting_path}"

}

function handle_manifests {

	local __manifest_file="${MVAR_DIR_EREPO_LOCAL}${_active_path}"'/Manifest'

	set -x
	rm "${__manifest_file}"
	set +x

	local __find_files=$(find "${MVAR_DIR_EREPO_LOCAL}${_active_path}" -maxdepth 1 -mindepth 1 -type f | sort)

	local __find_file
	for __find_file in $(echo "${__find_files}"); do
		local __find_filename="${__find_file##*/}"
		if [[ "${__find_filename}" =~ ^.+\.ebuild$ ]]; then
			set -x
			ebuild "${__find_file}" manifest
			if [[ $? != 0 ]]; then
				exit_err_1 'ebuild returned ERROR'
			fi
			set +x
		fi
	done

	local __manifest_filename="${__manifest_file##*/}"
	local __full_file_name="${MVAR_DIR_EREPO_LOCAL}${_active_path}"'/'"${__manifest_filename}"
	local __dest_dir="${MVAR_DIR_MYPROG_HOV}${_active_path}"
	cp_n_chown_n_chmod "${__full_file_name}" "${_user_name}"':'"${_user_name}" 644 "${__dest_dir}" || exit $?

}

function handle_folders {

	local __find_folders=$(find "${MVAR_DIR_EREPO_LOCAL}${_active_path}" -maxdepth 1 -mindepth 1 -type d | sort)
	local __active_path_without_folders="${_active_path}"

	local __find_folder
	for __find_folder in $(echo "${__find_folders}"); do
		local __find_foldername="${__find_folder##*/}"

		set_my_active_path "${__active_path_without_folders}"
		add_to_my_active_path "${__find_foldername}"
		handle_manifests || exit $?

	done

}

function main {

	local __my_category
	for __my_category in $(echo "${_categories}"); do
		local __category_name="${__my_category##*/}"

		clear_my_active_path
		add_to_my_active_path "${__category_name}"

		if [[ "${__category_name}" != 'metadata' && "${__category_name}" != 'profiles' && "${__category_name}" != 'eclass' && "${__category_name}" != 'licenses' ]]; then
			echo

			handle_folders
		fi
	done

}

main

exit 0
