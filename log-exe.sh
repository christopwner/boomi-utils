#!/bin/bash

# Copyright (C) 2018 Christopher Diaz
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

# Utility script for logging process (execution) logs from Dell Boomi with Fluentd.


usage() { echo "Usage: $0 -b <boomi_account> -u <user>:<pass> -e <exe_id> [-o </home/chris/boomi-utils/records>] [-c </home/chris/boomi-utils>]" 1>&2; exit 1; }

#parse variables
while getopts b:u:e:o:c: option; do
    case "${option}"
        in
        b) acct=${OPTARG};;
        u) user=${OPTARG};;
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
if [ -z "${acct}" ] || [ -z "${user}" ] || [ -z "${exe_id}" ]; then
    usage
fi

#make dir for logs
path="${path}/${exe_id}"
mkdir -p ${path}

#request additional info about execution
query_url='https://api.boomi.com/api/rest/v1/'${acct}'/ExecutionRecord/query'
query_req='<QueryConfig xmlns="http://api.platform.boomi.com/"><QueryFilter><expression operator="EQUALS" property="executionId" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="SimpleExpression"><argument>'${exe_id}'</argument></expression></QueryFilter></QueryConfig>'

response_code=$(curl -s -o "${path}/temp.info" -w "%{http_code}" -u "${user}" -d "${query_req}" "${query_url}")


#check response is ok
if [ "$response_code" -ne 200 ]; then
    echo "Unable to query exe: ${exe_id}"
    exit 1;
fi

#parse addition info
process_name=$(xmllint --xpath "string(//*[local-name()='processName'])" ${path}/temp.info)

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
attempts=0
until [ "$size" -gt 0 ]; do
    curl -s -o ${zip} -u "${user}" "${log_url}"
    size=$(wc -c < $zip)
    attempts=$((attempts+1))

	#if unable to download, writes entry to backfill.pos to try again later
    if [ "$attempts" -gt 60 ]; then
        echo "Too many attempts for" ${log_url}
		echo "$exe_id" >> ${backfill_pos}

		exit 1;
    fi
done

#unzip logs into temp dir
unzip -qo $zip -d ${path}

#insert addition info into logs and pipe to fluent-cat
. $HOME/.profile; sed -e "s/^/${process_name} /" ${path}/*.log | /usr/local/bin/fluent-cat -f none debug.boomi

#cleanup zip/dl
rm -r ${path}
