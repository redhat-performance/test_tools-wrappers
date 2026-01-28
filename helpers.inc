#
# Copyright (C) 2026  David Valin dvalin@redhat.com
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
#

#
# Standard time stamp for outputting to the csv files
#
retrieve_time_stamp()
{
	date -u "+%Y-%m-%dT%H:%M:%SZ"
}

#
# Build the string and filter out all , in the results values
#
build_data_string()
{
	out_string=""
	separ=""
	for arg in "$@"; do
		append=`echo $arg | sed "s/,//g"`
		out_string=${out_string}${separ}${append}
		separ=","
	done
	echo $out_string
}

test_start_time=$(retrieve_time_stamp)
export test_start
