#!/bin/bash

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
