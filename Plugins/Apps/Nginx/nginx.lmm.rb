
module ConfigLMM
    module LMM
        class Nginx < Framework::NginxApp
            CERTBOT_PACKAGE = 'CertBotNginx'
            ERROR_PAGES_REPO = 'https://github.com/HttpErrorPages/HttpErrorPages.git'

            def actionNginxBuild(id, target, activeState, context, options)

                dir = options['output'] + '/nginx/'
                mkdir(dir + 'conf.d', options[:dry])
                mkdir(dir + 'servers-lmm', options[:dry])
                copy(__dir__ + '/config-lmm', dir, options[:dry])
                copy(__dir__ + '/nginx.conf', dir, options[:dry])
                copy(__dir__ + '/conf.d/configlmm.conf', dir + 'conf.d/', options[:dry])

                mkdir(options['output'] + WWW_DIR + 'root', options[:dry])
                mkdir(options['output'] + WWW_DIR + 'errors', options[:dry])
            end

            # TODO
            # def actionNginxDiff(id, target, activeState, context, options)
            #     I think we need nginx config parser to implement this
            # end

            def actionNginxDeploy(id, target, activeState, context, options)
                dir = options['output'] + '/nginx/'

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.class.sshStart(uri) do |ssh|
                        Framework::LinuxApp.ensurePackages([CERTBOT_PACKAGE], ssh)
                        self.class.prepareNginxConfig(target, ssh)

                        self.class.sshExec!(ssh, "mkdir -p #{CONFIG_DIR}conf.d")
                        self.class.sshExec!(ssh, "mkdir -p #{WWW_DIR}root")
                        self.class.sshExec!(ssh, "mkdir -p #{WWW_DIR}errors")
                        ssh.scp.upload!(dir + 'nginx.conf', CONFIG_DIR + 'nginx.conf')
                        ssh.scp.upload!(dir + 'conf.d/configlmm.conf', CONFIG_DIR + 'conf.d/configlmm.conf')
                        resolverIP = self.class.sshExec!(ssh, "cat /etc/resolv.conf | grep 'nameserver' | grep -v ':' | head -n 1 | cut -d ' ' -f 2").strip
                        self.class.sshExec!(ssh, "sed -i 's|^resolver .*|resolver #{resolverIP};|' /etc/nginx/conf.d/configlmm.conf")

                        self.class.uploadFolder(dir + 'config-lmm', CONFIG_DIR, ssh)
                        self.class.uploadFolder(dir + 'servers-lmm', CONFIG_DIR, ssh)

                        template = ERB.new(File.read(__dir__ + '/main.conf.erb'))
                        renderTemplate(template, target, dir + 'main.conf', options)
                        ssh.scp.upload!(dir + 'main.conf', CONFIG_DIR + 'main.conf')

                        if !self.class.remoteFilePresent?(WWW_DIR + 'errors/HTTP500.html', ssh)
                            errorPages = File.expand_path(REPOS_CACHE + '/HttpErrorPages')
                            if !File.exist?(errorPages)
                                mkdir(File.expand_path(REPOS_CACHE), false)
                                begin
                                    Framework::LinuxApp.ensurePackages(['git', 'Yarn'], '@me')
                                rescue RuntimeError => error
                                    prompt.say(error, :color => :red)
                                end
                                `cd #{REPOS_CACHE} && git clone --quiet #{ERROR_PAGES_REPO} > /dev/null`
                            end
                            `cd #{errorPages} && yarn install --silent`
                            `cd #{errorPages} && yarn run static config-dist.json > /dev/null`
                            `cd #{errorPages} && cp -R dist errors`
                            self.class.uploadFolder(errorPages + '/errors', WWW_DIR, ssh)
                        end

                        Framework::LinuxApp.createCertificateOverSSH(ssh)
                    end
                else
                    self.class.prepareNginxConfig(target, nil)

                    copy(dir + '/config-lmm', CONFIG_DIR, options[:dry])
                    copy(dir + '/nginx.conf', CONFIG_DIR, options[:dry])

                    copy(dir + '/servers-lmm', CONFIG_DIR, options['dry'])
                    mkdir(WWW_DIR + 'root', options[:dry])
                    mkdir(WWW_DIR + 'errors', options[:dry])

                    template = ERB.new(File.read(__dir__ + '/main.conf.erb'))
                    renderTemplate(template, target, dir + 'main.conf', options)
                    copy(dir + '/main.conf', CONFIG_DIR, options[:dry])

                    dir = "/etc/letsencrypt/live/Wildcard/"
                    `mkdir -p #{dir}`
                    if !File.exist?(dir + 'fullchain.pem')
                        `openssl req -x509 -noenc -days 90 -newkey rsa:2048 -keyout #{dir}privkey.pem -out #{dir}fullchain.pem -subj "/C=US/O=ConfigLMM/CN=Wildcard"`
                         `cp #{dir}fullchain.pem #{dir}chain.pem`
                    end

                end
                # Consider:
                # * Deploy on current host
                # * Deploy on remote host thru SSH (eg. VPS)
                # * Using already existing solution like Chef/Puppet/Ansible/etc
                # * Provision from some Cloud provider
                # We implement this as we go - what people actually use
            end

            def actionNginxProxyBuild(id, target, activeState, context, options)
                target['ConfigName'] = target['Name']
                writeNginxConfig(__dir__, 'proxy', id, target, activeState, context, options)
                actionNginxBuild(id, target, activeState, context, options)
            end

            def actionNginxProxyDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Proxy field must be set!') unless target['Proxy']

                target['ConfigName'] = target['Name']
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.class.sshStart(uri) do |ssh|
                        useNginxProxy(__dir__, 'proxy', id, target, activeState, state, context, options, ssh)
                    end
                else
                    useNginxProxy(__dir__, 'proxy', id, target, activeState, state, context, options, ssh)
                end
            end

        end
    end
end
