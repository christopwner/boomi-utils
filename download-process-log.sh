#!/bin/bash

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

# Utility script for downloading process logs from Dell Boomi.
# See: http://help.boomi.com/atomsphere/GUID-C436EF06-CF5F-46FC-8049-B7705FA93D1D.html

usage() { echo "Usage: $0 -b <boomi_account> -a <atom_id> -u <user>:<pass> [-d <date>] [-o <out_dir>] [-c <config>]" 1>&2; exit 1; }

#parse variables
while getopts b:u:a:d:o:c: option; do
     case "${option}"
         in
         b) acct=${OPTARG};;
         a) atom=${OPTARG};;
         u) user=${OPTARG};;
         d) date=${OPTARG};;
	 o) path=${OPTARG};;
	 c) . ${OPTARG};;
     esac
done

#defaults today's date if none provided
if [ -z "${date}" ]; then
    date=$(date +%F)
fi

#default path to current dir
if [ -z "${path}" ]; then
    path=$(pwd)
fi

#check that account, atom and user passed in
if [ -z "${acct}" ] || [ -z "${atom}" ] || [ -z "${user}" ]; then
    usage
fi

#create path for atom logs if doesn't exist
path="${path}/${atom}"
log_path="${path}/$(date -d $date +%Y)/$(date -d $date +%m)/$(date -d $date +%d)"
mkdir -p ${log_path}

#setup request
api_url='https://api.boomi.com/api/rest/v1/'${acct}'/ProcessLog'
request='<ProcessLog xmlns="http://api.platform.boomi.com/" executionId="execution-'$atom'-'$(date -d $date +%Y.%m.%d)'" logLevel="ALL"/>'

echo $api_url
echo $request

#request download and parse response
response_code=$(curl -s -o "${path}/temp.url" -w "%{http_code}" -u "${user}" -d "${request}" "${api_url}")

#check code
if [ "$response_code" -ne 202 ]; then
    curl -i -u "${user}" -d "${request}" "${api_url}"
    exit 1;
fi

#parse log url
log_url=$(cat "${path}/temp.url" | xmllint --xpath 'string(/*/@url)' -)

#download file, retry until available
zip="${path}/temp.zip"
size=0
until [ $size -gt 0 ]; do
    curl -s -o ${zip} -u "${user}" "${log_url}"
    size=$(wc -c < $zip)
done

#unzip logs into temp dir
unzip -qo $zip -d ${path}/temp

#rsync logs to proper path
rsync ${path}/temp/* ${log_path}

#cleanup
rm -r ${path}/temp ${path}/temp.zip ${path}/temp.url
