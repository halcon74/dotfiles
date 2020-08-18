#!/bin/bash

# Installer script for halcon-overlay
# Synchronizing an overlay in a hg (Mercurial) repository, owned by user, with another location, owned by root and portage
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
MY_CONFFILE='/usr/local/bin/installer_halconoverlay.conf'

MY_OVERLAY_DIR=$(grep 'MY_OVERLAY_DIR' "$MY_CONFFILE" | sed -n '1p' | cut -d '=' -f2)
MY_REPO_DIR=$(grep 'MY_REPO_DIR' "$MY_CONFFILE" | sed -n '1p' | cut -d '=' -f2)

if [[ -z "$MY_OVERLAY_DIR" ]]; then
	exit_err_1 'MY_OVERLAY_DIR is not set'
fi
if [[ -z "$MY_REPO_DIR" ]]; then
	exit_err_1 'MY_REPO_DIR is not set'
fi

if [[ ! -d "$MY_OVERLAY_DIR" ]]; then
	exit_err_1 'MY_OVERLAY_DIR='"$MY_OVERLAY_DIR"': No such diectory'
fi
if [[ ! -d "$MY_REPO_DIR" ]]; then
	exit_err_1 'MY_REPO_DIR='"$MY_REPO_DIR"': No such diectory'
fi

MY_METADATA_FILES=('layout.conf')
MY_METADATA_PORTAGE_FILES=()

MY_PROFILE_FILES=('repo_name')
MY_PROFILE_PORTAGE_FILES=('repo_name')

MY_TREE_FILES=('Manifest' 'metadata.xml')
MY_TREE_PORTAGE_FILES=('metadata.xml')

# Set in function set_my_active_files
MY_ACTIVE_FILES=()

MY_SUBFOLDERS=('files')

# Set in functions add_to_my_active_path and clear_my_active_path
MY_ACTIVE_PATH=''

MY_CATEGORIES=$(find "$MY_REPO_DIR" -maxdepth 1 -mindepth 1 -type d | grep -v '\.hg' | sort)

# No multi-dimensional arrays in bash...
function set_my_active_files {

	local FILE_TYPE="$1"
	local IS_PORTAGE="$2"

	if [[ "$FILE_TYPE" == 'metadata' ]]; then
		if [[ $IS_PORTAGE -eq 1 ]]; then
			MY_ACTIVE_FILES="${MY_METADATA_PORTAGE_FILES[@]}"
		else
			MY_ACTIVE_FILES="${MY_METADATA_FILES[@]}"
		fi
	elif [[ "$FILE_TYPE" == 'profiles' ]]; then
		if [[ $IS_PORTAGE -eq 1 ]]; then
			MY_ACTIVE_FILES="${MY_PROFILE_PORTAGE_FILES[@]}"
		else
			MY_ACTIVE_FILES="${MY_PROFILE_FILES[@]}"
		fi
	elif [[ "$FILE_TYPE" == 'tree' ]]; then
		if [[ $IS_PORTAGE -eq 1 ]]; then
			MY_ACTIVE_FILES="${MY_TREE_PORTAGE_FILES[@]}"
		else
			MY_ACTIVE_FILES="${MY_TREE_FILES[@]}"
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

	MY_ACTIVE_PATH+='/'"$ADDING_PATH"

}

function clear_my_active_path {

	MY_ACTIVE_PATH=''

}

function mkdir_n_chown {

	local DIR_OWNER="$1"

	if [[ "$DIR_OWNER" == 'root' ]] || [[ "$DIR_OWNER" == 'portage' ]]; then
		echo
		
		set -x
		mkdir -p "${MY_OVERLAY_DIR}${MY_ACTIVE_PATH}"
		chown "$DIR_OWNER":"$DIR_OWNER" "${MY_OVERLAY_DIR}${MY_ACTIVE_PATH}"
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
		cp "${MY_REPO_DIR}${MY_ACTIVE_PATH}"'/'"$FILENAME" "${MY_OVERLAY_DIR}${MY_ACTIVE_PATH}"'/'
		chown "$FILE_OWNER":"$FILE_OWNER" "${MY_OVERLAY_DIR}${MY_ACTIVE_PATH}"'/'"$FILENAME"
		set +x
	else
		exit_err_1 'Wrong FILE_OWNER '"$FILE_OWNER"
	fi

}

function handle_overlay_dir {

	if [[ -d "$MY_OVERLAY_DIR" ]]; then
		echo
		echo 'ATTENTION! Delete this directory?
   '"$MY_OVERLAY_DIR"'
(y/n)
If you choose '"'"'n'"'"', the script will be interrupted'

		read USER_CHOICE
		
		if [[ "$USER_CHOICE" == 'y' ]]; then
			echo
			set -x
			rm -r "$MY_OVERLAY_DIR"
			set +x
		else
			echo
			exit_err_1 'User interrupted the script'
		fi
	else
		set -x
		mkdir -p "${MY_OVERLAY_DIR}"
		chown root:root "${MY_OVERLAY_DIR}"
		set +x
	fi

}

