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
    ]
];
