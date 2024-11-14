
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
                        linuxConnection.fileWrite('/var/log/php/nextcloud.access.json', '', options)
                        linuxConnection.fileWrite('/var/log/php/nextcloud.errors.log', '', options)
                        linuxConnection.fileWrite('/var/log/php/nextcloud.mail.log', '', options)

                        linuxConnection.setUserGroup('/var/log/php/nextcloud.access.json', USER, USER, options)
                        linuxConnection.setUserGroup('/var/log/php/nextcloud.errors.log', USER, USER, options)
                        linuxConnection.setUserGroup('/var/log/php/nextcloud.mail.log', USER, USER, options)

                        linuxConnection.exec("chmod o-r /var/log/php/nextcloud.access.json /var/log/php/nextcloud.errors.log /var/log/php/nextcloud.mail.log", false, options)

                        distroInfo = linuxConnection.distroInfo
                        webappsDir = PHP_FPM::webappsDir(distroInfo)
                        configDir = webappsDir + 'nextcloud/config/'
                        if !linuxConnection.filePresent?(configDir + 'config.php', options)
                            linuxConnection.upload(__dir__ + '/config.php', configDir, options)
                            linuxConnection.fileReplace("#{configDir}config.php", "'instanceid' .*", "'instanceid' => '#{SecureRandom.alphanumeric(10)}',", options)
                            linuxConnection.fileWrite("#{configDir}CAN_INSTALL", '', options)
                            linuxConnection.fileReplace("#{configDir}config.php", '/usr/share/webapps/', webappsDir, options)
                        end
                        linuxConnection.setUserGroup(configDir, USER, USER, options)
                        linuxConnection.setUserGroup('/var/lib/nextcloud', USER, USER, options)

                        target['Database'] ||= {}
                        if !target['Database']['Type'] || target['Database']['Type'] == 'pgsql'
                            PostgreSQL.withConnection(target['Database'], linuxConnection) do |postgresConnection|
                                postgresConnection.createUserAndDB(USER, nil, options)
                            end
                        end

                        target['User'] = USER unless target['User']
                        target['Root'] = webappsDir + 'nextcloud'
                        name = 'nextcloud'
                        linuxConnection.updateFile(PHP_FPM.configDir(distroInfo) + name + '.conf', options, false, ';') do |configLines|
                            PHP_FPM.writeConfig(name, target, distroInfo, configLines)
                        end

                        linuxConnection.startService(PHP_FPM::PHPFPM_SERVICE, options)

                        Nginx.withConnection(linuxConnection) do |nginxConnection|
                            nginxConnection.writeConfig(__dir__, 'Nextcloud', target, state, context, options)
                            nginxConnection.deployAllConfigs(target, activeState, context, options)
                        end
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Nextcloud, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        Nginx.withConnection(linuxConnection) do |nginxConnection|
                            nginxConnection.cleanupConfig('Nextcloud', context, options)
                            nginxConnection.reload(options)
                        end
                        linuxConnection.rm(PHP_FPM.configDir(linuxConnection.distroInfo) + 'nextcloud.conf', options[:dry])
                        linuxConnection.reloadService(PHP_FPM::PHPFPM_SERVICE, options)
                        linuxConnection.removePackage(PACKAGE_NAME, options)
                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            linuxConnection.rm(PHP_FPM::webappsDir(linuxConnection.distroInfo) + 'nextcloud', options[:dry])
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
