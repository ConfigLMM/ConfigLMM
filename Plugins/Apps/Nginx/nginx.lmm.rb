
module ConfigLMM
    module LMM
        class Nginx < Framework::NginxApp
            CERTBOT_PACKAGE = 'CertBotNginx'

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
                        Framework::LinuxApp.ensurePackagesOverSSH([CERTBOT_PACKAGE], ssh)
                        self.class.prepareNginxConfig(target, ssh)

                        self.class.sshExec!(ssh, "mkdir -p #{CONFIG_DIR}conf.d")
                        self.class.sshExec!(ssh, "mkdir -p #{WWW_DIR}root")
                        self.class.sshExec!(ssh, "mkdir -p #{WWW_DIR}errors")
                        ssh.scp.upload!(dir + 'nginx.conf', CONFIG_DIR + 'nginx.conf')
                        ssh.scp.upload!(dir + 'conf.d/configlmm.conf', CONFIG_DIR + 'conf.d/configlmm.conf')
                        resolverIP = self.class.sshExec!(ssh, "cat /etc/resolv.conf | grep 'nameserver' | grep -v ':' | cut -d ' ' -f 2").strip
                        self.class.sshExec!(ssh, "sed -i 's|^resolver .*|resolver #{resolverIP};|' /etc/nginx/conf.d/configlmm.conf")

                        self.class.uploadFolder(dir + 'config-lmm', CONFIG_DIR, ssh)
                        self.class.uploadFolder(dir + 'servers-lmm', CONFIG_DIR, ssh)

                        template = ERB.new(File.read(__dir__ + '/main.conf.erb'))
                        renderTemplate(template, target, dir + 'main.conf', options)
                        ssh.scp.upload!(dir + 'main.conf', CONFIG_DIR + 'main.conf')

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
                updateTargetConfig(target)

                template = ERB.new(File.read(__dir__ + '/proxy.conf.erb'))
                renderTemplate(template, target, options['output'] + '/nginx/servers-lmm/' + target['Name'] + '.conf', options)

                actionNginxBuild(id, target, activeState, context, options)
            end

            def actionNginxProxyDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
