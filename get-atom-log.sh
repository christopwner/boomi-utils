#!/bin/bash
#
# Copyright (C) 2017 Christopher Towner
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

usage() { echo "Usage: $0 -b <boomi_account> -a <atom_id> -u <user>:<pass> [-d <date>] [-c <config>]" 1>&2; exit 1; }

#parse variables
while getopts b:u:a:d:c: option; do
     case "${option}"
         in
         b) acct=${OPTARG};;
         a) atom=${OPTARG};;
         u) user=${OPTARG};;
         d) date=${OPTARG};;
	 c) . ${OPTARG};;
     esac
done

#defaults today's date if none provided
if [ -z "${date}" ]; then
    date=$(date +%F)
fi

#check that account, atom and user passed in
if [ -z "${acct}" ] || [ -z "${atom}" ] || [ -z "${user}" ]; then
    usage
fi

#setup request
api_url='https://api.boomi.com/api/rest/v1/'${acct}'/AtomLog'
request='<AtomLog xmlns="http://api.platform.boomi.com/" atomId='\"$atom\"' logDate='\"$date\"' includeBin="true"/>'

#request download and parse url
log_url=$(curl -s -u "${user}" -d "${request}" "${api_url}" | xmllint --xpath 'string(/*/@url)' -)

#create path for atom log if doesn't exist
path="${atom}/$(date -d $date +%Y)/$(date -d $date +%m)/$(date -d $date +%d)"
mkdir -p ${path}

#download file, retry until available
zip="${path}/temp.zip"
size=0
until [ $size -gt 0 ]; do
    curl -s -o ${zip} -u "${user}" "${log_url}"
    size=$(wc -c < $zip)
done
