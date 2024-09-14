
module ConfigLMM
    module LMM
        class ERPNext < Framework::NginxApp

            USER = 'erpnext'
            HOME_DIR = '/var/lib/erpnext'
            VERSION = '15'
            FRAPPE_REPO = 'https://github.com/frappe/frappe_docker.git'
            IMAGE_ID = 'ConfigLM.moe/erpnext:v' + VERSION

            def actionERPNextBuild(id, target, activeState, context, options)
                buildContainer(id, target, options)
            end

            def buildContainer(id, target, options)
                begin
                    Framework::LinuxApp.ensurePackage('git', '@me', 'git')
                    Framework::LinuxApp.ensurePackage('Podman', '@me', 'podman')
                rescue RuntimeError => error
                    prompt.say(error, :color => :red)
                end
                frappe = File.expand_path(REPOS_CACHE + '/frappe_docker')
                if !File.exist?(frappe)
                    mkdir(File.expand_path(REPOS_CACHE), false)
                    self.class.exec('cd #{REPOS_CACHE} && git clone --quiet #{FRAPPE_REPO}')
                else
                    self.class.exec('cd #{REPOS_CACHE}/frappe_docker && git pull --quiet')
                end
                self.class.exec('cd #{REPOS_CACHE}/frappe_docker && git checkout . --quiet')

                if !self.class.cmdSuccess?("podman image exists #{IMAGE_ID}")
                    appsJSON = Base64.urlsafe_encode64(File.read(__dir__ + '/sites/apps.json').gsub('$VERSION', VERSION))
                    self.class.exec("cd #{REPOS_CACHE}/frappe_docker && podman build --tag=#{IMAGE_ID} --build-arg APPS_JSON_BASE64=#{appsJSON} --build-arg FRAPPE_BRANCH=version-#{VERSION}  --file images/custom/Containerfile .")
                end
            end

            def actionERPNextDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']

                target['Database'] ||= {}
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|

                        dbPassword = self.configureMariaDB(target['Database'], activeState, ssh)
                        distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                        Framework::LinuxApp.configurePodmanServiceOverSSH(USER, HOME_DIR, 'ERPNext', distroInfo, ssh)
                        self.class.exec("su --login #{USER} --shell /bin/sh --command 'mkdir -p ~/sites ~/logs'", ssh)

                        cmd = self.class.cmdSSH(uri)
                        self.class.exec("podman image save ConfigLM.moe/erpnext:v#{VERSION} | #{cmd} 'cat > #{HOME_DIR}/erpnext.tar'")
                        self.class.exec("su --login #{USER} --shell /usr/bin/sh --command 'podman image load --input erpnext.tar'", ssh)
                        self.class.exec("rm -f #{HOME_DIR}/erpnext.tar", ssh)

                        path = Framework::LinuxApp::SYSTEMD_CONTAINERS_PATH.gsub('~', HOME_DIR)
                        self.class.exec(" echo 'FRAPPE_DB_PASSWORD=#{dbPassword}' > #{path}/ERPNext.env", ssh)
                        self.class.exec("echo 'FRAPPE_SITE_NAME_HEADER=erpnext' >> #{path}/ERPNext.env", ssh)
                        #self.class.exec("echo 'UPSTREAM_REAL_IP_ADDRESS=127.0.0.1' >> #{path}/ERPNext.env", ssh)
                        #self.class.exec("echo 'UPSTREAM_REAL_IP_RECURSIVE=on' >> #{path}/ERPNext.env", ssh)
                        self.class.exec("echo 'BACKEND=10.90.50.10:8000' >> #{path}/ERPNext.env", ssh)
                        self.class.exec("echo 'SOCKETIO=10.90.50.11:9000' >> #{path}/ERPNext.env", ssh)

                        self.class.exec("chown #{USER}:#{USER} #{path}/ERPNext.env", ssh)
                        self.class.exec("chmod 600 #{path}/ERPNext.env", ssh)

                        ssh.scp.upload!(__dir__ + '/sites/apps.txt', HOME_DIR + '/sites/')
                        ssh.scp.upload!(__dir__ + '/sites/common_site_config.json', HOME_DIR + '/sites/')

                        if target['Database'] && target['Database']['HostName']
                            self.class.exec("sed -i 's|\"10.0.2.2\"|\"#{target['Database']['HostName']}\"|' #{HOME_DIR}/sites/common_site_config.json", ssh)
                        end

                        if target['Valkey']
                            self.class.exec("sed -i 's|10.0.2.2:6379|#{target['Valkey']}|' #{HOME_DIR}/sites/common_site_config.json", ssh)
                        end

                        valkeyPassword = ENV[id + '-VALKEY_PASSWORD'] || ENV['VALKEY_PASSWORD']
                        if valkeyPassword
                            self.class.exec("sed -i 's|\"use_rq_auth\": false|\"use_rq_auth\": true|' #{HOME_DIR}/sites/common_site_config.json", ssh)
                            self.class.exec("sed -i 's|$VALKEY_PASSWORD|#{valkeyPassword}|' #{HOME_DIR}/sites/common_site_config.json", ssh)
                        end

                        self.class.exec("chown -R #{USER}:#{USER} " + HOME_DIR + '/sites', ssh)

                        ssh.scp.upload!(__dir__ + '/ERPNext.network', path)
                        ssh.scp.upload!(__dir__ + '/ERPNext.container', path)
                        ssh.scp.upload!(__dir__ + '/ERPNext-Queue.container', path)
                        ssh.scp.upload!(__dir__ + '/ERPNext-Scheduler.container', path)
                        ssh.scp.upload!(__dir__ + '/ERPNext-Websocket.container', path)
                        ssh.scp.upload!(__dir__ + '/ERPNext-Frontend.container', path)
                        self.class.exec("sed -i 's|$VERSION|#{VERSION}|' #{path}/ERPNext.container", ssh)
                        self.class.exec("sed -i 's|$VERSION|#{VERSION}|' #{path}/ERPNext-Queue.container", ssh)
                        self.class.exec("sed -i 's|$VERSION|#{VERSION}|' #{path}/ERPNext-Scheduler.container", ssh)
                        self.class.exec("sed -i 's|$VERSION|#{VERSION}|' #{path}/ERPNext-Websocket.container", ssh)
                        self.class.exec("sed -i 's|$VERSION|#{VERSION}|' #{path}/ERPNext-Frontend.container", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ daemon-reload", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart ERPNext-network", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart ERPNext", ssh)

                        containers = JSON.parse(self.class.exec("su --login #{USER} --shell /usr/bin/sh --command 'podman ps --format json --filter name=^ERPNext$'", ssh).strip)
                        raise 'Failed to find container!' if containers.empty?

                        MariaDB.executeRemotely(target['Database'], ssh) do |sshDB|
                            if !MariaDB.tableExist?(USER, 'tabUser', sshDB)
                                adminPassword = SecureRandom.alphanumeric(20)
                                self.class.exec("rm -rf " + HOME_DIR + '/sites/erpnext', ssh)
                                #self.class.exec(" su --login #{USER} --shell /usr/bin/sh --command \"podman exec #{containers.first['Id']} sh -c 'bench new-site --no-setup-db --db-name erpnext --db-user erpnext --admin-password #{adminPassword} --install-app erpnext --set-default erpnext'\"", ssh)
                                dbAdminPassword = MariaDB.createAdmin(sshDB)
                                MariaDB.executeSQL("DROP DATABASE #{USER}", nil, sshDB)
                                self.class.exec(" su --login #{USER} --shell /usr/bin/sh --command \" podman exec #{containers.first['Id']} sh -c ' bench new-site --db-root-username admin --db-root-password #{dbAdminPassword} --db-name erpnext --admin-password #{adminPassword} --install-app erpnext --set-default erpnext'\"", ssh)
                                MariaDB.dropAdmin(sshDB)
                                self.class.exec("su --login #{USER} --shell /usr/bin/sh --command \"podman exec #{containers.first['Id']} sh -c 'bench --site erpnext install-app hrms'\"", ssh)
                                prompt.say("Administrator password: #{adminPassword}", :color => :magenta)
                            end
                        end

                        self.class.exec("systemctl --user --machine=#{USER}@ restart ERPNext-Queue", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart ERPNext-Scheduler", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart ERPNext-Websocket", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart ERPNext-Frontend", ssh)

                        useNginxProxy(__dir__, 'ERPNext', id, target, activeState, state, context, options, ssh)
                    end
                else
                    # TODO
                end
            end

            def configureMariaDB(settings, activeState, ssh)
                password = SecureRandom.alphanumeric(20)
                MariaDB.createRemoteUserAndDB(settings, USER, password, ssh)
                password
            end

        end
    end
end


