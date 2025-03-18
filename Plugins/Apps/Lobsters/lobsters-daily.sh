#!/bin/bash

err=0
report() {
  err=1
  echo -n "error at line ${BASH_LINENO[0]}, in call to "
  sed -n ${BASH_LINENO[0]}p $0
} >&2
trap report ERR

cd /srv/lobste.rs/http

if [ -f public/maintenance.html ];
then
  exit 0
fi

bundle exec rails daily_maintenance
bundle exec rails sitemap:refresh -s

find /srv/lobste.rs/http/tmp -type f -name 'rack%3A%3Aattack*' -mtime +2 -delete

exit $err
