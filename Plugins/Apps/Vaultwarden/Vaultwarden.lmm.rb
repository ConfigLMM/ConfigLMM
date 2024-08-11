
require 'fileutils'

module ConfigLMM
    module LMM
        class Vaultwarden < Framework::NginxApp

            NAME = 'Vaultwarden'
            USER = 'vaultwarden'
            HOME_DIR = '/var/lib/vaultwarden'

            def actionVaultwardenBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, NAME, id, target, state, context, options)
            end

            def actionVaultwardenDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionVaultwardenDeploy(id, target, activeState, context, options)
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    self.class.sshStart(uri) do |ssh|
                        if !target.key?('Proxy') || target['Proxy'] != 'only'
                            distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                            Framework::LinuxApp.configurePodmanServiceOverSSH(USER, HOME_DIR, 'Vaultwarden', distroInfo, ssh)
                            self.class.sshExec!(ssh, "su --login #{USER} --shell /bin/sh --command 'mkdir -p ~/data'")
                            path = Framework::LinuxApp::SYSTEMD_CONTAINERS_PATH.gsub('~', HOME_DIR)
                            self.class.sshExec!(ssh, "echo 'ROCKET_PORT=8000' > #{path}/Vaultwarden.env")
                            if target['Domain']
                                self.class.sshExec!(ssh, "echo 'DOMAIN=https://#{target['Domain']}' >> #{path}/Vaultwarden.env")
                            end
                            target['Signups'] = false unless target['Signups']
                            self.class.sshExec!(ssh, "echo 'SIGNUPS_ALLOWED=#{target['Signups'].to_s}' >> #{path}/Vaultwarden.env")
                            if target.key?('Invitations')
                                self.class.sshExec!(ssh, "echo 'INVITATIONS_ALLOWED=#{target['Invitations'].to_s}' >> #{path}/Vaultwarden.env")
                            end
                            if ENV.key?('VAULTWARDEN_ADMIN_TOKEN')
                                token = ENV['VAULTWARDEN_ADMIN_TOKEN']
                                token = SecureRandom.alphanumeric(40) if token.empty?
                                self.class.sshExec!(ssh, "echo 'ADMIN_TOKEN=#{token}' >> #{path}/Vaultwarden.env")
                            end
                            self.class.sshExec!(ssh, "chown #{USER}:#{USER} #{path}/Vaultwarden.env")
                            self.class.sshExec!(ssh, "chmod 600 #{path}/Vaultwarden.env")

                            ssh.scp.upload!(__dir__ + '/Vaultwarden.container', path)
                            self.class.sshExec!(ssh, "systemctl --user --machine=#{USER}@ daemon-reload")
                            self.class.sshExec!(ssh, "systemctl --user --machine=#{USER}@ start Vaultwarden")
                        end
                        if !target.key?('Proxy') || !!target['Proxy']
                            self.class.prepareNginxConfig(target, ssh)
                            writeNginxConfig(__dir__, NAME, id, target, state, context, options)
                            deployNginxConfig(id, target, activeState, context, options)
                        end
                    end
                else
                    # TODO
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
