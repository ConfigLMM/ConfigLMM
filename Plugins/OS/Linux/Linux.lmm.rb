
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
                buildAutoInstall(id, target, options)
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
                    deployLocal(target, options)
                end
                if target['AlternativeLocation']
                    uri = Addressable::URI.parse(target['AlternativeLocation'])
                    raise Framework::PluginProcessError.new("#{id}: Unsupported protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    deployOverSSH(uri, id, target, activeState, context, options)
                end
            end

            def deployOverSSH(locationUri, id, target, activeState, context, options)
                self.class.sshStart(locationUri) do |ssh|
                    if target['Domain'] || target['Hosts']
                        hostsLines = []
                        if target['Domain']
                            envs = self.class.sshExec!(ssh, "env").split("\n")
                            envVars = Hash[envs.map { |vars| vars.split('=', 2) }]
                            ipAddr = envVars['SSH_CONNECTION'].split[-2]
                            hostsLines << ipAddr.ljust(16) + target['Domain'] + ' ' + target['Name'] + "\n"
                        end
                        target['Hosts'].to_a.each do |ip, entries|
                            hostsLines << ip.ljust(16) + entries.join(' ') + "\n"
                        end
                        updateRemoteFile(ssh, HOSTS_FILE, options, false) do |fileLines|
                            fileLines + hostsLines
                        end
                    end
                    distroInfo = self.class.currentDistroInfo(ssh)
                    if target['Network']
                        if distroInfo['Name'] == 'openSUSE Leap'
                            updateNetworkInterface(target['Network'], 'eth0', ssh, options)
                            if target['Network']['Interfaces']
                                target['Network']['Interfaces'].each do |interface, config|
                                    updateNetworkInterface(config, interface, ssh, options)
                                end
                            end
                            if target['Network']['DNS']
                                configFile = '/etc/sysconfig/network/config'
                                dns = target['Network']['DNS']
                                dns = [dns] unless dns.is_a?(Array)
                                self.class.sshExec!(ssh, "sed -i 's|^NETCONFIG_DNS_STATIC_SERVERS=.*|NETCONFIG_DNS_STATIC_SERVERS=\"#{dns.join(' ')}\"|' #{configFile}")
                            end
                            if target['Network']['Gateway']
                                routesFile = '/etc/sysconfig/network/routes'
                                self.class.sshExec!(ssh, "sed -i 's|^default |#default |' #{routesFile}")
                                updateRemoteFile(ssh, routesFile, options) do |fileLines|
                                    fileLines << "default #{target['Network']['Gateway']}\n"
                                end
                            end
                        else
                            # TODO
                            raise 'Not Unimplemented!'
                        end
                    end
                    if target['Tmpfs']
                        self.class.sshExec!(ssh, "sed -i '/ \\/tmp /d' #{FSTAB_FILE}")
                        updateRemoteFile(ssh, FSTAB_FILE, options, false) do |fileLines|
                            fileLines << "tmpfs                                      /tmp                    tmpfs  nodev,nosuid,size=#{target['Tmpfs']}          0  0\n"
                        end
                    end
                    if target['Sysctl']
                        updateRemoteFile(ssh, SYSCTL_FILE, options, false) do |fileLines|
                            target['Sysctl'].each do |name, value|
                                fileLines << "#{name} = #{value}\n"
                                self.class.sshExec!(ssh, "sysctl #{name}=#{value}")
                            end
                            fileLines
                        end
                    end
                    if target['Users']
                        target['Users'].each do |name, info|
                            userId = ssh.exec!("id -u #{name} 2>/dev/null").strip
                            if userId.empty?
                                shell = ''
                                if info['Shell']
                                    shell = "--shell '/usr/bin/#{info['Shell']}'"
                                end
                                badname = '--badname'
                                badname = '--badnames' if distroInfo['Name'] == 'openSUSE Leap'
                                self.class.sshExec!(ssh, "useradd #{badname} --create-home --user-group #{shell} #{name}")
                            end
                            homeDir = self.class.sshExec!(ssh, "getent passwd #{name} | cut -d ':' -f 6").strip
                            keyFile = homeDir + "/.ssh/id_ed25519"
                            if info['SSHKey'] && !self.class.remoteFilePresent?(keyFile, ssh)
                                self.class.sshExec!(ssh, "mkdir -p #{homeDir}/.ssh")
                                self.class.sshExec!(ssh, "ssh-keygen -t ed25519 -f #{keyFile} -P ''")
                                self.class.sshExec!(ssh, "chown -R #{name}:#{name} #{homeDir}/.ssh")
                            end
                        end
                    end
                    self.executeCommands(target['Execute'], ssh)
                end
                if target['Firewall'] && target['Firewall'] != 'no'
                    self.ensurePackage(FIREWALL_PACKAGE, locationUri)
                    self.ensureServiceAutoStart(FIREWALL_SERVICE, locationUri)
                    self.startService(FIREWALL_SERVICE, locationUri)
                end
            end

            def updateNetworkInterface(config, interface, ssh, options)
                baseFile = '/etc/sysconfig/network/ifcfg-'
                networkFile = baseFile + interface
                self.class.sshExec!(ssh, "touch #{networkFile}")
                self.class.sshExec!(ssh, "sed -i \"/^BOOTPROTO=.*/d\" #{networkFile}")
                self.class.sshExec!(ssh, "sed -i \"/^STARTMODE=.*/d\" #{networkFile}")
                self.class.sshExec!(ssh, "sed -i \"/^ZONE=.*/d\" #{networkFile}")
                updateRemoteFile(ssh, networkFile, options, false) do |fileLines|
                    fileLines << "STARTMODE=auto\n"
                    fileLines << "ZONE=public\n"
                    if config == 'dhcp'
                        fileLines << "BOOTPROTO=dhcp\n"
                    else
                        fileLines << "BOOTPROTO=static\n"
                        fileLines << "\n"
                        if config['IP']
                            self.class.sshExec!(ssh, "sed -i 's|^IPADDR=|#IPADDR=|' #{networkFile}")
                            if config['IP'].is_a?(Array)
                                config['IP'].each_with_index do |ip, i|
                                    c = "_#{i}"
                                    c = '' if i.zero?
                                    fileLines << "IPADDR#{c}=#{ip}\n"
                                end
                            else
                                fileLines << "IPADDR=#{config['IP']}\n"
                            end
                        end
                    end
                    fileLines
                end
            end

            def deployLocal(target, options)
                deployLocalHostsFile(target, options)
                deployLocalSSHConfig(target, options)
                if target['Sysctl']
                    updateLocalFile(SYSCTL_FILE, options) do |fileLines|
                        target['Sysctl'].each do |name, value|
                            fileLines << "#{name} = #{value}\n"
                            `sysctl #{name}=#{value}`
                        end
                        fileLines
                    end
                end
                if target['Users']
                    target['Users'].each do |name, info|
                        userId = self.class.exec("id -u #{name} 2>/dev/null", nil, true).strip
                        if userId.empty?
                            shell = ''
                            if info['Shell']
                                shell = "--shell '/usr/bin/#{info['Shell']}'"
                            end
                            distroInfo = self.class.currentDistroInfo(nil)
                            badname = '--badname'
                            badname = '--badnames' if distroInfo['Name'] == 'openSUSE Leap'
                            self.class.exec("useradd #{badname} --create-home --user-group #{shell} #{name}")
                        end
                        homeDir = self.class.exec("getent passwd #{name} | cut -d ':' -f 6").strip
                        keyFile = homeDir + "/.ssh/id_ed25519"
                        if info['SSHKey'] && !self.class.filePresent?(keyFile)
                            self.class.exec("mkdir -p #{homeDir}/.ssh")
                            self.class.exec("ssh-keygen -t ed25519 -f #{keyFile} -P ''")
                            self.class.exec("chown -R #{name}:#{name} #{homeDir}/.ssh")
                        end
                    end
                end
                if target['Firewall'] && target['Firewall'] != 'no'
                    self.ensurePackage(FIREWALL_PACKAGE, locationUri)
                    self.ensureServiceAutoStart(FIREWALL_SERVICE, locationUri)
                    self.startService(FIREWALL_SERVICE, locationUri)
                end
                self.executeCommands(target['Execute'])
            end

            def executeCommands(commands, ssh = nil)
                return unless commands

                commands.each do |type, data|
                    case type
                    when 'sh'
                        data = [data] unless data.is_a?(Array)
                        data.each do |cmd|
                            self.class.exec(cmd, ssh)
                        end
                    else
                        raise 'Unimplemented!'
                    end
                end
            end

            def deployOverLibvirt(id, target, activeState, context, options)
                location = Libvirt.getLocation(target['Location'])
                iso = installationISO(target['Distro'], target['Flavour'], location)
                iso = buildAutoInstallISO(id, iso, target, options)
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

            def buildAutoInstall(id, target, options)
                if target['Flavour'] == PROXMOXVE_NAME
                    outputFolder = options['output'] + '/' + id + '/'
                    template = ERB.new(File.read(__dir__ + '/Proxmox/answer.toml.erb'))
                    renderTemplate(template, target, outputFolder + 'answer.toml', options)
                    File.write("#{outputFolder}/auto-installer-mode.toml", 'mode = "iso"')
                elsif target['Distro'] == SUSE_NAME
                    outputFolder = options['output'] + '/' + id + '/'
                    template = ERB.new(File.read(__dir__ + '/openSUSE/autoinst.xml.erb'))
                    renderTemplate(template, target, outputFolder + 'autoinst.xml', options)
                elsif target['Distro'] == DEBIAN_NAME
                    outputFolder = options['output'] + '/' + id + '/'
                    template = ERB.new(File.read(__dir__ + '/Debian/preseed.cfg.erb'))
                    renderTemplate(template, target, outputFolder + 'preseed.cfg', options)
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

            def installationISO(distro, flavour, location)
                url = nil
                flavour = distro unless flavour
                flavourInfo = YAML.load_file(__dir__ + '/Flavours.yaml')[flavour]
                if flavourInfo.nil?
                    raise Framework::PluginProcessError.new("#{id}: Unknown Linux Distro: #{flavour}!")
                end
                url = flavourInfo['ISO']
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

            def buildAutoInstallISO(id, iso, target, options)
                if target['Flavour'] == PROXMOXVE_NAME
                    iso = buildISOAutoProxmox(id, iso, target, options)
                elsif target['Distro'] == SUSE_NAME
                    iso = buildISOAutoYaST(id, iso, target, options)
                elsif target['Distro'] == DEBIAN_NAME
                    iso = buildISOPreseed(id, iso, target, options)
                end
                iso
            end

            def buildISOAutoYaST(id, iso, target, options)
                outputFolder = options['output'] + '/iso/'
                mkdir(outputFolder, false)
                self.class.exec("xorriso -osirrox on -indev #{iso} -extract / #{outputFolder}")
                FileUtils.chmod_R(0750, outputFolder) # Need to make it writeable so it can be deleted
                copy(options['output'] + '/' + id + '/autoinst.xml', outputFolder, false)

                cfg = outputFolder + "boot/x86_64/loader/isolinux.cfg"
                self.class.exec("sed -i 's|default harddisk|default linux|' #{cfg}")
                self.class.exec("sed -i 's|append initrd=initrd splash=silent showopts|append initrd=initrd splash=silent autoyast=device://sr0/autoinst.xml|' #{cfg}")
                self.class.exec("sed -i 's|prompt		1|prompt		0|' #{cfg}")
                self.class.exec("sed -i 's|timeout		600|timeout		1|' #{cfg}")

                patchedIso = File.dirname(iso) + '/patched.iso'
                self.class.exec("xorriso -as mkisofs -no-emul-boot -boot-info-table -boot-load-size 4 -iso-level 4 -b boot/x86_64/loader/isolinux.bin -c boot/x86_64/loader/boot.cat -eltorito-alt-boot -no-emul-boot -e boot/x86_64/efi -o #{patchedIso} #{outputFolder}")
                patchedIso
            end

            def buildISOPreseed(id, iso, target, options)
                outputFolder = options['output'] + '/iso/'
                mkdir(outputFolder, false)
                self.class.exec("xorriso -osirrox on -indev #{iso} -extract / #{outputFolder}")
                FileUtils.chmod_R(0750, outputFolder) # Need to make it writeable so it can be deleted
                copy(options['output'] + '/' + id + '/preseed.cfg', outputFolder, false)

                self.class.exec("sed -i 's|vga=788 --- quiet|auto=true file=/cdrom/preseed.cfg vga=788 --- quiet|' #{outputFolder + "boot/grub/grub.cfg"}")
                self.class.exec("sed -i 's|--- quiet|file=/cdrom/preseed.cfg --- quiet|' #{outputFolder + "isolinux/adgtk.cfg"}")
                self.class.exec("sed -i 's|default .*|default autogui|' #{outputFolder + "isolinux/isolinux.cfg"}")

                patchedIso = File.dirname(iso) + '/patched.iso'
                self.class.exec("xorriso -as mkisofs -no-emul-boot -boot-info-table -boot-load-size 4 -iso-level 4 -b isolinux/isolinux.bin -c isolinux/boot.cat -eltorito-alt-boot -o #{patchedIso} #{outputFolder}")
                patchedIso
            end

            def buildISOAutoProxmox(id, iso, target, options)
                outputFolder = options['output'] + '/iso/'
                patchedIso = File.dirname(iso) + '/patched.iso'

                copy(iso, patchedIso, false)

                self.class.exec("xorriso -boot_image any keep -dev #{patchedIso} -map #{options['output'] + '/' + id + '/auto-installer-mode.toml'} /auto-installer-mode.toml")
                self.class.exec("xorriso -boot_image any keep -dev #{patchedIso} -map #{options['output'] + '/' + id + '/answer.toml'} /answer.toml")
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
                    target['Users']['root']['Password'] = ENV['LINUX_ROOT_PASSWORD']
                    target['Users']['root']['PasswordHash'] = self.class.linuxPasswordHash(ENV['LINUX_ROOT_PASSWORD'])
                elsif target['Users'].key?('root')
                    if !target['Users']['root']['Password'] &&
                       !target['Users']['root']['PasswordHash']
                        rootPassword = SecureRandom.urlsafe_base64(12)
                        prompt.say("Root password: #{rootPassword}", :color => :magenta)
                        target['Users']['root']['Password'] = rootPassword
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
                target['Apps'] = self.class.mapPackages(target['Apps'], target['Distro']) if target['Distro']
            end

            def self.linuxPasswordHash(password)
                salt = SecureRandom.alphanumeric(16)
                password.crypt('$6$' + salt)
            end

        end
    end
end