function handle_service_files {
	
	local FIND_FILES=$(find "${MY_REPO_DIR}${MY_ACTIVE_PATH}" -maxdepth 1 -mindepth 1 -type f | sort)
	
	for FIND_FILE in $(echo "$FIND_FILES"); do
		local FIND_FILENAME=$(basename "$FIND_FILE")
		echo
		
		set_my_active_files "$CATEGORY_NAME" 0
		local FOUND_IN_MY_FILES=$(find_in_array "$FIND_FILENAME" "${MY_ACTIVE_FILES[@]}")
		
		if [[ $FOUND_IN_MY_FILES -eq 1 ]]; then
			set_my_active_files "$CATEGORY_NAME" 1
			local FOUND_IN_MY_PORTAGE_FILES=$(find_in_array "$FIND_FILENAME" "${MY_ACTIVE_FILES[@]}")
			
			if [[ $FOUND_IN_MY_PORTAGE_FILES -eq 1 ]]; then
				cp_n_chown 'portage' "$FIND_FILENAME"
			else
				cp_n_chown 'root' "$FIND_FILENAME"
			fi
		else
			exit_err_1 'Wrong service file '"${MY_ACTIVE_PATH}"'/'"$FIND_FILENAME"
		fi
	done

}

function handle_tree_files {

	local NO_TREE_CHECK="$1"
	
	local FIND_FILES=$(find "${MY_REPO_DIR}${MY_ACTIVE_PATH}" -maxdepth 1 -mindepth 1 -type f | sort)
	
	for FIND_FILE in $(echo "$FIND_FILES"); do
		local FIND_FILENAME=$(basename "$FIND_FILE")
		echo
		
		if [[ -n "$NO_TREE_CHECK" ]] && [[ "$NO_TREE_CHECK" == 'no_check' ]]; then
			local FOUND_IN_MY_FILES=$(find_in_array "$FIND_FILENAME" "${MY_ACTIVE_FILES[@]}")
			
			cp_n_chown 'root' "$FIND_FILENAME"
		else
			set_my_active_files 'tree' 0
			local FOUND_IN_MY_FILES=$(find_in_array "$FIND_FILENAME" "${MY_ACTIVE_FILES[@]}")
			
			if [[ $FOUND_IN_MY_FILES -eq 1 ]]; then
				set_my_active_files 'tree' 1
				local FOUND_IN_MY_PORTAGE_FILES=$(find_in_array "$FIND_FILENAME" "${MY_ACTIVE_FILES[@]}")
				
				if [[ $FOUND_IN_MY_PORTAGE_FILES -eq 1 ]]; then
					cp_n_chown 'portage' "$FIND_FILENAME"
				else
					cp_n_chown 'root' "$FIND_FILENAME"
				fi
			elif [[ "$FIND_FILENAME" =~ ^.+\.ebuild$ ]]; then
				cp_n_chown 'root' "$FIND_FILENAME"
			else
				exit_err_1 'Wrong tree file '"${MY_ACTIVE_PATH}"'/'"$FIND_FILENAME"
			fi
		fi
	done

}

function handle_folders {
	
	local FIND_FOLDERS=$(find "${MY_REPO_DIR}${MY_ACTIVE_PATH}" -maxdepth 1 -mindepth 1 -type d | sort)
	
	for FIND_FOLDER in $(echo "$FIND_FOLDERS"); do
		local FIND_FOLDERNAME=$(basename "$FIND_FOLDER")
		
		add_to_my_active_path "$FIND_FOLDERNAME"
		mkdir_n_chown 'portage'
		handle_tree_files ''
		
		local FIND_SUBFOLDERS=$(find "${MY_REPO_DIR}${MY_ACTIVE_PATH}" -maxdepth 1 -mindepth 1 -type d | sort)
		
		for FIND_SUBFOLDER in $(echo "$FIND_SUBFOLDERS"); do
			local FIND_SUBFOLDERNAME=$(basename "$FIND_SUBFOLDER")
			echo
			
			local FOUND_IN_MY_SUBFOLDERS=$(find_in_array "$FIND_SUBFOLDERNAME" "${MY_SUBFOLDERS[@]}")
			
			if [[ $FOUND_IN_MY_SUBFOLDERS -eq 1 ]]; then
				add_to_my_active_path "$FIND_SUBFOLDERNAME"
				mkdir_n_chown 'root'
				handle_tree_files 'no_check'
			else
				add_to_my_active_path "$FIND_SUBFOLDERNAME"
				exit_err_1 'Wrong folder '"${MY_ACTIVE_PATH}"
			fi
		done
	done

}

function check_diff {

	echo
	echo

	local MY_DIFF=$(diff -ur "${MY_REPO_DIR}" "${MY_OVERLAY_DIR}" | grep -v ': \.hg')
	
	if [[ "$MY_DIFF" != '' ]]; then
		exit_err_1 'MY_DIFF non-empty: 
'"${MY_DIFF}"
	fi

}

function main {

	handle_overlay_dir

	for MY_CATEGORY in $(echo "$MY_CATEGORIES"); do	
		local CATEGORY_NAME=$(basename "$MY_CATEGORY")
		echo
		
		clear_my_active_path
		add_to_my_active_path "$CATEGORY_NAME"
		mkdir_n_chown 'portage'
		
		if [[ "$CATEGORY_NAME" == 'metadata' ]]; then
			handle_service_files
		elif [[ "$CATEGORY_NAME" == 'profiles' ]]; then
			handle_service_files
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
