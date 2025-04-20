
module ConfigLMM
    module LMM
        class Nextcloud < Framework::Plugin

            USER = 'nextcloud'
            HOME_DIR = '/var/lib/nextcloud'
            PACKAGE_NAME = 'Nextcloud'

            def actionNextcloudBuild(id, target, state, context, options)
                Nginx.withConnection(local) do |nginxConnection|
                    nginxConnection.writeConfig(__dir__, 'Nextcloud', target, state, context, options)
                end
            end

            def actionNextcloudDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionNextcloudDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        PHP_FPM::deploy(linuxConnection, options)
                        linuxConnection.ensurePackage(PACKAGE_NAME, options)

                        Podman.createUser(USER, HOME_DIR, 'Nextcloud', linuxConnection, options)
                        linuxConnection.withUserShell(USER) do |shell|
                            shell.createDirs(options, '~/apps', '~/data')
                        end
                        linuxConnection.createDirs(options, '/var/log/php')
                        linuxConnection.makeAccessible(HOME_DIR, options)

                        webappsDir = nil
                        PHP_FPM.withConnection(linuxConnection) do |phpConnection|
                            webappsDir = phpConnection.webappsDir
                            phpConnection.enableExtension('imagick', options)
                        end

                        target['User'] = USER unless target['User']
                        target['Root'] = webappsDir + 'nextcloud'
                        dbPassword = configureDatabase(target, linuxConnection, context, options)

                        configDir = webappsDir + 'nextcloud/config/'
                        if !linuxConnection.filePresent?(configDir + 'config.php', options)
                            linuxConnection.fileWrite('/var/log/php/nextcloud.access.json', '', options)
                            linuxConnection.fileWrite('/var/log/php/nextcloud.errors.log', '', options)
                            linuxConnection.fileWrite('/var/log/php/nextcloud.mail.log', '', options)

                            linuxConnection.setUserGroup('/var/log/php/nextcloud.access.json', USER, USER, options)
                            linuxConnection.setUserGroup('/var/log/php/nextcloud.errors.log', USER, USER, options)
                            linuxConnection.setUserGroup('/var/log/php/nextcloud.mail.log', USER, USER, options)

                            linuxConnection.exec("chmod o-r /var/log/php/nextcloud.access.json /var/log/php/nextcloud.errors.log /var/log/php/nextcloud.mail.log", false, options)

                            linuxConnection.upload(__dir__ + '/autoconfig.php', configDir, options)

                            linuxConnection.fileReplace("#{configDir}autoconfig.php", "'dbuser' .*", "'dbuser' => '#{target['User']}',", options)
                            linuxConnection.fileReplace("#{configDir}autoconfig.php", "'dbpass' .*", "'dbpass' => '#{dbPassword}',", { **options, hide: true })

                            if target['Database']['HostName'] != 'localhost'
                                linuxConnection.fileReplace("#{configDir}autoconfig.php", "'dbhost' .*", "'dbhost' => '#{target['Database']['HostName']}',", options)
                            end

                            if target['Admin'].to_h.empty?
                                linuxConnection.fileReplace("#{configDir}autoconfig.php", "'adminlogin'", "//'adminlogin'", options)
                                linuxConnection.fileReplace("#{configDir}autoconfig.php", "'adminpass'", "//'adminpass'", options)
                            else
                                raise 'Admin.Name missing!' unless target['Admin']['Name']
                                linuxConnection.fileReplace("#{configDir}autoconfig.php", "'adminlogin' .*", "'adminlogin' => '#{target['Admin']['Name']}',", options)

                                adminPassword = context.secrets.load(target['SecretId'], 'ADMIN_PASSWORD')
                                if adminPassword.nil?
                                    adminPassword = SecureRandom.alphanumeric(20)
                                    context.secrets.store(target['SecretId'], 'ADMIN_PASSWORD', adminPassword)
                                    context.secrets.print("Nextcloud Admin '#{target['Admin']['Name']}' password", adminPassword)
                                end

                                linuxConnection.fileReplace("#{configDir}autoconfig.php", "'adminpass' .*", "'adminpass' => '#{adminPassword}',", { **options, hide: true })
                            end

                            linuxConnection.upload(__dir__ + '/config.php', configDir, options)
                            linuxConnection.fileReplace("#{configDir}config.php", "'instanceid' .*", "'instanceid' => '#{SecureRandom.alphanumeric(10)}',", options)

                            if target['Valkey'].to_h.empty?
                                linuxConnection.fileReplace("#{configDir}config.php", "'memcache.distributed'", "//'memcache.distributed'", options)
                                linuxConnection.fileReplace("#{configDir}config.php", "'memcache.locking'", "//'memcache.locking'", options)
                            else
                                if target['Valkey']['Host']
                                    linuxConnection.fileReplace("#{configDir}config.php", "'host' .*", "'host' => '#{target['Valkey']['Host']}',", options)
                                end
                                if target['Valkey']['SecretId']
                                    valkeyPassword = context.secrets.load(target['Valkey']['SecretId'], 'VALKEY_PASSWORD')
                                    linuxConnection.fileReplace("#{configDir}config.php", "'password' .*", "'password' => '#{valkeyPassword}',", { **options, hide: true })
                                end
                            end

                            linuxConnection.fileWrite("#{configDir}CAN_INSTALL", '', options)
                            linuxConnection.fileReplace("#{configDir}config.php", '/usr/share/webapps/', webappsDir, options)
                        end
                        linuxConnection.setUserGroup(configDir, USER, USER, options)
                        linuxConnection.setUserGroup('/var/lib/nextcloud', USER, USER, options)


                        name = 'nextcloud'
                        PHP_FPM.withConnection(linuxConnection) do |phpConnection|
                            linuxConnection.updateFile(phpConnection.configDir + name + '.conf', options, false, ';') do |configLines|
                                phpConnection.writeConfig(name, target, configLines)
                            end
                        end

                        linuxConnection.upload(__dir__ + '/nextcloudcron.service', '/etc/systemd/system/', options)
                        linuxConnection.upload(__dir__ + '/nextcloudcron.timer', '/etc/systemd/system/', options)
                        linuxConnection.fileReplace('/etc/systemd/system/nextcloudcron.service', '\$WEBAPPS/', webappsDir, options)

                        linuxConnection.reloadServiceManager(options)
                        linuxConnection.startService(PHP_FPM::PHPFPM_SERVICE, options)
                        linuxConnection.ensureServiceAutoStart('nextcloudcron.timer', options)
                        linuxConnection.startService('nextcloudcron.timer', options)

                        Nginx.withConnection(linuxConnection) do |nginxConnection|
                            nginxConnection.writeConfig(__dir__, 'Nextcloud', target, state, context, options)
                            nginxConnection.deployAllConfigs(target, activeState, context, options)
                        end
                    end
                end
            end

            def configureDatabase(target, linuxConnection, context, options)
                target['Database'] ||= {}

                password = context.secrets.load(target['SecretId'], 'DB_PASSWORD')
                if password.nil?
                    password = SecureRandom.alphanumeric(20)
                    context.secrets.store(target['SecretId'], 'DB_PASSWORD', password)
                end

                if !target['Database']['Type'] || target['Database']['Type'] == 'pgsql'
                    PostgreSQL.defaults(target['Database'])
                    PostgreSQL.withConnection(target['Database'], linuxConnection) do |postgresConnection|
                        postgresConnection.createUserAndDB(target['User'], password, options)
                    end
                end
                password
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Nextcloud, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        Nginx.withConnection(linuxConnection) do |nginxConnection|
                            nginxConnection.cleanupConfig('Nextcloud', context, options)
                            nginxConnection.reload(options)
                        end
                        linuxConnection.stopService('nextcloudcron.timer', options)

                        configDir = nil
                        webappsDir = nil
                        PHP_FPM.withConnection(linuxConnection) do |phpConnection|
                            configDir = phpConnection.configDir
                            webappsDir = phpConnection.webappsDir
                        end

                        linuxConnection.rm(configDir + 'nextcloud.conf', options[:dry])
                        linuxConnection.rm('/etc/systemd/system/nextcloudcron.service', options[:dry])
                        linuxConnection.rm('/etc/systemd/system/nextcloudcron.timer', options[:dry])
                        linuxConnection.reloadService(PHP_FPM::PHPFPM_SERVICE, options)
                        linuxConnection.removePackage(PACKAGE_NAME, options)
                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            linuxConnection.rm(webappsDir + 'nextcloud', options[:dry])
                            item['Config']['Database'] ||= {}
                            if !item['Config']['Database']['Type'] || item['Config']['Database']['Type'] == 'pgsql'
                                PostgreSQL.withConnection(item['Config']['Database'], linuxConnection) do |postgresConnection|
                                    postgresConnection.dropUserAndDB(USER, options)
                                end
                            end
                            linuxConnection.deleteUserAndGroup(USER, options)
                            linuxConnection.rm('/var/log/php/nextcloud.access.json', options[:dry])
                            linuxConnection.rm('/var/log/php/nextcloud.errors.log', options[:dry])
                            linuxConnection.rm('/var/log/php/nextcloud.mail.log', options[:dry])
                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end

        end
    end
end
