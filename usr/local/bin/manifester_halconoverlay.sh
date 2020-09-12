#!/bin/bash

# Manifester script for halcon-overlay
# Regenerating manifests and synchronizing a Gentoo overlay in a location, owned by root and portage, with a hg (Mercurial) repository, owned by user
# Should be called by root (got by user with `su`, in a terminal/console opened by user)
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

source /usr/local/bin/mclass_utilities.sh

# Example file: installer_halconoverlay.conf.example
_conf_file='/usr/local/bin/installer_halconoverlay.conf'

OVERLAY_DIR=$(read_from_conffile 'OVERLAY_DIR' "${_conf_file}")
HG_REPO_DIR=$(read_from_conffile 'HG_REPO_DIR' "${_conf_file}")

if [[ -z "${OVERLAY_DIR}" ]]; then
	exit_err_1 'OVERLAY_DIR is not set'
fi
if [[ -z "${HG_REPO_DIR}" ]]; then
	exit_err_1 'HG_REPO_DIR is not set'
fi

if [[ ! -d "${OVERLAY_DIR}" ]]; then
	exit_err_1 'OVERLAY_DIR='"${OVERLAY_DIR}"': No such diectory'
fi
if [[ ! -d "${HG_REPO_DIR}" ]]; then
	exit_err_1 'HG_REPO_DIR='"${HG_REPO_DIR}"': No such diectory'
fi

_user_name=$(ls -l `tty` | awk '{print $3}')

# Set in functions add_to_my_active_path and clear_my_active_path
_active_path=''

_categories=$(find "${OVERLAY_DIR}" -maxdepth 1 -mindepth 1 -type d | sort)

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

function cp_n_chown {

	local __file_owner="${_user_name}"
	local __filename="${1}"
	
	if [[ -z "${__filename}" || "${__filename}" =~ [\/] || "${__filename}" =~ [[:space:]] ]]; then
		exit_err_1 'Wrong __filename '"${__filename}"
	fi

	set -x
	cp "${OVERLAY_DIR}${_active_path}"'/'"${__filename}" "${HG_REPO_DIR}${_active_path}"'/'
	chown "${__file_owner}":"${__file_owner}" "${HG_REPO_DIR}${_active_path}"'/'"${__filename}"
	set +x

}

function handle_manifests {
	
	local __manifest_file="${OVERLAY_DIR}${_active_path}"'/Manifest'
	
	set -x
	rm "${__manifest_file}"
	set +x
	
	local __find_files=$(find "${OVERLAY_DIR}${_active_path}" -maxdepth 1 -mindepth 1 -type f | sort)
	
	local __find_file
	for __find_file in $(echo "${__find_files}"); do
		local __find_filename="${__find_file##*/}"
		if [[ "${__find_filename}" =~ ^.+\.ebuild$ ]]; then
			set -x
			ebuild "${__find_file}" manifest
			set +x
		fi
	done

	local __manifest_filename="${__manifest_file##*/}"
	cp_n_chown "${__manifest_filename}"
}

function handle_folders {
	
	local __find_folders=$(find "${OVERLAY_DIR}${_active_path}" -maxdepth 1 -mindepth 1 -type d | sort)
	
	local __find_folder
	for __find_folder in $(echo "${__find_folders}"); do
		local __find_foldername="${__find_folder##*/}"
		
		add_to_my_active_path "${__find_foldername}"
		handle_manifests

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
