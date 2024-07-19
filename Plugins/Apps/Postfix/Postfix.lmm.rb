
module ConfigLMM
    module LMM
        class Postfix < Framework::Plugin
            PACKAGE_NAME = 'Postfix'
            SERVICE_NAME = 'postfix'
            MASTER_FILE = '/etc/postfix/master.cf'
            MAIN_FILE = '/etc/postfix/main.cf'
            TRANSPORT_FILE = '/etc/postfix/transport'

            def actionPostfixDeploy(id, target, activeState, context, options)
                plugins[:Linux].ensurePackage(PACKAGE_NAME, target['Location'])
                plugins[:Linux].ensureServiceAutoStart(SERVICE_NAME, target['Location'])

                deploySettings(target, target['Location'], options)

                plugins[:Linux].startService(SERVICE_NAME, target['Location'])
            end

            def deploySettings(target, location, options)
                if location && location != '@me'
                    if target['AlternativePort']
                        updateRemoteFile(location, MASTER_FILE, options, true) do |fileLines|
                            fileLines << "#{target['AlternativePort']}      inet  n       -       n       -       -       smtpd\n"
                        end
                    end
                    self.class.sshStart(location) do |ssh|
                        domain = self.class.sshExec!(ssh, "hostname --fqdn").strip
                        command = "sed -i 's|^myhostname = .*|myhostname = #{domain}|' #{MAIN_FILE}"
                        command = "sed -i 's|^#myhostname = virtual.domain.tld|myhostname = #{domain}|' #{MAIN_FILE}"
                        self.class.sshExec!(ssh, command)
                    end
                    if target['Settings']
                        target['Settings'].each do |name, value|
                            self.class.sshStart(location) do |ssh|
                                command = "sed -i 's|^#{name} =.*|#{name} = #{value}|' #{MAIN_FILE}"
                                self.class.sshExec!(ssh, command)
                            end
                        end
                    end
                    if target['ForwardAll']
                        updateRemoteFile(location, TRANSPORT_FILE, options, true) do |fileLines|
                            hostname, port = target['ForwardAll'].split(':')
                            hostname = '[' + hostname + ']'
                            line = '* smtp:' + hostname
                            line += ':' + port if port
                            fileLines << line + "\n"
                        end
                        self.class.sshStart(location) do |ssh|
                            self.class.sshExec!(ssh, "postmap #{TRANSPORT_FILE}")
                        end
                    end
                else
                    if target['AlternativePort']
                        updateLocalFile(MASTER_FILE, options, true) do |fileLines|
                            fileLines << "#{target['AlternativePort']}      inet  n       -       n       -       -       smtpd\n"
                        end
                    end
                    if target['Settings']
                        target['Settings'].each do |name, value|
                            `sed -i 's|^#{name} =.*|#{name} = #{value}|' #{MAIN_FILE}`
                        end
                    end
                    if target['ForwardAll']
                        updateLocalFile(TRANSPORT_FILE, options, true) do |fileLines|
                            fileLines << '* smtp:[' + target['ForwardAll'] + "]\n"
                        end
                        `postmap #{TRANSPORT_FILE}`
                    end
                end
            end

        end

    end
end
