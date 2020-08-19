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
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

# calling example: 
# FOUND_IN_SCRIPTS=$(find_in_array "$FILENAME" "${MY_SCRIPTS[@]}")
function find_in_array {
	
	local ARG_VALUE="$1"
	shift
	local ARG_ARRAY=("$@")
	
	local FOUND=0
	for EACH in ${ARG_ARRAY[@]}; do
		if [[ "$ARG_VALUE" == "$EACH" ]]; then
			FOUND=1
			break
		fi
	done
	
	echo $FOUND

}

# calling example: 
# exit_err_1 'Wrong category: '"$CATEGORY_NAME"
function exit_err_1 {
	
	local ARG_ERROR="$1"

	echo "$ARG_ERROR"'.

Exiting 1.'
	exit 1

}

# calling example: 
# MY_OVERLAY_DIR=$(read_from_conffile 'MY_OVERLAY_DIR' "$MY_CONFFILE")
function read_from_conffile {

	local THE_NAME="$1"
	local THE_CONFFILE="$2"
	
	local THE_VALUE=$(grep "$THE_NAME" "$THE_CONFFILE" | egrep -v '^[[:space:]]*#|^[[:space:]]*$' | sed -n '1p' | sed -r 's/'"$THE_NAME"'=(.+)$/\1/')
	
	echo "$THE_VALUE"

}

echo 'Inherited: mclass_utilities'
