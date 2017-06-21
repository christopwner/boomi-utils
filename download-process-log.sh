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

# Utility script for downloading atom logs from Dell Boomi.
# See: http://help.boomi.com/atomsphere/GUID-C436EF06-CF5F-46FC-8049-B7705FA93D1D.html
# See: http://help.boomi.com/atomsphere/GUID-1B3FC1BC-F10E-4C24-9D65-9CBB372B603A.html

usage() { echo "Usage: $0 -b <boomi_account> -a <atom_id> -u <user>:<pass> [-i <interval>] [-o <out_dir>] [-c <config>]" 1>&2; exit 1; }

#parse variables
while getopts b:u:a:i:o:c: option; do
    case "${option}"
        in
        b) acct=${OPTARG};;
        a) atom=${OPTARG};;
        u) user=${OPTARG};;
        i) interval=${OPTARG};;
	    o) path=${OPTARG};;
	    c) . ${OPTARG};;
     esac
done

#default to 1 minute interval if none provided
if [ -z "${interval}" ]; then
    interval=1
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
mkdir -p ${path}

#query for execution id(s)
query_execution_url='https://api.boomi.com/api/rest/v1/'${acct}'/ExecutionRecord/query'
query_execution_request='
<QueryConfig xmlns="http://api.platform.boomi.com/">
    <QueryFilter>
        <expression operator="EQUALS" property="atomId" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="SimpleExpression">
            <argument>'${atom}'</argument>
        </expression>
        <expression operator="BETWEEN" property="executionTime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="SimpleExpression">
            <argument>'$(date -d "${interval} min ago" +%FT%TZ)'</argument>
            <argument>'$(date +%FT%TZ)'</argument>
        </expression>
    </QueryFilter>
</QueryConfig>'
response_code=$(curl -s -o "${path}/temp.xml" -w "%{http_code}" -u "${user}" -d "${query_execution_request}" "${query_execution_url}")

#check id count (if 100 could be paged which is unhandled)
exe_count=$(xmllint --xpath "string(/*/@numberOfResults)" "${path}/temp.xml")
if [ "$exe_count" -gt 99 ]; then
    echo "Too many executions! Try lowering your interval or modifying the script to filter results further"
    exit 1;
fi

#interate execution ids
for (( i = 1; i <= $exe_count; i++)); do
    #get exe id and make dir for logs
    exe_id=$(xmllint --xpath "string(/*/*["$i"]/*[local-name()='executionId'])" "${path}/temp.xml")
    log_path="${path}/${exe_id}"
    mkdir -p ${log_path}

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
    unzip -qo $zip -d ${path}/temp

    #rsync logs to proper path
    rsync ${path}/temp/* ${log_path}

    #cleanup zip/dl
    rm -r ${path}/temp ${path}/temp.zip ${path}/temp.url
done

#cleanup exe ids
rm ${path}/temp.xml
