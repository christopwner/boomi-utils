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

# Utility script for reading execution feed from Dell Boomi.

usage() { echo "Usage: $0 -b <boomi_account> -u <user>:<pass> [-o <out_dir>] [-i <interval>] [-c <config>]" 1>&2; exit 1; }

#parse variables
while getopts b:u:o:i:c: option; do
    case "${option}"
        in
        b) acct=${OPTARG};;
        u) user=${OPTARG};;
        o) path=${OPTARG};;
        i) interval=${OPTARG};;
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
if [ -z "${acct}" ] || [ -z "${user}" ]; then
    usage
fi

#download feed
feed=$path/exe-feed.xml
curl -s -o ${feed} https://platform.boomi.com/account/${acct}/feed/rss-2.0

#hardcoded guid for exe type category in boomi feed
exe_type='b3dc32d4-0dbe-43a7-9a82-9f15fde812ea'

#get item count in feed and iterate
item_count=$(xmllint --xpath 'count(/rss/channel/item)' ${feed})
for (( i = 1; i <= $item_count; i++)); do
    
    #check that item_type equal to exe_type
    item_type=$(xmllint --xpath 'string(/rss/channel/item['$i']/category[3])' ${feed})
    if [ $item_type != $exe_type ]; then
        echo "Unhandled type:" $item_type
        continue;
    fi   

    #get date and id from item
    exe_date=$(xmllint --xpath 'string(/rss/channel/item['$i']/pubDate)' ${feed})
    exe_id=$(xmllint --xpath 'string(/rss/channel/item['$i']/guid)' ${feed} |sed 's/^.*executionId=//')
    echo $exe_date - $exe_id

done

#cleanup
#rm ${feed}
