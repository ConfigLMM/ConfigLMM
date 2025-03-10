
module ConfigLMM
    module LMM
        class Answer < Framework::Plugin

            USER = 'answer'
            HOME_DIR = '/var/lib/answer'
            INSTALL_PATH = '/usr/local/bin/'
            GITHUB_REPO_ID = 'apache/answer'
            PORT = 18700

            def actionAnswerDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        answerUser = USER
                        answerHomeDir = HOME_DIR
                        answerPort = PORT
                        if target.key?('Instance')
                            answerUser += target['Instance'].to_s
                            answerHomeDir += target['Instance'].to_s
                            answerPort += target['Instance'].to_i
                        end

                        prepareSettings(target, answerUser, answerUser)

                        linuxConnection.createServiceUser(answerUser, answerHomeDir, 'Apache Answer', options)

                        if !linuxConnection.filePresent?(INSTALL_PATH + 'answer')
                            releases = GitHub::getReleases(GITHUB_REPO_ID, logger, context, options)
                            asset = GitHub::getReleaseAsset('apache-answer-*-bin-linux-amd64.tar.gz', releases)
                            linuxConnection.exec("curl --silent --location --output /tmp/answer.tar.gz #{asset['browser_download_url']}", false, options)
                            linuxConnection.exec("mkdir /tmp/answer", false, options)
                            linuxConnection.exec("tar --extract --strip-components=1 --directory /tmp/answer --file /tmp/answer.tar.gz", false, options)
                            linuxConnection.exec("cp /tmp/answer/answer #{INSTALL_PATH}", false, options)
                            linuxConnection.exec("rm -rf /tmp/answer /tmp/answer.tar.gz", false, options)
                        end

                        db = configureDatabase(target, linuxConnection, options)

                        if !linuxConnection.filePresent?(answerHomeDir + '/data/conf/config.yaml')

                            target['Site'] ||= {}
                            target['Site']['Language'] = 'en-US' unless target['Site']['Language']
                            target['Site']['Name'] = 'Q&A' unless target['Site']['Name']

                            raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']
                            raise Framework::PluginProcessError.new('Site.ContactEMail field must be set!') unless target['Site']['ContactEMail']
                            raise Framework::PluginProcessError.new('Admin.Username field must be set!') unless target['Admin']['Username']
                            raise Framework::PluginProcessError.new('Admin.EMail field must be set!') unless target['Admin']['EMail']

                            linuxConnection.withUserShell(answerUser) do |shell|

                                adminPassword = SecureRandom.urlsafe_base64(20)

                                installEnv = "AUTO_INSTALL=true SITE_ADDR=127.0.0.1:#{answerPort} INSTALL_PORT=#{answerPort+1} "
                                installEnv += "DB_TYPE=#{db['Type']} DB_HOST=#{db['HostName']} DB_NAME=#{db['Name']} DB_USERNAME=#{db['User']} DB_PASSWORD=unused "
                                installEnv += " LANGUAGE=#{target['Site']['Language']} SITE_NAME='#{target['Site']['Name']}' SITE_URL=https://#{target['Domain']} CONTACT_EMAIL=#{target['Site']['ContactEMail']} "
                                installEnv += " ADMIN_NAME=#{target['Admin']['Username'].downcase} ADMIN_EMAIL=#{target['Admin']['EMail']} ADMIN_PASSWORD=#{adminPassword} "
                                shell.exec(installEnv + INSTALL_PATH + "answer init --data-path #{answerHomeDir}/data", false, { **options, hide: true })

                                prompt.say("Answer Administrator #{target['Admin']['EMail']} password: #{adminPassword}", :color => :magenta)
                            end

                            linuxConnection.fileReplace(answerHomeDir + '/data/conf/config.yaml', 'show: true', 'show: false', options)
                        end

                        linuxConnection.upload(__dir__ + '/answer@.service', Systemd::SYSTEMD_CONFIG_PATH, options)
                        linuxConnection.reloadServiceManager(options)
                        linuxConnection.ensureServiceAutoStart("answer@#{answerUser}.service", options)
                        linuxConnection.startService("answer@#{answerUser}.service", options)
                    end
                end
            end

            def prepareSettings(target, userName, dbName)
                target['Database'] ||= {}
                target['Database']['Type'] = 'postgres' unless target['Database']['Type']
                target['Database']['HostName'] = '/run/postgresql' unless target['Database']['HostName']
                target['Database']['Port'] = 5432 unless target['Database']['Port']
                target['Database']['Name'] = userName unless target['Database']['Name']
                target['Database']['User'] = dbName unless target['Database']['User']

                raise 'Using this DB type is not implemented!' if target['Database']['Type'] != 'postgres'
            end

            def configureDatabase(target, linuxConnection, options)
                dbSettings = {}
                dbSettings['HostName'] = target['Database']['HostName']
                dbSettings['Port'] = target['Database']['Port']
                PostgreSQL.withConnection(dbSettings, linuxConnection) do |postgresConnection|
                    password = SecureRandom.alphanumeric(20)
                    postgresConnection.createUserAndDB(target['Database']['Name'], password, options)
                end
                target['Database']
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Answer, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        answerUser = USER
                        answerHomeDir = HOME_DIR
                        deleteAnswer = true
                        if target.key?('Instance')
                            answerUser += target['Instance'].to_s
                            answerHomeDir += target['Instance'].to_s
                            deleteAnswer = false
                        end

                        linuxConnection.stopService("answer@#{answerUser}.service", options)
                        linuxConnection.disableService("answer@#{answerUser}.service", options)

                        if deleteAnswer
                            linuxConnection.rm(Systemd::SYSTEMD_CONFIG_PATH + 'answer@.service', options[:dry])
                            linuxConnection.rm(INSTALL_PATH + 'answer', options[:dry])
                        end

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            linuxConnection.deleteUserAndGroup(answerUser, options)
                            linuxConnection.rm(answerHomeDir, options[:dry])
                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end
        end
    end
end
