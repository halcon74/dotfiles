#!/bin/bash

# Helper script for pushing to halcon-overlay
# Pushes a local hg (Mercurial) repository with different branches and bookmarks to a remote repository in the way compatible with hg-git
# The script uses the following Environment Variables: ( HALCONHG_DIR HALCONHG_REMOTE )
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

_branch="${1}"

source /usr/local/bin/mclass_utilities.sh

# Example file: installer_halconoverlay.conf.example
_conf_file='/usr/local/bin/installer_halconoverlay.conf'

HALCONHG_DIR=$(read_env_or_conf_var 'HALCONHG_DIR' "${_conf_file}")
HALCONHG_REMOTE=$(read_env_or_conf_var 'HALCONHG_REMOTE' "${_conf_file}")

if [[ -z "${HALCONHG_DIR}" ]]; then
	exit_err_1 'HALCONHG_DIR is not set'
fi
if [[ -z "${HALCONHG_REMOTE}" ]]; then
	exit_err_1 'HALCONHG_REMOTE is not set'
fi

if [[ ! -d "${HALCONHG_DIR}" ]]; then
	exit_err_1 'HALCONHG_DIR='"${HALCONHG_DIR}"': No such diectory'
fi

if [[ -z "${_branch}" ]]; then
	exit_err_1 'branch argument is not passed'
fi

set -x
pushd "${HALCONHG_DIR}"
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
LC_ALL=C hg push --verbose "${HALCONHG_REMOTE}"
popd
set +x

exit 0
