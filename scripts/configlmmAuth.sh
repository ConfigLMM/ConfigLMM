#!/usr/bin/sh

if [ "$#" -lt 3 ]; then
    echo "Usage $0 <cmd> <key file> <config file>"
    exit 1
fi

cmd="$1"
keysFile="$2"
shift
shift

if [ ! -f "$keysFile" ]; then
    echo "Provided key file '$keysFile' doesn't exist!"
    exit 1
fi

if [[ ${keysFile:0:2} != "./" ]]; then
    keysFile="./$keysFile"
fi

if [ "$(grep -v '^#' "$keysFile" | wc -l)" -gt 0 ]; then
    export $(grep -v '^#' "$keysFile" | xargs -d '\n')
fi

echo "Deploying..."

configlmm $cmd "$@"
