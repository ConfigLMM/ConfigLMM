

module ConfigLMM
    module LMM
        class Lobsters < Framework::Plugin

            USER = 'lobsters'
            HOME_DIR = '/var/lib/lobsters'
            GIT_REPO = 'https://github.com/lobsters/lobsters.git'
            IMAGE_ID = 'ConfigLM.moe/lobsters:master'

            def actionLobstersBuild(id, target, activeState, context, options)
                buildContainer(id, target, options)
            end

            def buildContainer(id, target, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']
                Linux.withConnection(local) do |localLinux|
                    begin
                        localLinux.ensurePackages(['git', 'Podman'], options) unless localLinux.hasBinaries?(['git', 'podman'], options)
                    rescue RuntimeError => error
                        prompt.say(error, :color => :red)
                    end
                    lobstersDir = File.expand_path(REPOS_CACHE + '/lobsters')
                    if !File.exist?(lobstersDir)
                        localLinux.createDirs(options, File.expand_path(REPOS_CACHE))
                        gitRepo = GIT_REPO
                        gitRepo = target['Repository'] if target['Repository']
                        localLinux.exec("cd #{REPOS_CACHE} && git clone --quiet #{gitRepo} lobsters", false, options)
                    else
                        localLinux.exec("cd #{lobstersDir} && git checkout . --quiet && git pull --quiet", false, options)
                    end
                    localLinux.exec("cd #{lobstersDir} && git checkout . --quiet", false, options)

                    if !IO::Connection.cmdSuccess?("podman image exists #{IMAGE_ID}")
                        # if you see error like "newuidmap 5227 0 1000 1 1 100000 65536: newuidmap: write to uid_map failed: Operation not permitted"
                        # then for LXC you need to set idmap like:
                        # LXC:
                        #     - idmap: u 0 100000 165536
                        #     - idmap: g 0 100000 165536
                        localLinux.upload(__dir__ + '/entrypoint.sh', lobstersDir, options)
                        localLinux.upload(__dir__ + '/Containerfile', lobstersDir, options)
                        localLinux.upload(__dir__ + '/crontab', lobstersDir, options)
                        localLinux.upload(__dir__ + '/puma.rb', lobstersDir + '/config/', options)
                        localLinux.upload(__dir__ + '/database.yml', lobstersDir + '/config/', options)
                        localLinux.upload(__dir__ + '/lobsters-cron.sh', lobstersDir + '/script/', options)
                        localLinux.upload(__dir__ + '/lobsters-daily.sh', lobstersDir + '/script/', options)
                        localLinux.upload(__dir__ + '/generateCredentials.rb', lobstersDir + '/script/', options)

                        localLinux.exec("cd #{lobstersDir} && git rev-parse HEAD > id.txt", false, options)

                        localLinux.exec("sed -i 's|lobste\\.rs|#{target['Domain']}|' #{lobstersDir}/config/application.rb #{lobstersDir}/config/sitemap.rb #{lobstersDir}/public/opensearch.xml", false, options)
                        localLinux.exec("sed -i 's|lobste\\.rs|#{target['Domain']}|' #{lobstersDir}/app/models/comment.rb #{lobstersDir}/app/controllers/keybase_proofs_controller.rb", false, options)

                        localLinux.exec("sed -i 's|email: \"inactive-user@example.com\"|email: \"inactive-user@#{target['Domain']}\"|' #{lobstersDir}/db/seeds.rb", false, options)

                        if target['Admin'].to_h['Username']
                            localLinux.exec("sed -i 's|username: \"test\"|username: \"#{target['Admin']['Username']}\"|' #{lobstersDir}/db/seeds.rb", false, options)
                        end

                        if target['Admin'].to_h['EMail']
                            localLinux.exec("sed -i 's|email: \"test@example.com\"|email: \"#{target['Admin']['EMail']}\"|' #{lobstersDir}/db/seeds.rb", false, options)
                        end

                        adminPassword = SecureRandom.alphanumeric(20)
                        localLinux.exec(" sed -i 's|password: \"test\"|password: \"#{adminPassword}\"|' #{lobstersDir}/db/seeds.rb", false, { **options, hide: true })
                        localLinux.exec(" sed -i 's|password_confirmation: \"test\"|password_confirmation: \"#{adminPassword}\"|' #{lobstersDir}/db/seeds.rb", false, { **options, hide: true })

                        #localLinux.fileReplace("#{REPOS_CACHE}/lobsters/Dockerfile.dev", /COPY Gemfile.*/, 'COPY . ./',  options)
                        rubyVersion = localLinux.fileRead("#{REPOS_CACHE}/lobsters/.ruby-version", options).strip
                        localLinux.exec("cd #{REPOS_CACHE}/lobsters && podman build --tag=#{IMAGE_ID} --build-arg RUBY_VERSION=#{rubyVersion} --file Containerfile .", false, options)
                    end
                end
            end

            def actionLobstersDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                target['Database'] ||= {}
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        dbPassword = self.configureMariaDB(target['Database'], activeState, linuxConnection, options)

                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'Lobsters', linuxConnection, options)

                        cmd = IO::SSH.cmd(target['Location'])
                        local.exec("podman image save #{IMAGE_ID} | #{cmd} 'cat > #{HOME_DIR}/lobsters.tar'", false, options)

                        linuxConnection.withUserShell(USER) do |shell|
                            shell.createDirs(options, '~/config', '~/logs', '~/cache', '~/storage', '~/queue', '~/tmp')
                            Podman.loadImage(shell, 'lobsters.tar', options)
                        end

                        linuxConnection.exec("rm -f #{HOME_DIR}/lobsters.tar", false, options)

                        linuxConnection.createDirs(options, '/srv/lobsters')
                        linuxConnection.setUserGroup('/srv/lobsters', USER, USER, options)

                        path = Podman.containersPath(HOME_DIR)

                        linuxConnection.fileWrite(path + '/Lobsters.env', 'RAILS_ENV=production', options)
                        if target['SMTP'] && target['SMTP']['Host']
                            linuxConnection.fileAppend(path + '/Lobsters.env', 'SMTP_HOST=' + target['SMTP']['Host'], options)
                            if target['SMTP']['Port']
                                linuxConnection.fileAppend(path + '/Lobsters.env', 'SMTP_PORT=' + target['SMTP']['Port'].to_s, options)
                            end
                            if target['SMTP']['Username']
                                linuxConnection.fileAppend(path + '/Lobsters.env', 'SMTP_USERNAME=' + target['SMTP']['Username'], options)
                            end
                            if target['SMTP']['SecretId']
                                smtpPassword = context.secrets.load(target['SMTP']['SecretId'], target['SMTP']['Username'].upcase + '_PASSWORD')
                                linuxConnection.fileAppend(path + '/Lobsters.env', 'SMTP_PASSWORD=' + smtpPassword.to_s, { **options, hide: true })
                            end
                            if target['SMTP']['TLS'] || target['SMTP']['Port'].to_s == '465'
                                linuxConnection.fileAppend(path + '/Lobsters.env', 'SMTP_TLS=true', options)
                            end
                        else
                            linuxConnection.fileAppend(path + '/Lobsters.env', 'SMTP_HOST=10.0.2.2', options)
                        end
                        linuxConnection.fileAppend(path + '/Lobsters.env', 'SMTP_STARTTLS_AUTO=true', options)

                        linuxConnection.exec("chown #{USER}:#{USER} #{path}/Lobsters.env", false, options)
                        linuxConnection.exec("chmod 600 #{path}/Lobsters.env", false, options)

                        linuxConnection.upload(__dir__ + '/database.yml', HOME_DIR + '/config/', options)

                        if target['Database'] && target['Database']['HostName'] && target['Database']['HostName'] != 'localhost'
                            linuxConnection.fileReplace(HOME_DIR + '/config/database.yml', '10.0.2.2', target['Database']['HostName'], options)
                        end
                        linuxConnection.exec("sed -i 's|password:.*|password: #{dbPassword}|' #{HOME_DIR}/config/database.yml", false, options)

                        linuxConnection.upload(__dir__ + '/Lobsters.container', path, options)
                        linuxConnection.upload(__dir__ + '/Lobsters-Tasks.container', path, options)

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'Lobsters', options)
                        linuxConnection.restartUserService(USER, 'Lobsters-Tasks', options)

                        Nginx.withConnection(linuxConnection) do |nginxConnection|
                            nginxConnection.writeConfig(__dir__, 'Lobsters', target, state, context, options)
                            nginxConnection.deployAllConfigs(target, activeState, context, options)
                        end
                    end
                end
            end

            def configureMariaDB(settings, activeState, linuxConnection, options)
                password = SecureRandom.alphanumeric(20)
                MariaDB.withConnection(settings, linuxConnection) do |mariaConnection|
                    mariaConnection.createUserAndDB(USER, password, nil, options)
                end
                password
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Lobsters, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        Nginx.withConnection(linuxConnection) do |nginxConnection|
                            nginxConnection.cleanupConfig('Lobsters', context, options)
                            nginxConnection.reload(options)
                        end

                        linuxConnection.stopUserService(USER, 'Lobsters-Tasks', options)
                        linuxConnection.stopUserService(USER, 'Lobsters', options)

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.rm(path + 'Lobsters.container', options[:dry])
                        linuxConnection.rm(path + 'Lobsters-Tasks.container', options[:dry])
                        linuxConnection.rm('/srv/lobsters', options[:dry])

                        linuxConnection.withUserShell(USER) do |shell|
                            Podman.removeImage(shell, IMAGE_ID, options)
                        end

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            item['Config']['Database'] ||= {}
                            MariaDB.withConnection(item['Config']['Database'], linuxConnection) do |connectionDB|
                                connectionDB.dropDB(USER, options)
                            end
                            linuxConnection.deleteUserAndGroup(USER, options)
                            linuxConnection.rm(HOME_DIR, options[:dry])

                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end

        end
    end
end
