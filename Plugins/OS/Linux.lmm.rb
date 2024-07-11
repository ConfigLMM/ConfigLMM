
module ConfigLMM
    module LMM
        class Linux < Framework::Plugin

            HOSTS_FILE = '/etc/hosts'
            HOSTS_SECTION_BEGIN = "# -----BEGIN CONFIGLMM-----\n"
            HOSTS_SECTION_END   = "# -----END CONFIGLMM-----\n"

            def actionLinuxBuild(id, target, activeState, context, options)
                if target['Hosts']
                    hosts  = "#\n"
                    hosts += "# /etc/hosts: static lookup table for host names\n"
                    hosts += "#\n\n"
                    hosts += "#<ip-address>   <hostname.domain.org>   <hostname>\n"
                    hosts += "127.0.0.1       localhost\n"
                    hosts += "::1             localhost\n\n"
                    hosts += HOSTS_SECTION_BEGIN
                    target['Hosts'].each do |ip, entries|
                        hosts += ip.ljust(16) + entries.join(' ') + "\n"
                    end
                    hosts += HOSTS_SECTION_END

                    mkdir(options['output'] + '/etc', options[:dry])
                    fileWrite(options['output'] + HOSTS_FILE, hosts, options[:dry])
                end
            end

            def actionLinuxDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    if target['Hosts']
                        hostsLines = File.read(HOSTS_FILE).lines
                        sectionBeginIndex = hostsLines.index(HOSTS_SECTION_BEGIN)
                        sectionEndIndex = hostsLines.index(HOSTS_SECTION_END)
                        if sectionBeginIndex.nil?
                            linesBefore = hostsLines
                            linesBefore << "\n"
                            linesBefore << HOSTS_SECTION_BEGIN
                            linesAfter = [HOSTS_SECTION_END]
                            linesAfter << "\n"
                        else
                            linesBefore = hostsLines[0..sectionBeginIndex]
                            if sectionEndIndex.nil?
                                linesAfter = [HOSTS_SECTION_END]
                                linesAfter << "\n"
                            else
                                linesAfter = hostsLines[sectionEndIndex..hostsLines.length]
                            end
                        end

                        hostsLines = linesBefore
                        target['Hosts'].each do |ip, entries|
                            hostsLines << ip.ljust(16) + entries.join(' ') + "\n"
                        end
                        hostsLines += linesAfter

                        fileWrite(HOSTS_FILE, hostsLines.join(), options[:dry])
                    end
                end
            end

        end
    end
end
