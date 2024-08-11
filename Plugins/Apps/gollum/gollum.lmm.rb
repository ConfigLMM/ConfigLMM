
module ConfigLMM
    module LMM
        class Gollum < Framework::NginxApp

            NAME = 'gollum'
            USER = 'gollum'
            GOLLUM_PATH = '/srv/gollum'
            HOME_DIR = '/var/lib/authentik'

            def actionGollumBuild(id, target, activeState, context, options)
                writeNginxConfig(__dir__, NAME, id, target, activeState, context, options)
                targetDir = options['output'] + GOLLUM_PATH
                mkdir(targetDir, options['dry'])
                copy(__dir__ + '/config.ru', targetDir, options['dry'])
                `git init #{targetDir}/repo`
            end

            def actionGollumRefresh(id, target, activeState, context, options)
                # Would need to parse deployed config to implement
            end

            def actionGollumDeploy(id, target, activeState, context, options)
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    self.class.sshStart(uri) do |ssh|
                        if !target.key?('Proxy') || !!target['Proxy']
                            self.class.prepareNginxConfig(target, ssh)
                            if !target['Root']
                                gollumPath = ssh.exec!('gem which gollum').strip
                                target['Root'] = File.dirname(gollumPath) + '/gollum/public'
                            end
                            writeNginxConfig(__dir__, NAME, id, target, state, context, options)
                            deployNginxConfig(id, target, activeState, context, options)
                        end
                        if !target.key?('Proxy') || target['Proxy'] != 'only'
                            distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                            Framework::LinuxApp.configurePodmanServiceOverSSH(USER, GOLLUM_PATH, 'gollum', distroInfo, ssh)
                            self.class.uploadFolder(options['output'] + GOLLUM_PATH, '/srv', ssh)
                            path = Framework::LinuxApp::SYSTEMD_CONTAINERS_PATH.gsub('~', GOLLUM_PATH)
                            ssh.scp.upload!(__dir__ + '/gollum.container', path)
                            self.class.sshExec!(ssh, "chown -R #{USER}:#{USER} #{GOLLUM_PATH}")
                            self.class.sshExec!(ssh, "systemctl --user --machine=#{USER}@ daemon-reload")
                            self.class.sshExec!(ssh, "systemctl --user --machine=#{USER}@ start gollum")
                        end
                    end
                else
                    targetDir = GOLLUM_PATH
                    mkdir(targetDir, options['dry'])
                    if !target.key?('Proxy') || !!target['Proxy']
                        self.class.prepareNginxConfig(target)
                        if !target['Root']
                            target['Root'] = File.dirname(`gem which gollum`.strip) + '/gollum/public'
                        end
                        writeNginxConfig(__dir__, NAME, id, target, state, context, options)
                        deployNginxConfig(id, target, activeState, context, options)
                    end
                    if !target.key?('Proxy') || target['Proxy'] != 'only'
                        copy(options['output'] + GOLLUM_PATH + '/config.ru', GOLLUM_PATH, options['dry'])
                        copyNotPresent(options['output'] + GOLLUM_PATH + '/repo', GOLLUM_PATH, options['dry'])
                        chown('http', 'http', GOLLUM_PATH, options['dry'])
                    end
                    activeState['Location'] = '@me'
                end
            end

            def cleanup(configs, state, context, options)
                items = state.selectType(:Gollum)
                items.each do |id, item|
                    if !configs.key?(id)
                        if item['Location'] == '@me'
                            cleanupNginxConfig(NAME, id, state, context, options)
                        else
                            # TODO
                        end
                    end
                end
            end
        end
    end
end
