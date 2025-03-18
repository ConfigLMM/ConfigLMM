#!/usr/bin/sh

set -o errexit
set -o nounset

cmd="/lobsters/bin/rails"

if [ $# -gt 0 ]; then
    if [ "$1" = "cron" ]; then
        shift
        cmd="/usr/local/bin/supercronic /etc/crontab"
    elif [ "$1" = "server" ]; then
        status=0
        cmp --quiet "/lobsters/id.txt" "/srv/lobsters/id.txt" || status=$?
        if [ $status -ne 0 ]; then
            rm -rf /srv/lobsters/*
            mkdir -p /srv/lobsters/public
            cp -R /lobsters/public_source/* /srv/lobsters/public/
            cp -R /lobsters/public_source/.* /srv/lobsters/public/
            cp "/lobsters/id.txt" "/srv/lobsters/"
        fi

        if [ ! -f "/config/credentials.yml.enc" ]; then
            bundle exec /lobsters/script/generateCredentials.rb
        fi
        /lobsters/bin/rails db:prepare
    fi
fi

exec $cmd "$@"
