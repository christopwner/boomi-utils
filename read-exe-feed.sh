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

# Utility script for reading executions in RSS feed from Dell Boomi.

usage() { echo "Usage: $0 -b <boomi_account> -u <user>:<pass> [-o <out_dir>] [-c <config>]" 1>&2; exit 1; }

#parse variables
while getopts b:u:o:c: option; do
    case "${option}"
        in
        b) acct=${OPTARG};;
        u) user=${OPTARG};;
        o) path=${OPTARG};;
        c) . ${OPTARG};;
     esac
done

#default path to current dir, create if doesnt exist
if [ -z "${path}" ]; then
    path=$(pwd)
fi

#check that account, atom and user passed in
if [ -z "${acct}" ] || [ -z "${user}" ]; then
    usage
fi

#create log path if doesnt exists
mkdir -p $path

#download feed
feed=$path/exe-feed.xml
curl -s -o ${feed} https://platform.boomi.com/account/${acct}/feed/rss-2.0

#read last pos if exists
feed_pos=$path/exe-feed.pos
if [ -f "${feed_pos}" ]; then
    last_exe_id=$(cat $feed_pos)
fi

#hardcoded guid for exe type category in boomi feed
exe_type='b3dc32d4-0dbe-43a7-9a82-9f15fde812ea'

#get item count in feed and iterate
item_count=$(xmllint --xpath 'count(/rss/channel/item)' ${feed})
for (( i = 1; i <= $item_count; i++)); do
    
    #check that item_type equal to exe_type
    item_type=$(xmllint --xpath 'string(/rss/channel/item['$i']/category[3])' ${feed})
    if [ "$item_type" != "$exe_type" ]; then
        #uncomment for debugging unhandled types
        #xmllint --xpath '/rss/channel/item['$i']' ${feed}; echo
        continue;
    fi   

    #get date and id from item
    exe_date=$(xmllint --xpath 'string(/rss/channel/item['$i']/pubDate)' ${feed})
    exe_id=$(xmllint --xpath 'string(/rss/channel/item['$i']/guid)' ${feed} |sed 's/^.*executionId=//')

    #if id last in pos (already processed), break from loop
    if [ "$exe_id" == "$last_exe_id" ]; then
        break;
    fi

    #if first in list, store temp to overwrite pos file
    if [ -z "$first_exe_id" ]; then 
        first_exe_id=${exe_id}
    fi

    #retrieve and log execution
    echo $exe_date - $exe_id
    #$(dirname "$0")/log-exe.sh -b ${acct} -u ${user} -e ${exe_id} -o ${path}
done

#store first executed in pos for subsequent runs
if [ -n "$first_exe_id" ]; then
    echo "$first_exe_id" > $feed_pos
fi

#cleanup
rm ${feed}
