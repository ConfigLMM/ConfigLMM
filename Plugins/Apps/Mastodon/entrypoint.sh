#!/usr/bin/sh

set -o errexit
set -o nounset

cmd="/usr/bin/tini"

if [ $# -gt 0 ] && [ "$1" = "server" ]; then
    bin/rails db:prepare
    bin/rails configlmm:setup
    unset ADMIN_PASSWORD

    exec $cmd -- bundle exec puma -C config/puma.rb
else
    exec $cmd -- "$@"
fi
