#!/usr/bin/sh

if [ "$#" -ne 3 ]; then
    echo "Usage $0 <cmd> <key file> <config file>"
    exit 1
fi

cmd="$1"
keysFile="$2"
configFile="$3"

if [ ! -f "$keysFile" ]; then
    echo "Provided key file '$keysFile' doesn't exist!"
    exit 1
fi

if [[ ${keysFile:0:2} != "./" ]]; then
    keysFile="./$keysFile"
fi

export $(grep -v '^#' "$keysFile" | xargs -d '\n')

echo "Deploying..."

ruby configlmm $cmd $configFile

