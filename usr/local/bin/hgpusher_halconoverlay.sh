#!/bin/bash

# Helper script for pushing to halcon-overlay
# Pushes a local hg (Mercurial) repository with different branches and bookmarks to a remote repository in the way compatible with hg-git
#
# The script uses the following Environment Variables: ( MVAR_DIR_MYPROG_HOV MVAR_DIR_REMOTE_HOV )
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
# hgpusher_halconoverlay.sh default
# or
# hgpusher_halconoverlay.sh some_other_hg_branch
_branch="${1}"

source /usr/local/bin/mclass_utilities.sh

if [[ -z "${_branch}" ]]; then
	exit_err_1 'branch argument is not passed'
fi

_conf_file='/usr/local/bin/installer_halconoverlay.conf'
MVAR_DIR_REMOTE_HOV=$(read_env_or_conf_var 'MVAR_DIR_REMOTE_HOV' "${_conf_file}") || exit $?
MVAR_DIR_MYPROG_HOV=$(read_env_or_conf_var 'MVAR_DIR_MYPROG_HOV' "${_conf_file}") || exit $?

if [[ -z "${MVAR_DIR_MYPROG_HOV}" ]]; then
	exit_err_1 'MVAR_DIR_MYPROG_HOV is not set'
fi
if [[ -z "${MVAR_DIR_REMOTE_HOV}" ]]; then
	exit_err_1 'MVAR_DIR_REMOTE_HOV is not set'
fi

if [[ ! -d "${MVAR_DIR_MYPROG_HOV}" ]]; then
	exit_err_1 'MVAR_DIR_MYPROG_HOV='"${MVAR_DIR_MYPROG_HOV}"': No such diectory'
fi

set -x
pushd "${MVAR_DIR_MYPROG_HOV}"
set +x

_exists_branch=$(hg branches | grep "${_branch}" | wc -l)

if [[ "${_exists_branch}" -ne 1 ]]; then
	exit_err_1 'hg branch error: _exists_branch='"${_exists_branch}"
fi

_bookmark="${_branch}"
if [[ "${_bookmark}" == 'default' ]]; then
	_bookmark='master'
fi

set -x
LC_ALL=C hg bookmark --rev tip "${_bookmark}"
LC_ALL=C hg push --verbose "${MVAR_DIR_REMOTE_HOV}"
popd
set +x

exit 0
