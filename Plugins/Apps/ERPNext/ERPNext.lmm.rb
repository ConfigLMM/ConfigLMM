
require 'addressable/idna'

require_relative '../Podman/Podman.lmm'

module ConfigLMM
    module LMM
        class ERPNext < Framework::Plugin

            USER = 'erpnext'
            HOME_DIR = '/var/lib/erpnext'
            VERSION = '16'
            FRAPPE_REPO = 'https://github.com/frappe/frappe_docker.git'
            IMAGE_ID = Podman::IMAGE_DOMAIN + '/erpnext:v' + VERSION
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
                        appsJSON = JSON.parse(File.read(__dir__ + '/sites/apps.json').gsub('$VERSION', VERSION))
                        # if you see error like "newuidmap 5227 0 1000 1 1 100000 65536: newuidmap: write to uid_map failed: Operation not permitted"
                        # then for LXC you need to set idmap like:
                        # LXC:
                        #     - idmap: u 0 100000 165536
                        #     - idmap: g 0 100000 165536
                        localLinux.fileReplace(REPOS_CACHE + '/frappe_docker/resources/core/nginx/nginx-template.conf', '$proxy_x_forwarded_proto://${FRAPPE_SITE_NAME_HEADER}', '$proxy_x_forwarded_proto://${PUBLIC_HOST}', options)
                        localLinux.fileReplace(REPOS_CACHE + '/frappe_docker/resources/core/nginx/nginx-entrypoint.sh', '${FRAPPE_SITE_NAME_HEADER}', '${FRAPPE_SITE_NAME_HEADER} ${PUBLIC_HOST}', options)
                        appsJSONPath = options['output'] + '/apps.json'
                        File.write(appsJSONPath, appsJSON.to_json)
                        localLinux.inDir(REPOS_CACHE + '/frappe_docker') do
                            args = [
                                '--build-arg', "FRAPPE_BRANCH=version-#{VERSION}",
                                '--secret', "id=apps_json,src=#{appsJSONPath}"
                            ]
                            args << '--annotation' << Podman::NAMESPACE + '.erpnext.apps=' + appsJSON.map { |app| app['url'] }.join(',')
                            args << '--annotation' << Podman::NAMESPACE + '.erpnext.branches=' + appsJSON.map { |app| app['branch'] }.join(',')
                            Podman::buildGitImage('images/custom/Containerfile', IMAGE_ID, args, localLinux, options)
                        end
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
                            shell.createDirs(options, '~/sites', '~/logs', '~/config/pids')
                            Podman.loadImage(shell, 'erpnext.tar', options)
                        end

                        linuxConnection.fileDelete(HOME_DIR + '/erpnext.tar', options)

                        path = Podman.containersPath(HOME_DIR)

                        publicURL = 'http://localhost:18400'
                        publicHost = 'localhost:18400'
                        podmanPublicHost = nil
                        if target['Domain']
                            publicHost = target['Domain']
                            publicURL = 'https://' + publicHost
                            if !IO::Connection.ipAddr?(publicHost)
                                if Podman.updateHost(publicHost, linuxConnection, options) != publicHost
                                    podmanPublicHost = publicHost.split(':').first
                                end
                            end
                        end

                        linuxConnection.fileWrite(path + '/ERPNext.env', 'FRAPPE_SITE_NAME_HEADER=site', options)
                        linuxConnection.fileAppend(path + '/ERPNext.env', 'PUBLIC_HOST=' + Addressable::IDNA.to_ascii(publicHost.downcase), options)
                        #linuxConnection.fileAppend(path + '/ERPNext.env', 'UPSTREAM_REAL_IP_ADDRESS=127.0.0.1', options)
                        #linuxConnection.fileAppend(path + '/ERPNext.env', 'UPSTREAM_REAL_IP_RECURSIVE=on', options)
                        linuxConnection.fileAppend(path + '/ERPNext.env', 'BACKEND=10.90.50.10:8000', options)
                        linuxConnection.fileAppend(path + '/ERPNext.env', 'SOCKETIO=10.90.50.11:9000', options)

                        linuxConnection.setUserGroup(path + '/ERPNext.env', USER, USER, options)
                        linuxConnection.setPrivate(path + '/ERPNext.env', options)

                        linuxConnection.upload(__dir__ + '/sites/apps.txt', HOME_DIR + '/sites/', options)
                        linuxConnection.upload(__dir__ + '/sites/common_site_config.json', HOME_DIR + '/sites/', options)

                        linuxConnection.fileReplace(HOME_DIR + '/sites/common_site_config.json', '$PUBLIC_URL', publicURL, options)
                        activeState['PublicURL'] = publicURL

                        activeState['Database'] ||= {}
                        dbHostName = 'host.containers.internal'
                        if target['Database'] && target['Database']['HostName']
                            dbHostName = Podman.updateHost(target['Database']['HostName'], linuxConnection, options)
                            if dbHostName != 'host.containers.internal'
                                linuxConnection.fileReplace(HOME_DIR + '/sites/common_site_config.json', '"host.containers.internal"', '"' + dbHostName + '"', options)
                            end
                        end
                        activeState['Database']['HostName'] = dbHostName

                        if target['Valkey']
                            activeState['Valkey'] = Podman.updateHost(target['Valkey'], linuxConnection, options)
                            if activeState['Valkey'] != 'host.containers.internal:6379'
                                linuxConnection.fileReplace(HOME_DIR + '/sites/common_site_config.json', 'host.containers.internal:6379', activeState['Valkey'], options)
                            end
                        else
                            activeState['Valkey'] = 'host.containers.internal:6379'
                        end

                        if target['ValkeySecretId']
                            valkeyPassword = context.secrets.load(target['ValkeySecretId'], 'VALKEY_PASSWORD')
                            linuxConnection.fileReplace(HOME_DIR + '/sites/common_site_config.json', '"use_rq_auth": false', '"use_rq_auth": true', options)
                            linuxConnection.fileReplace(HOME_DIR + '/sites/common_site_config.json', '$VALKEY_PASSWORD', valkeyPassword, { **options, hide: true })
                        end

                        linuxConnection.setUserGroup(HOME_DIR + '/sites', USER, USER, options)

                        linuxConnection.upload(__dir__ + '/ERPNext.network', path, options)
                        linuxConnection.upload(__dir__ + '/ERPNext.container', path, options)
                        linuxConnection.upload(__dir__ + '/ERPNext-Queue.container', path, options)
                        linuxConnection.upload(__dir__ + '/ERPNext-Scheduler.container', path, options)
                        linuxConnection.upload(__dir__ + '/ERPNext-Websocket.container', path, options)
                        linuxConnection.upload(__dir__ + '/ERPNext-Frontend.container', path, options)
                        linuxConnection.fileReplace(path + '/ERPNext.container', '$VERSION', VERSION, options)
                        linuxConnection.fileReplace(path + '/ERPNext-Queue.container', '$VERSION', VERSION, options)
                        linuxConnection.fileReplace(path + '/ERPNext-Scheduler.container', '$VERSION', VERSION, options)
                        linuxConnection.fileReplace(path + '/ERPNext-Websocket.container', '$VERSION', VERSION, options)
                        linuxConnection.fileReplace(path + '/ERPNext-Frontend.container', '$VERSION', VERSION, options)

                        if podmanPublicHost
                            linuxConnection.fileReplace(path + '/ERPNext.container', '$PUBLIC_HOST', podmanPublicHost, options)
                        else
                            linuxConnection.fileRemoveLines(path + '/ERPNext.container', '$PUBLIC_HOST', options)
                        end

                        if !target.key?('Proxy') || target['Proxy']
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                nginxConnection.provisionProxy('http://127.0.0.1:18400', 'ERPNext', target, activeState, context, options)
                            end
                        elsif target.key?('Proxy') && target['Proxy'] == false
                            linuxConnection.fileReplace(path + '/ERPNext-Frontend.container', 'PublishPort=127.0.0.1:18400:', 'PublishPort=0.0.0.0:18400:', options)
                            linuxConnection.firewallAddPort('18400/tcp', options)
                        end

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'ERPNext-network', options)
                        linuxConnection.restartUserService(USER, 'ERPNext', options)

                        MariaDB.withConnection(target['Database'], linuxConnection) do |connectionDB|
                            linuxConnection.withUserShell(USER) do |shellConnection|
                                Podman.withConnection(shellConnection, Podman.container(CONTAINER_NAME, shellConnection, options)) do |podmanConnection|
                                    if connectionDB.tableExist?(USER, 'tabUser', { **options, 'dry' => false })
                                        linuxConnection.fileReplace(HOME_DIR + '/sites/site/site_config.json', /"db_password".*/, "\"db_password\": \"#{dbPassword}\",", { **options, hide: true })
                                        podmanConnection.exec('bench --site site migrate', false, options)
                                        podmanConnection.exec('bench --site site clear-website-cache', false, options)
                                    else
                                        adminPassword = SecureRandom.alphanumeric(20)
                                        linuxConnection.fileDelete(HOME_DIR + '/sites/erpnext', options)
                                        podmanConnection.exec("bench new-site --force --no-setup-db --db-name erpnext --db-user erpnext --db-password #{dbPassword.shellescape} --admin-password #{adminPassword.shellescape} --install-app erpnext --set-default site", false, { **options, hide: true })
                                        podmanConnection.exec("bench --site site install-app hrms", false, options)
                                        prompt.say("Administrator password: #{adminPassword}", :color => :magenta)
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


