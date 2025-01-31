
module ConfigLMM
    module LMM
        class ERPNext < Framework::Plugin

            USER = 'erpnext'
            HOME_DIR = '/var/lib/erpnext'
            VERSION = '15'
            FRAPPE_REPO = 'https://github.com/frappe/frappe_docker.git'
            IMAGE_ID = 'ConfigLM.moe/erpnext:v' + VERSION
            CONTAINER_NAME = 'ERPNext'

            def actionERPNextBuild(id, target, activeState, context, options)
                buildContainer(id, target, options)
            end

            def buildContainer(id, target, options)
                Linux.withConnection(local) do |localLinux|
                    begin
                        localLinux.ensurePackages(['git', 'Podman'], options) unless localLinux.hasBinaries?(['git', 'podman'], options)
                    rescue RuntimeError => error
                        prompt.say(error, :color => :red)
                    end
                    frappe = File.expand_path(REPOS_CACHE + '/frappe_docker')
                    if !File.exist?(frappe)
                        localLinux.createDirs(options, File.expand_path(REPOS_CACHE))
                        localLinux.exec("cd #{REPOS_CACHE} && git clone --quiet #{FRAPPE_REPO}", false, options)
                    else
                        localLinux.exec("cd #{REPOS_CACHE}/frappe_docker && git pull --quiet", false, options)
                    end
                    localLinux.exec("cd #{REPOS_CACHE}/frappe_docker && git checkout . --quiet", false, options)

                    if !IO::Connection.cmdSuccess?("podman image exists #{IMAGE_ID}")
                        appsJSON = Base64.urlsafe_encode64(File.read(__dir__ + '/sites/apps.json').gsub('$VERSION', VERSION))
                        # if you see error like "newuidmap 5227 0 1000 1 1 100000 65536: newuidmap: write to uid_map failed: Operation not permitted"
                        # then for LXC you need to set idmap like:
                        # LXC:
                        #     - idmap: u 0 100000 165536
                        #     - idmap: g 0 100000 165536
                        localLinux.exec("cd #{REPOS_CACHE}/frappe_docker && podman build --tag=#{IMAGE_ID} --build-arg APPS_JSON_BASE64=#{appsJSON} --build-arg FRAPPE_BRANCH=version-#{VERSION}  --file images/custom/Containerfile .", false, options)
                    end
                end
            end

            def actionERPNextDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') if (!target.key?('Proxy') || target['Proxy']) && !target['Domain']

                target['Database'] ||= {}
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        dbPassword = self.configureMariaDB(target['Database'], activeState, linuxConnection, options)

                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'ERPNext', linuxConnection, options)

                        cmd = IO::SSH.cmd(target['Location'])
                        local.exec("podman image save ConfigLM.moe/erpnext:v#{VERSION} | #{cmd} 'cat > #{HOME_DIR}/erpnext.tar'", false, options)

                        linuxConnection.withUserShell(USER) do |shell|
                            shell.createDirs(options, '~/sites', '~/logs')
                            Podman.loadImage(shell, 'erpnext.tar', options)
                        end

                        linuxConnection.exec("rm -f #{HOME_DIR}/erpnext.tar", false, options)

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.exec(" echo 'FRAPPE_DB_PASSWORD=#{dbPassword}' > #{path}/ERPNext.env", false, options)
                        linuxConnection.exec("echo 'FRAPPE_SITE_NAME_HEADER=erpnext' >> #{path}/ERPNext.env", false, options)
                        #linuxConnection.exec("echo 'UPSTREAM_REAL_IP_ADDRESS=127.0.0.1' >> #{path}/ERPNext.env", false, options)
                        #linuxConnection.exec("echo 'UPSTREAM_REAL_IP_RECURSIVE=on' >> #{path}/ERPNext.env", false, options)
                        linuxConnection.exec("echo 'BACKEND=10.90.50.10:8000' >> #{path}/ERPNext.env", false, options)
                        linuxConnection.exec("echo 'SOCKETIO=10.90.50.11:9000' >> #{path}/ERPNext.env", false, options)

                        linuxConnection.exec("chown #{USER}:#{USER} #{path}/ERPNext.env", false, options)
                        linuxConnection.exec("chmod 600 #{path}/ERPNext.env", false, options)

                        linuxConnection.upload(__dir__ + '/sites/apps.txt', HOME_DIR + '/sites/', options)
                        linuxConnection.upload(__dir__ + '/sites/common_site_config.json', HOME_DIR + '/sites/', options)

                        if target['Database'] && target['Database']['HostName']
                            linuxConnection.exec("sed -i 's|\"10.0.2.2\"|\"#{target['Database']['HostName']}\"|' #{HOME_DIR}/sites/common_site_config.json", false, options)
                        end

                        if target['Valkey']
                            linuxConnection.exec("sed -i 's|10.0.2.2:6379|#{target['Valkey']}|' #{HOME_DIR}/sites/common_site_config.json", false, options)
                        end

                        if target['ValkeySecretId']
                            valkeyPassword = context.secrets.load(target['ValkeySecretId'], 'VALKEY_PASSWORD')
                            linuxConnection.exec("sed -i 's|\"use_rq_auth\": false|\"use_rq_auth\": true|' #{HOME_DIR}/sites/common_site_config.json", false, options)
                            linuxConnection.exec("sed -i 's|$VALKEY_PASSWORD|#{valkeyPassword}|' #{HOME_DIR}/sites/common_site_config.json", false, { **options, hide: true })
                        end

                        linuxConnection.exec("chown -R #{USER}:#{USER} " + HOME_DIR + '/sites', false, options)

                        linuxConnection.upload(__dir__ + '/ERPNext.network', path, options)
                        linuxConnection.upload(__dir__ + '/ERPNext.container', path, options)
                        linuxConnection.upload(__dir__ + '/ERPNext-Queue.container', path, options)
                        linuxConnection.upload(__dir__ + '/ERPNext-Scheduler.container', path, options)
                        linuxConnection.upload(__dir__ + '/ERPNext-Websocket.container', path, options)
                        linuxConnection.upload(__dir__ + '/ERPNext-Frontend.container', path, options)
                        linuxConnection.exec("sed -i 's|$VERSION|#{VERSION}|' #{path}/ERPNext.container", false, options)
                        linuxConnection.exec("sed -i 's|$VERSION|#{VERSION}|' #{path}/ERPNext-Queue.container", false, options)
                        linuxConnection.exec("sed -i 's|$VERSION|#{VERSION}|' #{path}/ERPNext-Scheduler.container", false, options)
                        linuxConnection.exec("sed -i 's|$VERSION|#{VERSION}|' #{path}/ERPNext-Websocket.container", false, options)
                        linuxConnection.exec("sed -i 's|$VERSION|#{VERSION}|' #{path}/ERPNext-Frontend.container", false, options)

                        if !target.key?('Proxy') || target['Proxy']
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                nginxConnection.provisionProxy('http://127.0.0.1:18400', 'ERPNext', target, activeState, context, options)
                            end
                        elsif target.key?('Proxy') && target['Proxy'] == false
                            linuxConnection.exec("sed -i 's|PublishPort=127.0.0.1:18400:|PublishPort=0.0.0.0:18400:|' #{path}/ERPNext-Frontend.container", false, options)
                            linuxConnection.firewallAddPort('18400/tcp', options)
                        end

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'ERPNext-network', options)
                        linuxConnection.restartUserService(USER, 'ERPNext', options)

                        MariaDB.withConnection(target['Database'], linuxConnection) do |connectionDB|
                            if !connectionDB.tableExist?(USER, 'tabUser', { **options, 'dry': false })
                                linuxConnection.withUserShell(USER) do |shellConnection|
                                    Podman.withConnection(shellConnection, Podman.container(CONTAINER_NAME, shellConnection, options)) do |podmanConnection|
                                        adminPassword = SecureRandom.alphanumeric(20)
                                        dbAdminPassword = connectionDB.createAdmin(options)
                                        linuxConnection.exec("rm -rf " + HOME_DIR + '/sites/erpnext', false, options)
                                        #podmanConnection.exec("bench new-site --no-setup-db --db-name erpnext --db-user erpnext --admin-password #{adminPassword} --install-app erpnext --set-default erpnext", false, { **options, hide: true })
                                        connectionDB.dropDB(USER, options)
                                        podmanConnection.exec("bench new-site --db-root-username admin --db-root-password #{dbAdminPassword} --db-name erpnext --admin-password #{adminPassword} --install-app erpnext --set-default erpnext", false, { **options, hide: true })
                                        podmanConnection.exec("bench --site erpnext install-app hrms", false, options)
                                        prompt.say("Administrator password: #{adminPassword}", :color => :magenta)
                                        connectionDB.dropAdmin(options)
                                    end
                                end
                            end
                        end

                        linuxConnection.restartUserService(USER, 'ERPNext-Queue', options)
                        linuxConnection.restartUserService(USER, 'ERPNext-Scheduler', options)
                        linuxConnection.restartUserService(USER, 'ERPNext-Websocket', options)
                        linuxConnection.restartUserService(USER, 'ERPNext-Frontend', options)
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
                cleanupType(:ERPNext, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if item['Config']['Proxy'].nil? || item['Config']['Proxy']
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                nginxConnection.cleanupConfig('ERPNext', context, options)
                                nginxConnection.reload(options)
                            end
                        end
                        linuxConnection.firewallRemovePort('18400/tcp', options)

                        linuxConnection.stopUserService(USER, 'ERPNext-Frontend', options)
                        linuxConnection.stopUserService(USER, 'ERPNext', options)
                        linuxConnection.stopUserService(USER, 'ERPNext-Websocket', options)
                        linuxConnection.stopUserService(USER, 'ERPNext-Scheduler', options)
                        linuxConnection.stopUserService(USER, 'ERPNext-Queue', options)
                        linuxConnection.stopUserService(USER, 'ERPNext-network', options)

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.rm(path + 'ERPNext.network', options[:dry])
                        linuxConnection.rm(path + 'ERPNext.container', options[:dry])
                        linuxConnection.rm(path + 'ERPNext-Queue.container', options[:dry])
                        linuxConnection.rm(path + 'ERPNext-Scheduler.container', options[:dry])
                        linuxConnection.rm(path + 'ERPNext-Websocket.container', options[:dry])
                        linuxConnection.rm(path + 'ERPNext-Frontend.container', options[:dry])

                        linuxConnection.exec("podman rmi #{IMAGE_ID}", true, options)

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


