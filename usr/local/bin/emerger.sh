#!/bin/bash
#
# Script-alias for `emerge`, giving the possibility to log the output of `emerge --sync`, preserving color, with date added
#
# The script is intended to be copied to a location in PATH (for example, /usr/local/bin), and after that
# the folllowing line should be added to shell aliases of root OR of a user in 'wheel' group:
# alias emerge='emerger.sh'
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
#
# # # # # HEADS-UP ! # # # # #
#
# DON'T FORGET to add something like
# /var/log/emerge-sync.log {
#	olddir /var/log/rotated/
#	postrotate
#		logger -p user.alert "emerge-sync.log has been rotated."
#	endscript
# }
# to your /etc/logrotate.conf !

source /usr/local/bin/mclass_utilities.sh

# for saving $@
_all_args=()
# the first arg
_sync_or_not_sync=''
# a regex for sanitizing args
_arg_regex='^[a-zA-Z0-9._=:+/\@\-]+$'
# where to log emerge --sync output
_log_file='/var/log/emerge-sync.log'

_arg_num=0
for _arg in "$@"; do
	_all_args+=("${_arg}")
	let "_arg_num+=1"
	if [[ ! "${_arg}" =~ ${_arg_regex} ]]; then
		exit_err_1 'The parameter #'"${_arg_num}"' does not match the regex '"${_arg_regex}"
	fi
	if [[ ${_arg_num} -eq 1 ]]; then
		_sync_or_not_sync="${_arg}"
	fi
	if [[ ${_arg_num} -ne 1 && "${_arg}" == '--sync' ]]; then
		exit_err_1 'The parameter --sync not allowed as $'"${_arg_num}"' (allowed as $1 only)'
	fi
done

function main {

	if [[ "${_sync_or_not_sync}" == '--sync' ]]; then
		local __current_date=$(date +%Y-%m-%d\ %H:%M:%S)
		local __lines_with_date='
emerger.sh: '"${__current_date}"'
'
		echo "${__lines_with_date}" >> "${_log_file}"
		emerge "${_all_args[@]}" --color=y | tee -a "${_log_file}"
	else
		emerge "${_all_args[@]}"
	fi

}

main

exit 0
