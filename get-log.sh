#!/bin/bash
#Copyright (C) 2017 Christopher Towner
#
#This program is free software: you can redistribute it and/or modify
#it under the terms of the GNU General Public License as published by
#the Free Software Foundation, either version 3 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.
#
#You should have received a copy of the GNU General Public License

usage() { echo "Usage: $0 -b <boomi_account> -a <atom_id> -u <user>:<pass> [-d <date>]" 1>&2; exit 1; }

#parse variables
while getopts b:u:a:d: option; do
     case "${option}"
         in
         b) ACCT=${OPTARG};;
         a) ATOM=${OPTARG};;
         u) USER=${OPTARG};;
         d) DATE=${OPTARG};;
     esac
done

#defaults today's date if none provided
if [ -z "${DATE}" ]; then
    DATE=$(date +%Y-%m-%d)
fi

#check that account, atom and user passed in
if [ -z "${ACCT}" ] || [ -z "${ATOM}" ] || [ -z "${USER}" ]; then
    usage
fi

#setup request
API_URL='https://api.boomi.com/api/rest/v1/'${ACCT}'/AtomLog'
REQUEST='<AtomLog xmlns="http://api.platform.boomi.com/" atomId='\"$ATOM\"' logDate='\"$DATE\"' includeBin="true"/>'

#request download and parse url
LOG_URL=$(curl -s -u "${USER}" -d "${REQUEST}" "${API_URL}" | xmllint --xpath 'string(/*/@url)' -)

#create directory for atom logs if doesn't exist
mkdir -p ${ATOM}

#download file, retry until available
ZIP="${ATOM}/${DATE}.zip"
SIZE=0
until [ $SIZE -gt 0 ]; do
    curl -s -o ${ZIP} -u "${USER}" "${LOG_URL}"
    SIZE=$(wc -c < $ZIP)
done
