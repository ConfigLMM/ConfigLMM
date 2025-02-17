<?php

$CONFIG = [
    'instanceid' => '',
    'datadirectory' => '/var/lib/nextcloud/data/',
    'apps_paths' => [
        [
            'path'=> '/usr/share/webapps/nextcloud/apps',
            'url' => '/apps',
            'writable' => false,
        ],
        [
            'path'=> '/var/lib/nextcloud/apps',
            'url' => '/wapps',
            'writable' => true,
        ],
    ],
    'maintenance_window_start' => 2,
    //'memcache.local' => '\OC\Memcache\APCu',
    'memcache.distributed' => '\OC\Memcache\Redis',
    'memcache.locking' => '\OC\Memcache\Redis',
    'redis' => [
        'host' => '127.0.0.1',
        'port' => 6379,
        'password' => '',
    ],
];
