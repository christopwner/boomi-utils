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

# Utility script for downloading process (execution) logs from Dell Boomi.

usage() { echo "Usage: $0 -b <boomi_account> -u <user>:<pass> -e <exe_id> [-o <out_dir>] [-c <config>]" 1>&2; exit 1; }

#parse variables
while getopts b:u:e:o:c: option; do
    case "${option}"
        in
        b) acct=${OPTARG};;
        a) atom=${OPTARG};;
        e) exe_id=${OPTARG};;
	    o) path=${OPTARG};;
        c) . ${OPTARG};;
     esac
done

#default path to current dir
if [ -z "${path}" ]; then
    path=$(pwd)
fi

#check that account, atom and user passed in
if [ -z "${acct}" ] || [ -z "${atom}" ] || [ -z "${exe_id}" ]; then
    usage
fi

#make dir for logs
path="${path}/${exe_id}"
mkdir -p ${path}

#post request for process log
post_log_url='https://api.boomi.com/api/rest/v1/'${acct}'/ProcessLog'
post_log_req='<ProcessLog xmlns="http://api.platform.boomi.com/" executionId="'${exe_id}'" logLevel="ALL"/>'
response_code=$(curl -s -o "${path}/temp.url" -w "%{http_code}" -u "${user}" -d "${post_log_req}" "${post_log_url}")

#check response is ok
if [ "$response_code" -ne 202 ]; then
    curl -i -u "${user}" -d "${post_log_req}" "${post_log_url}"
    exit 1;
fi

#parse log url
log_url=$(xmllint --xpath 'string(/*/@url)' "${path}/temp.url")

#download file, retry until available
zip="${path}/temp.zip"
size=0
until [ $size -gt 0 ]; do
    curl -s -o ${zip} -u "${user}" "${log_url}"
    size=$(wc -c < $zip)
done

#unzip logs into temp dir
unzip -qo $zip -d ${path}

#cleanup zip/dl
rm -r ${path}/temp.zip ${path}/temp.url
