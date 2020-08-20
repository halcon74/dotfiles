#!/bin/bash

# Installer script for halcon-overlay
# Synchronizing a Gentoo overlay in a hg (Mercurial) repository, owned by user, with another location, owned by root and portage
# Should be called by root
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
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

source /usr/local/bin/mclass_utilities.sh

# Example file: installer_halconoverlay.conf.example
_conf_file='/usr/local/bin/installer_halconoverlay.conf'

OVERLAY_DIR=$(read_from_conffile 'OVERLAY_DIR' "$_conf_file")
HG_REPO_DIR=$(read_from_conffile 'HG_REPO_DIR' "$_conf_file")

if [[ -z "$OVERLAY_DIR" ]]; then
	exit_err_1 'OVERLAY_DIR is not set'
fi
if [[ -z "$HG_REPO_DIR" ]]; then
	exit_err_1 'HG_REPO_DIR is not set'
fi

if [[ ! -d "$OVERLAY_DIR" ]]; then
	exit_err_1 'OVERLAY_DIR='"$OVERLAY_DIR"': No such diectory'
fi
if [[ ! -d "$HG_REPO_DIR" ]]; then
	exit_err_1 'HG_REPO_DIR='"$HG_REPO_DIR"': No such diectory'
fi

_metadata_files=('layout.conf')
_metadata_portage_files=()

_profile_files=('repo_name')
_profile_portage_files=('repo_name')

_tree_files=('Manifest' 'metadata.xml')
_tree_portage_files=('metadata.xml')

# Set in function set_my_active_files
_active_files=()

_subfolders=('files')

# Set in functions add_to_my_active_path and clear_my_active_path
_active_path=''

_categories=$(find "$HG_REPO_DIR" -maxdepth 1 -mindepth 1 -type d | grep -v '\.hg' | sort)

# No multi-dimensional arrays in bash...
function set_my_active_files {

	local FILE_TYPE="$1"
	local IS_PORTAGE="$2"

	if [[ "$FILE_TYPE" == 'metadata' ]]; then
		if [[ $IS_PORTAGE -eq 1 ]]; then
			_active_files="${_metadata_portage_files[@]}"
		else
			_active_files="${_metadata_files[@]}"
		fi
	elif [[ "$FILE_TYPE" == 'profiles' ]]; then
		if [[ $IS_PORTAGE -eq 1 ]]; then
			_active_files="${_profile_portage_files[@]}"
		else
			_active_files="${_profile_files[@]}"
		fi
	elif [[ "$FILE_TYPE" == 'tree' ]]; then
		if [[ $IS_PORTAGE -eq 1 ]]; then
			_active_files="${_tree_portage_files[@]}"
		else
			_active_files="${_tree_files[@]}"
		fi
	else
		exit_err_1 'Wrong FILE_TYPE '"$FILE_TYPE"
	fi

}

function add_to_my_active_path {

	local ADDING_PATH="$1"
	
	if [[ -z "$ADDING_PATH" ]] || [[ "$ADDING_PATH" =~ [\/] ]] || [[ "$ADDING_PATH" =~ [[:space:]] ]]; then
		exit_err_1 'Wrong ADDING_PATH '"$ADDING_PATH"
	fi

	_active_path+='/'"$ADDING_PATH"

}

function clear_my_active_path {

	_active_path=''

}

function mkdir_n_chown {

	local DIR_OWNER="$1"

	if [[ "$DIR_OWNER" == 'root' ]] || [[ "$DIR_OWNER" == 'portage' ]]; then
		echo
		
		set -x
		mkdir -p "${OVERLAY_DIR}${_active_path}"
		chown "$DIR_OWNER":"$DIR_OWNER" "${OVERLAY_DIR}${_active_path}"
		set +x
	else
		exit_err_1 'Wrong DIR_OWNER '"$DIR_OWNER"
	fi

}

function cp_n_chown {

	local FILE_OWNER="$1"
	local FILENAME="$2"
	
	if [[ -z "$FILENAME" ]] || [[ "$FILENAME" =~ [\/] ]] || [[ "$FILENAME" =~ [[:space:]] ]]; then
		exit_err_1 'Wrong FILENAME '"$FILENAME"
	fi

	if [[ "$FILE_OWNER" == 'root' ]] || [[ "$FILE_OWNER" == 'portage' ]]; then
		set -x
		cp "${HG_REPO_DIR}${_active_path}"'/'"$FILENAME" "${OVERLAY_DIR}${_active_path}"'/'
		chown "$FILE_OWNER":"$FILE_OWNER" "${OVERLAY_DIR}${_active_path}"'/'"$FILENAME"
		set +x
	else
		exit_err_1 'Wrong FILE_OWNER '"$FILE_OWNER"
	fi

}

function handle_overlay_dir {

	if [[ -d "$OVERLAY_DIR" ]]; then
		echo
		echo 'ATTENTION! Delete this directory?
   '"$OVERLAY_DIR"'
(y/n)
If you choose '"'"'n'"'"', the script will be interrupted'

		read USER_CHOICE
		
		if [[ "$USER_CHOICE" == 'y' ]] || [[ "$USER_CHOICE" == 'Y' ]]; then
			echo
			set -x
			rm -r "$OVERLAY_DIR"
			set +x
		else
			echo
			exit_err_1 'User interrupted the script'
		fi
	else
		set -x
		mkdir -p "${OVERLAY_DIR}"
		chown root:root "${OVERLAY_DIR}"
		set +x
	fi

}

