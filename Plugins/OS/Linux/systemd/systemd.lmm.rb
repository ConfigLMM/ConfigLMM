
module ConfigLMM
    module LMM
        class Systemd < Framework::LinuxApp

            SYSTEMD_CONFIG_PATH = '/etc/systemd/system/'
            USER_SERVICE_DIR = '/etc/systemd/system/user@.service.d/'

            def actionSystemdDeploy(id, target, activeState, context, options)
                if target['Location'] && target['Location'] != '@me'
                    if target['UserCgroups']
                        uri = Addressable::URI.parse(target['Location'])
                        raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                        self.class.sshStart(uri) do |ssh|
                            self.class.sshExec!(ssh, "mkdir -p #{USER_SERVICE_DIR}")
                            ssh.scp.upload!(__dir__ + '/user-0.slice', SYSTEMD_CONFIG_PATH)
                            ssh.scp.upload!(__dir__ + '/user@.service.d/delegate.conf', USER_SERVICE_DIR)
                        end
                    end
                else
                    # TODO
                end

            end

        end
    end
end
