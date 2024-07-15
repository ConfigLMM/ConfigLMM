
require 'http'
require 'securerandom'

module ConfigLMM
    module LMM
        class Linux < Framework::Plugin

            ISO_LOCATION = '~/.cache/configlmm/images/'
            HOSTS_FILE = '/etc/hosts'
            HOSTS_SECTION_BEGIN = "# -----BEGIN CONFIGLMM-----\n"
            HOSTS_SECTION_END   = "# -----END CONFIGLMM-----\n"
            SUSE_NAME = 'openSUSE Leap'

            def actionLinuxBuild(id, target, activeState, context, options)
                buildHostsFile(target, options)
                buildAutoYaST(id, target, options)
            end

            def actionLinuxDeploy(id, target, activeState, context, options)
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    case uri.scheme
                    when 'qemu'
                        location = Libvirt.getLocation(target['Location'])
                        iso = installationISO(target['Distro'], location)
                        iso = buildISOAutoYaST(id, iso, target, options) if target['Distro'] == SUSE_NAME
                        plugins[:Libvirt].createVM(target['Name'], target, target['Location'], iso, activeState)
                    else
                        raise Framework::PluginProcessError.new("#{id}: Unknown protocol: #{uri.scheme}!")
                    end
                else
                    deployLocalHostsFile(target, options)
                end
            end

            def buildHostsFile(target, options)
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

            def buildAutoYaST(id, target, options)
                if target['Distro'] == SUSE_NAME
                    outputFolder = options['output'] + '/' + id + '/'
                    template = ERB.new(File.read(__dir__ + '/openSUSE/autoinst.xml.erb'))
                    if ENV['LINUX_ROOT_PASSWORD_HASH']
                        target['RootPasswordHash'] = ENV['LINUX_ROOT_PASSWORD_HASH']
                    elsif ENV['LINUX_ROOT_PASSWORD']
                        target['RootPassword'] = ENV['LINUX_ROOT_PASSWORD']
                    elsif !target['RootPassword'] && !target['RootPasswordHash']
                        rootPassword = SecureRandom.urlsafe_base64(12)
                        prompt.say("Root password: #{rootPassword}", :color => :magenta)
                        target['RootPasswordHash'] = self.class.linuxPasswordHash(rootPassword)
                    elsif target['RootPassword'] == 'no'
                        target.delete('RootPassword')
                    end
                    renderTemplate(template, target, outputFolder + 'autoinst.xml', options)
                end
            end

            def deployLocalHostsFile(target, options)
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

            def installationISO(distro, location)
                url = nil
                case distro
                when SUSE_NAME
                    if location.empty?
                        # TODO automatically fetch latest version from website
                        url = 'https://download.opensuse.org/distribution/leap/15.6/iso/openSUSE-Leap-15.6-NET-x86_64-Media.iso'
                    else
                        raise Framework::PluginProcessError.new("#{id}: Unimplemented!")
                    end
                else
                    raise Framework::PluginProcessError.new("#{id}: Unknown Linux Distro: #{distro}!")
                end

                filename = File.basename(Addressable::URI.parse(url).path)
                iso = File.expand_path(ISO_LOCATION + filename)
                if !File.exist?(iso)
                    mkdir(File.expand_path(ISO_LOCATION), false)
                    prompt.say('Downloading... ' + url)
                    response = HTTP.follow.get(url)
                    raise "Failed to download file: #{response.status}" unless response.status.success?
                    File.open(iso, 'wb') do |file|
                        response.body.each do |chunk|
                            file.write(chunk)
                        end
                    end
                end
                iso
            end

            def buildISOAutoYaST(id, iso, target, options)
                outputFolder = options['output'] + '/iso/'
                mkdir(outputFolder, false)
                `xorriso -osirrox on -indev #{iso} -extract / #{outputFolder} 2>&1 >/dev/null`
                FileUtils.chmod_R(0750, outputFolder) # Need to make it writeable so it can be deleted
                copy(options['output'] + '/' + id + '/autoinst.xml', outputFolder, false)

                cfg = outputFolder + "boot/x86_64/loader/isolinux.cfg"
                `sed -i 's|default harddisk|default linux|' #{cfg}`
                `sed -i 's|append initrd=initrd splash=silent showopts|append initrd=initrd splash=silent autoyast=device://sr0/autoinst.xml|' #{cfg}`
                `sed -i 's|prompt		1|prompt		0|' #{cfg}`
                `sed -i 's|timeout		600|timeout		1|' #{cfg}`

                patchedIso = File.dirname(iso) + '/patched.iso'
                `xorriso -as mkisofs -no-emul-boot -boot-load-size 4 -boot-info-table -iso-level 4 -b boot/x86_64/loader/isolinux.bin -c boot/x86_64/loader/boot.cat -eltorito-alt-boot -e boot/x86_64/efi -no-emul-boot -o #{patchedIso} #{outputFolder} 2>&1 >/dev/null`
                patchedIso
            end

            def self.linuxPasswordHash(password)
                salt = SecureRandom.alphanumeric(16)
                password.crypt('$6$' + salt)
            end
        end
    end
end