function handle_service_files {

	local CATEGORY_NAME="$1"
	
	local FIND_FILES=$(find "${HG_REPO_DIR}${_active_path}" -maxdepth 1 -mindepth 1 -type f | sort)
	
	for FIND_FILE in $(echo "$FIND_FILES"); do
		local FIND_FILENAME=$(basename "$FIND_FILE")
		echo
		
		if [[ "$CATEGORY_NAME" == 'eclass' ]]; then
			if [[ "$FIND_FILENAME" =~ ^.+\.eclass$ ]]; then
				cp_n_chown 'portage' "$FIND_FILENAME"
			else
				exit_err_1 'Wrong service file '"${_active_path}"'/'"$FIND_FILENAME"
			fi
		else
			set_my_active_files "$CATEGORY_NAME" 0
			local FOUND_IN_MY_FILES=$(find_in_array "$FIND_FILENAME" "${_active_files[@]}")
			
			if [[ $FOUND_IN_MY_FILES -eq 1 ]]; then
				set_my_active_files "$CATEGORY_NAME" 1
				local FOUND_IN_MY_PORTAGE_FILES=$(find_in_array "$FIND_FILENAME" "${_active_files[@]}")
				
				if [[ $FOUND_IN_MY_PORTAGE_FILES -eq 1 ]]; then
					cp_n_chown 'portage' "$FIND_FILENAME"
				else
					cp_n_chown 'root' "$FIND_FILENAME"
				fi
			else
				exit_err_1 'Wrong service file '"${_active_path}"'/'"$FIND_FILENAME"
			fi
		fi
	done

}

function handle_tree_files {

	local NO_TREE_CHECK="$1"
	
	local FIND_FILES=$(find "${HG_REPO_DIR}${_active_path}" -maxdepth 1 -mindepth 1 -type f | sort)
	
	for FIND_FILE in $(echo "$FIND_FILES"); do
		local FIND_FILENAME=$(basename "$FIND_FILE")
		echo
		
		if [[ -n "$NO_TREE_CHECK" ]] && [[ "$NO_TREE_CHECK" == 'no_check' ]]; then
			local FOUND_IN_MY_FILES=$(find_in_array "$FIND_FILENAME" "${_active_files[@]}")
			
			cp_n_chown 'root' "$FIND_FILENAME"
		else
			set_my_active_files 'tree' 0
			local FOUND_IN_MY_FILES=$(find_in_array "$FIND_FILENAME" "${_active_files[@]}")
			
			if [[ $FOUND_IN_MY_FILES -eq 1 ]]; then
				set_my_active_files 'tree' 1
				local FOUND_IN_MY_PORTAGE_FILES=$(find_in_array "$FIND_FILENAME" "${_active_files[@]}")
				
				if [[ $FOUND_IN_MY_PORTAGE_FILES -eq 1 ]]; then
					cp_n_chown 'portage' "$FIND_FILENAME"
				else
					cp_n_chown 'root' "$FIND_FILENAME"
				fi
			elif [[ "$FIND_FILENAME" =~ ^.+\.ebuild$ ]]; then
				cp_n_chown 'root' "$FIND_FILENAME"
			else
				exit_err_1 'Wrong tree file '"${_active_path}"'/'"$FIND_FILENAME"
			fi
		fi
	done

}

function handle_folders {
	
	local FIND_FOLDERS=$(find "${HG_REPO_DIR}${_active_path}" -maxdepth 1 -mindepth 1 -type d | sort)
	
	for FIND_FOLDER in $(echo "$FIND_FOLDERS"); do
		local FIND_FOLDERNAME=$(basename "$FIND_FOLDER")
		
		add_to_my_active_path "$FIND_FOLDERNAME"
		mkdir_n_chown 'portage'
		handle_tree_files ''
		
		local FIND_SUBFOLDERS=$(find "${HG_REPO_DIR}${_active_path}" -maxdepth 1 -mindepth 1 -type d | sort)
		
		for FIND_SUBFOLDER in $(echo "$FIND_SUBFOLDERS"); do
			local FIND_SUBFOLDERNAME=$(basename "$FIND_SUBFOLDER")
			echo
			
			local FOUND_IN_MY_SUBFOLDERS=$(find_in_array "$FIND_SUBFOLDERNAME" "${_subfolders[@]}")
			
			if [[ $FOUND_IN_MY_SUBFOLDERS -eq 1 ]]; then
				add_to_my_active_path "$FIND_SUBFOLDERNAME"
				mkdir_n_chown 'root'
				handle_tree_files 'no_check'
			else
				add_to_my_active_path "$FIND_SUBFOLDERNAME"
				exit_err_1 'Wrong subfolder '"${_active_path}"
			fi
		done
	done

}

function check_diff {

	echo
	echo

	local DIFF_UR=$(diff -ur "${HG_REPO_DIR}" "${OVERLAY_DIR}" | grep -v ': \.hg')
	
	if [[ "$DIFF_UR" != '' ]]; then
		exit_err_1 'DIFF_UR non-empty: 
'"${DIFF_UR}"
	fi

}

function main {

	handle_overlay_dir

	for MY_CATEGORY in $(echo "$_categories"); do	
		local CATEGORY_NAME=$(basename "$MY_CATEGORY")
		echo
		
		clear_my_active_path
		add_to_my_active_path "$CATEGORY_NAME"
		mkdir_n_chown 'portage'
		
		if [[ "$CATEGORY_NAME" == 'metadata' ]] || [[ "$CATEGORY_NAME" == 'profiles' ]] || [[ "$CATEGORY_NAME" == 'eclass' ]]; then
			handle_service_files "$CATEGORY_NAME"
		elif [[ "$CATEGORY_NAME" =~ ^[^\-]+\-[^\-]+$ ]]; then
			handle_folders
		else
			exit_err_1 'Wrong category: '"$CATEGORY_NAME"
		fi
	done
	
	check_diff

}

main
	
exit 0
