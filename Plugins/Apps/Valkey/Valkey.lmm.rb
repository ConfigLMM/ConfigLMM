
module ConfigLMM
    module LMM
        class Valkey < Framework::LinuxApp
            PACKAGE_NAME = 'Valkey'
            CONFIG_FILE = '/etc/redis/redis.conf'
            PID_FILE = '/run/redis/redis.pid'

            def actionValkeyDeploy(id, target, activeState, context, options)
                self.ensurePackage(PACKAGE_NAME, target['Location'])

                serviceName = 'redis'

                if target['Location'] && target['Location'] != '@me'
                    self.class.sshStart(target['Location']) do |ssh|
                        distroId = self.class.distroIDfromSSH(ssh)
                        if distroId == SUSE_ID
                            serviceName = 'redis@redis'
                            self.class.sshExec!(ssh, "touch #{CONFIG_FILE}")

                            target['Settings'] ||= {}
                            target['Settings']['pidfile'] = PID_FILE
                            target['Settings']['supervised'] = 'systemd'
                            target['Settings']['dir'] = '/var/lib/redis/default/'
                        end

                        if target['Settings']
                            updateRemoteFile(ssh, CONFIG_FILE, options, false) do |configLines|
                                target['Settings'].each do |name, value|
                                    configLines << "#{name} #{value}\n"
                                end
                                configLines
                            end
                        end
                    end
                else
                    if target['Settings']
                        `touch #{CONFIG_FILE}`
                        updateLocalFile(CONFIG_FILE, options) do |configLines|
                            target['Settings'].each do |name, value|
                                configLines << "#{name} #{value}\n"
                            end
                            configLines
                        end
                    end
                end

                self.ensureServiceAutoStart(serviceName, target['Location'])
                self.startService(serviceName, target['Location'])
            end

        end

    end
end
