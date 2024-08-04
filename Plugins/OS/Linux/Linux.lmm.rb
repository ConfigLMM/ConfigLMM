
require 'addressable/uri'
require 'http'
require 'securerandom'
require 'shellwords'

module ConfigLMM
    module LMM
        class Linux < Framework::LinuxApp

            ISO_LOCATION = '~/.cache/configlmm/images/'
            HOSTS_FILE = '/etc/hosts'
            FSTAB_FILE = '/etc/fstab'
            SSH_CONFIG = '~/.ssh/config'
            SYSCTL_FILE = '/etc/sysctl.d/90-configlmm.conf'
            FIREWALL_PACKAGE = 'firewalld'
            FIREWALL_SERVICE = 'firewalld'

            def actionLinuxBuild(id, target, activeState, context, options)
                prepareConfig(target)
                buildHostsFile(id, target, options)
                buildSSHConfig(id, target, options)
                buildAutoYaST(id, target, options)
            end

            def actionLinuxDeploy(id, target, activeState, context, options)
                prepareConfig(target)
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    case uri.scheme
                    when 'qemu'
                        deployOverLibvirt(id, target, activeState, context, options)
                    when 'ssh'
                        deployOverSSH(uri, id, target, activeState, context, options)
                    else
                        raise Framework::PluginProcessError.new("#{id}: Unknown protocol: #{uri.scheme}!")
                    end
                else
                    deployLocalHostsFile(target, options)
                    deployLocalSSHConfig(target, options)
                    if target['Firewall'] && target['Firewall'] != 'no'
                        self.ensurePackage(FIREWALL_PACKAGE, locationUri)
                        self.ensureServiceAutoStart(FIREWALL_SERVICE, locationUri)
                        self.startService(FIREWALL_SERVICE, locationUri)
                    end
                end
                if target['AlternativeLocation']
                    uri = Addressable::URI.parse(target['AlternativeLocation'])
                    raise Framework::PluginProcessError.new("#{id}: Unsupported protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    deployOverSSH(uri, id, target, activeState, context, options)
                end
            end

            def deployOverSSH(locationUri, id, target, activeState, context, options)
                if target['Domain'] || target['Hosts']
                    hostsLines = []
                    if target['Domain']
                        self.class.sshStart(locationUri) do |ssh|
                            envs = self.class.sshExec!(ssh, "env").split("\n")
                            envVars = Hash[envs.map { |vars| vars.split('=', 2) }]
                            ipAddr = envVars['SSH_CONNECTION'].split[-2]
                            hostsLines << ipAddr.ljust(16) + target['Domain'] + ' ' + target['Name'] + "\n"
                        end
                    end
                    target['Hosts'].to_a.each do |ip, entries|
                            hostsLines << ip.ljust(16) + entries.join(' ') + "\n"
                    end
                    updateRemoteFile(locationUri, HOSTS_FILE, options, false) do |fileLines|
                        fileLines + hostsLines
                    end
                end
                if target['Tmpfs']
                    self.class.sshStart(locationUri) do |ssh|
                        self.class.sshExec!(ssh, "sed -i '/ \\/tmp /d' #{FSTAB_FILE}")
                        updateRemoteFile(ssh, FSTAB_FILE, options, false) do |fileLines|
                            fileLines << "tmpfs                                      /tmp                    tmpfs  nodev,nosuid,size=#{target['Tmpfs']}          0  0\n"
                        end
                    end
                end
                if target['Sysctl']
                    updateRemoteFile(locationUri, SYSCTL_FILE, options, false) do |fileLines|
                        target['Sysctl'].each do |name, value|
                            fileLines << "#{name} = #{value}\n"
                        end
                        fileLines
                    end
                end
                if target['Firewall'] && target['Firewall'] != 'no'
                    self.ensurePackage(FIREWALL_PACKAGE, locationUri)
                    self.ensureServiceAutoStart(FIREWALL_SERVICE, locationUri)
                    self.startService(FIREWALL_SERVICE, locationUri)
                end
            end

            def deployOverLibvirt(id, target, activeState, context, options)
                location = Libvirt.getLocation(target['Location'])
                iso = installationISO(target['Distro'], location)
                iso = buildISOAutoYaST(id, iso, target, options) if target['Distro'] == SUSE_NAME
                plugins[:Libvirt].createVM(target['Name'], target, target['Location'], iso, activeState)
            end

            def buildHostsFile(id, target, options)
                if target['Hosts']
                    hosts  = "#\n"
                    hosts += "# /etc/hosts: static lookup table for host names\n"
                    hosts += "#\n\n"
                    hosts += "#<ip-address>   <hostname.domain.org>   <hostname>\n"
                    hosts += "127.0.0.1       localhost\n"
                    hosts += "::1             localhost\n\n"
                    hosts += CONFIGLMM_SECTION_BEGIN
                    target['Hosts'].each do |ip, entries|
                        hosts += ip.ljust(16) + entries.join(' ') + "\n"
                    end
                    hosts += CONFIGLMM_SECTION_END

                    path = options['output'] + '/' + id
                    mkdir(path + '/etc', options[:dry])
                    fileWrite(path + HOSTS_FILE, hosts, options[:dry])
                end
            end

            def buildSSHConfig(id, target, options)
                if !target['SSH']['Config'].empty?
                    sshConfig  = "\n"
                    sshConfig += CONFIGLMM_SECTION_BEGIN
                    target['SSH']['Config'].each do |name, info|
                        sshConfig += "Host #{name} #{info['HostName']}\n"
                        sshConfig += "    HostName " + info['HostName'] + "\n" if info['HostName']
                        sshConfig += "    Port " + info['Port'] + "\n" if info['Port']
                        sshConfig += "    User " + info['User'] + "\n" if info['User']
                        sshConfig += "    IdentityFile " + info['IdentityFile'] + "\n" if info['IdentityFile']
                        sshConfig += "\n"
                    end
                    sshConfig += CONFIGLMM_SECTION_END
                    sshConfig += "\n"

                    configPath = options['output'] + '/' + id
                    mkdir(configPath + '/root/.ssh', options[:dry])
                    fileWrite(configPath + SSH_CONFIG.gsub('~', '/root'), sshConfig, options[:dry])
                end
            end

            def buildAutoYaST(id, target, options)
                if target['Distro'] == SUSE_NAME
                    outputFolder = options['output'] + '/' + id + '/'
                    template = ERB.new(File.read(__dir__ + '/openSUSE/autoinst.xml.erb'))
                    renderTemplate(template, target, outputFolder + 'autoinst.xml', options)
                end
            end

            def deployLocalHostsFile(target, options)
                if target['Hosts']
                    updateLocalFile(HOSTS_FILE, options) do |hostsLines|
                        target['Hosts'].each do |ip, entries|
                            hostsLines << ip.ljust(16) + entries.join(' ') + "\n"
                        end
                        hostsLines
                    end
                end
            end

            def deployLocalSSHConfig(target, options)
                if !target['SSH']['Config'].empty?
                    updateLocalFile(File.expand_path(SSH_CONFIG), options) do |configLines|
                        target['SSH']['Config'].each do |name, info|
                            configLines << "Host #{name} #{info['HostName']}\n"
                            configLines << "    HostName " + info['HostName'] + "\n" if info['HostName']
                            configLines << "    Port " + info['Port'] + "\n" if info['Port']
                            configLines << "    User " + info['User'] + "\n" if info['User']
                            configLines << "    IdentityFile " + info['IdentityFile'] + "\n" if info['IdentityFile']
                        end
                        configLines
                    end
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

            def prepareConfig(target)
                target['SSH'] ||= {}
                target['SSH']['Config'] ||= {}
                target['Users'] ||= {}
                target['HostName'] = target['Name'] unless target['HostName']

                if ENV['LINUX_ROOT_PASSWORD_HASH']
                    target['Users']['root'] ||= {}
                    target['Users']['root']['PasswordHash'] = ENV['LINUX_ROOT_PASSWORD_HASH']
                elsif ENV['LINUX_ROOT_PASSWORD']
                    target['Users']['root'] ||= {}
                    target['Users']['root']['PasswordHash'] = self.class.linuxPasswordHash(ENV['LINUX_ROOT_PASSWORD'])
                elsif target['Users'].key?('root')
                    if !target['Users']['root']['Password'] &&
                       !target['Users']['root']['PasswordHash']
                        rootPassword = SecureRandom.urlsafe_base64(12)
                        prompt.say("Root password: #{rootPassword}", :color => :magenta)
                        target['Users']['root']['PasswordHash'] = self.class.linuxPasswordHash(rootPassword)
                    elsif target['Users']['root']['Password'] == 'no'
                        target['Users']['root'].delete('Password')
                    end
                end

                target['Users'].each do |user, info|
                    newKeys = []
                    info['AuthorizedKeys'].to_a.each do |key|
                        if key.start_with?('/') || key.start_with?('~')
                            newKeys << File.read(File.expand_path(key)).strip
                        else
                            newKeys << key
                        end
                    end
                    info['AuthorizedKeys'] = newKeys
                end

                packages = YAML.load_file(__dir__ + '/Packages.yaml')
                newApps = []
                target['Services'] ||= []
                if target['Apps'].to_a.include?('sshd')
                    target['Services'] << 'sshd'
                    target['Services'].uniq!
                end
                target['Apps'] = self.class.mapPackages(target['Apps'], target['Distro'])
            end

            def self.linuxPasswordHash(password)
                salt = SecureRandom.alphanumeric(16)
                password.crypt('$6$' + salt)
            end

        end
    end
end
