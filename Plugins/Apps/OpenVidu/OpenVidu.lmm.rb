
module ConfigLMM
    module LMM
        class OpenVidu < Framework::NginxApp

            USER = 'openvidu'
            HOME_DIR = '/var/lib/openvidu'
            HOST_IP = '10.0.2.2'

            def actionOpenViduDeploy(id, target, activeState, context, options)
                raise Framework::PluginProcessError.new('Domain field must be set!') unless target['Domain']
                raise Framework::PluginProcessError.new('CallDomain field must be set!') unless target['CallDomain']

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|

                        distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                        Framework::LinuxApp.configurePodmanServiceOverSSH(USER, HOME_DIR, 'OpenVidu', distroInfo, ssh)

                        secretKey = SecureRandom.alphanumeric(40)
                        bindIp = target['BindIP']
                        bindIp = '127.0.0.1' unless bindIp

                        path = Framework::LinuxApp::SYSTEMD_CONTAINERS_PATH.gsub('~', HOME_DIR)
                        self.class.exec("echo 'INGRESS_CONFIG_FILE=/etc/ingress.yaml' > #{path}/OpenVidu.env", ssh)
                        self.class.exec("echo 'LIVEKIT_URL=wss://#{target['Domain']}' >> #{path}/OpenVidu.env", ssh)
                        self.class.exec("echo 'LIVEKIT_API_KEY=Main' >> #{path}/OpenVidu.env", ssh)
                        self.class.exec("echo 'LIVEKIT_API_SECRET=#{secretKey}' >> #{path}/OpenVidu.env", ssh)
                        self.class.exec("echo 'CALL_PRIVATE_ACCESS=true' >> #{path}/OpenVidu.env", ssh)
                        self.class.exec("echo 'CALL_USER=guest' >> #{path}/OpenVidu.env", ssh)
                        callSecret = SecureRandom.alphanumeric(20)
                        prompt.say("OpenVidu Call guest password: #{callSecret}", :color => :magenta)
                        self.class.exec("echo 'CALL_SECRET=#{callSecret}' >> #{path}/OpenVidu.env", ssh)
                        self.class.exec("echo 'CALL_ADMIN_USER=admin' >> #{path}/OpenVidu.env", ssh)
                        callAdminSecret = SecureRandom.alphanumeric(20)
                        prompt.say("OpenVidu Call admin password: #{callAdminSecret}", :color => :magenta)
                        self.class.exec("echo 'CALL_ADMIN_SECRET=#{callAdminSecret}' >> #{path}/OpenVidu.env", ssh)

                        ssh.scp.upload!(__dir__ + '/livekit.yaml', HOME_DIR)
                        ssh.scp.upload!(__dir__ + '/ingress.yaml', HOME_DIR)

                        self.class.exec("sed -i 's|$SECRET|#{secretKey}|'  #{HOME_DIR}/livekit.yaml", ssh)

                        if target['Valkey']
                            self.class.exec("sed -i 's|10.0.2.2|#{target['Valkey']['Host']}|'  #{HOME_DIR}/ingress.yaml", ssh) if target['Valkey']['Host']
                        end
                        if ENV['VALKEY_PASSWORD']
                            self.class.exec("sed -i 's|password:|password: #{ENV['VALKEY_PASSWORD']}|'  #{HOME_DIR}/ingress.yaml", ssh)
                        end

                        self.class.exec("chown #{USER}:#{USER} #{path}/OpenVidu.env #{HOME_DIR}/livekit.yaml #{HOME_DIR}/ingress.yaml", ssh)
                        self.class.exec("chmod 600 #{path}/OpenVidu.env #{HOME_DIR}/livekit.yaml #{HOME_DIR}/ingress.yaml", ssh)

                        ssh.scp.upload!(__dir__ + '/OpenVidu.container', path)
                        ssh.scp.upload!(__dir__ + '/OpenViduCall.container', path)
                        ssh.scp.upload!(__dir__ + '/Ingress.container', path)

                        self.class.exec("sed -i 's|$BindIP|#{bindIp}|'  #{path}/OpenVidu.container", ssh)

                        Framework::LinuxApp.firewallAddPortOverSSH('7881/tcp', ssh)
                        Framework::LinuxApp.firewallAddPortOverSSH('7900-7999/udp', ssh)
                        Framework::LinuxApp.firewallAddPortOverSSH('45000-55000/udp', ssh)

                        self.class.exec("systemctl --user --machine=#{USER}@ daemon-reload", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart OpenVidu", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart OpenViduCall", ssh)
                        self.class.exec("systemctl --user --machine=#{USER}@ restart Ingress", ssh)

                        Framework::LinuxApp.ensurePackages([NGINX_PACKAGE], ssh)
                        Framework::LinuxApp.ensureServiceAutoStartOverSSH(NGINX_PACKAGE, ssh)
                        self.class.prepareNginxConfig(target, ssh)
                        target['CallDomain'] = Addressable::IDNA.to_ascii(target['CallDomain'])
                        self.writeNginxConfig(__dir__, 'OpenVidu', id, target, state, context, options)
                        self.writeNginxConfig(__dir__, 'OpenViduCall', id, target, state, context, options)
                        self.deployNginxConfig(id, target, activeState, context, options)
                        Framework::LinuxApp.startServiceOverSSH(NGINX_PACKAGE, ssh)

                    end
                else
                    # TODO
                end
            end

        end
    end
end

