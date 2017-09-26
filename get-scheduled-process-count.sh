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

# Utility script for reading if scheduled execution ran in past interval from Dell Boomi.
# See: http://help.boomi.com/atomsphere/GUID-1B3FC1BC-F10E-4C24-9D65-9CBB372B603A.html

usage() { echo "Usage: $0 -b <boomi_account> -p <process_id> -u <user>:<pass> [-i <interval>] [-o <out_dir>] [-c <config>]" 1>&2; exit 1; }

#parse variables
while getopts b:u:p:i:o:c: option; do
    case "${option}"
        in
        b) acct=${OPTARG};;
        p) proc=${OPTARG};;
        u) user=${OPTARG};;
        i) interval=${OPTARG};;
        o) path=${OPTARG};;
	    c) . ${OPTARG};;
     esac
done

#default to 10 minute interval if none provided
if [ -z "${interval}" ]; then
    interval=10
fi

#check that account, atom and user passed in
if [ -z "${acct}" ] || [ -z "${proc}" ] || [ -z "${user}" ]; then
    usage
fi

#query executions by process id
query_execution_url='https://api.boomi.com/api/rest/v1/'${acct}'/ExecutionRecord/query'
query_execution_request='
<QueryConfig xmlns="http://api.platform.boomi.com/">
    <QueryFilter>
        <expression operator="and" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="GroupingExpression"> 
            <nestedExpression operator="EQUALS" property="processId" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="SimpleExpression"> 
                <argument>'${proc}'</argument> 
            </nestedExpression> 
            <nestedExpression operator="GREATER_THAN_OR_EQUAL" property="executionTime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:type="SimpleExpression"> 
                <argument>'$(date -u -d "${interval} min ago" +%FT%TZ)'</argument>
            </nestedExpression>
        </expression>
    </QueryFilter>
</QueryConfig>'

#output number of results
curl -s -u "${user}" -d "${query_execution_request}" "${query_execution_url}" | xmllint --xpath "string(/*/@numberOfResults)" -
