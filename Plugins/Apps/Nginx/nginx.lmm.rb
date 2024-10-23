
require_relative 'Connection'

module ConfigLMM
    module LMM
        class Nginx < Framework::NginxApp
            PACKAGE_NAME = 'Nginx'
            SERVICE_NAME = :nginx
            ERROR_PAGES_REPO = 'https://github.com/HttpErrorPages/HttpErrorPages.git'

            def actionNginxBuild(id, target, activeState, context, options)
                dir = options['output'] + '/nginx/'
                local.mkdir(dir + 'conf.d', options[:dry])
                local.mkdir(dir + 'servers-lmm', options[:dry])
                local.copy(__dir__ + '/config-lmm', dir, options[:dry])
                local.copy(__dir__ + '/nginx.conf', dir, options[:dry])
                local.copy(__dir__ + '/conf.d/configlmm.conf', dir + 'conf.d/', options[:dry])

                local.mkdir(options['output'] + NginxConnection::WWW_DIR + 'root', options[:dry])
                local.mkdir(options['output'] + NginxConnection::WWW_DIR + 'errors', options[:dry])
            end

            # TODO
            # def actionNginxDiff(id, target, activeState, context, options)
            #     I think we need nginx config parser to implement this
            # end

            def actionNginxDeploy(id, target, activeState, context, options)
                dir = options['output'] + '/nginx/'

                # Consider:
                # * Deploy on current host
                # * Deploy on remote host thru SSH (eg. VPS)
                # * Using already existing solution like Chef/Puppet/Ansible/etc
                # * Provision from some Cloud provider
                # We implement this as we go - what people actually use

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        self.class.withConnection(linuxConnection) do |nginxConnection|
                            linuxConnection.ensurePackage(PACKAGE_NAME, options)

                            linuxConnection.createDirs(options, "#{NginxConnection::CONFIG_DIR}conf.d", "#{NginxConnection::WWW_DIR}root", "#{NginxConnection::WWW_DIR}errors")

                            linuxConnection.upload(dir + 'nginx.conf', NginxConnection::CONFIG_DIR + 'nginx.conf', options)
                            linuxConnection.upload(dir + 'conf.d/configlmm.conf', NginxConnection::CONFIG_DIR + 'conf.d/configlmm.conf', options)

                            if options['dry']
                                linuxConnection.exec("cat /etc/resolv.conf | grep 'nameserver' | grep -v ':' | head -n 1 | cut -d ' ' -f 2", { **options, 'dry': true })
                            end
                            resolverIP = linuxConnection.exec("cat /etc/resolv.conf | grep 'nameserver' | grep -v ':' | head -n 1 | cut -d ' ' -f 2", { **options, 'dry': false }).strip

                            linuxConnection.fileReplace('/etc/nginx/conf.d/configlmm.conf', '^resolver .*', "resolver #{resolverIP};", options)

                            linuxConnection.uploadFolder(dir + 'config-lmm', NginxConnection::CONFIG_DIR, options)
                            linuxConnection.uploadFolder(dir + 'servers-lmm', NginxConnection::CONFIG_DIR, options)

                            target = target.dup
                            target['NginxVersion'] = nginxConnection.nginxVersion
                            template = ERB.new(File.read(__dir__ + '/main.conf.erb'))
                            local.renderTemplate(template, target, dir + 'main.conf', options)
                            linuxConnection.upload(dir + 'main.conf', NginxConnection::CONFIG_DIR + 'main.conf', options)

                            if !linuxConnection.filePresent?(NginxConnection::WWW_DIR + 'errors/HTTP500.html', { **options, 'dry' => false })
                                errorPages = File.expand_path(REPOS_CACHE + '/HttpErrorPages')
                                if !File.exist?(errorPages)
                                    local.mkdir(File.expand_path(REPOS_CACHE), options['dry'])
                                    begin
                                        Linux.withConnection(local) do |localLinux|
                                            localLinux.ensurePackages(['git', 'Yarn'], options) unless localLinux.hasBinaries?(['git', 'yarn'], options)
                                        end
                                    rescue RuntimeError => error
                                        prompt.say(error, :color => :red)
                                    end
                                    local.exec("cd #{REPOS_CACHE} && git clone --quiet #{ERROR_PAGES_REPO}", false, options)
                                    local.exec("cd #{errorPages} && yarn install --silent", false, options)
                                    local.exec("cd #{errorPages} && yarn run static config-dist.json", false, options)
                                    local.exec("cd #{errorPages} && cp -R dist errors", false, options)
                                end
                                linuxConnection.uploadFolder(errorPages + '/errors', NginxConnection::WWW_DIR, options)
                            end

                            linuxConnection.createWildecardCertificate(options)

                            linuxConnection.ensureServiceAutoStart(SERVICE_NAME, options)
                            linuxConnection.startService(SERVICE_NAME, options)

                            linuxConnection.firewallAddService('http', options)
                            linuxConnection.firewallAddService('https', options)
                        end
                    end
                end
            end

            def actionNginxProxyBuild(id, target, activeState, context, options)
                target['ConfigName'] = target['Name']

                self.class.withConnection(local) do |nginxConnection|
                    nginxConnection.writeConfig(__dir__, 'proxy', target, activeState, context, options)
                end
                actionNginxBuild(id, target, activeState, context, options)
            end

            def actionNginxProxyDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Proxy field must be set!') unless target['Proxy']

                target['ConfigName'] = target['Name']
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        self.class.withConnection(linuxConnection) do |nginxConnection|
                            nginxConnection.provision(__dir__, 'proxy', target, activeState, context, options)
                        end
                    end
                end
            end

            def self.withConnection(linuxConnection)
                yield(NginxConnection.new(linuxConnection))
            end

        end
    end
end
