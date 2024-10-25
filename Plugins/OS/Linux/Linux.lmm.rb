
require_relative 'Connection'

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
            SUBUID_FILE = '/etc/subuid'
            SUBGID_FILE = '/etc/subgid'
            SSH_CONFIG = '~/.ssh/config'
            SYSCTL_FILE = '/etc/sysctl.d/90-configlmm.conf'
            FIREWALL_PACKAGE = 'firewalld'
            FIREWALL_SERVICE = 'firewalld'

            def actionLinuxBuild(id, target, activeState, context, options)
                prepareConfig(target, context)
                buildHostsFile(id, target, options)
                buildSSHConfig(id, target, options)
                buildAutoInstall(id, target, options)
            end

            def actionLinuxDeploy(id, target, activeState, context, options)
                prepareConfig(target, context)
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    case uri.scheme
                    when 'qemu'
                        deployOverLibvirt(id, target, activeState, context, options)
                    when 'proxmox'
                        deployOverProxmox(id, target, activeState, context, options)
                    when 'ssh'
                        self.withConnection(uri, target) do |connection|
                            self.class.withConnection(connection) do |connection|
                                deployOverConnection(connection, id, target, activeState, context, options)
                            end
                        end
                    else
                        raise Framework::PluginProcessError.new("#{id}: Unknown protocol: #{uri.scheme}!")
                    end
                else
                    self.class.withConnection(Local.new(prompt, logger)) do |connection|
                        deployLocal(connection, target, options)
                    end
                end
                if target['AlternativeLocation']
                    self.withConnection(target['AlternativeLocation'], target) do |connection|
                        self.class.withConnection(connection) do |connection|
                            deployOverConnection(connection, id, target, activeState, context, options)
                        end
                    end
                end
            end

            def deployOverConnection(connection, id, target, activeState, context, options)
                if target['Domain'] || target['Hosts']
                    hostsLines = []
                    if target['Domain']
                        envs = connection.exec("env").split("\n")
                        envVars = Hash[envs.map { |vars| vars.split('=', 2) }]
                        if envVars['SSH_CONNECTION']
                            ipAddr = envVars['SSH_CONNECTION'].split[-2]
                            hostsLines << ipAddr.ljust(16) + Addressable::IDNA.to_ascii(target['Domain']) + ' ' + target['Name'] + "\n"
                        end
                    end
                    target['Hosts'].to_a.each do |ip, entries|
                        hostsLines << ip.ljust(16) + entries.map { |entry| Addressable::IDNA.to_ascii(entry) }.join(' ') + "\n"
                    end
                    connection.updateFile(HOSTS_FILE, options, false) do |fileLines|
                        fileLines + hostsLines
                    end
                end
                distroInfo = connection.distroInfo
                convertFlavour(distroInfo, target, connection, options)
                configureNetwork(distroInfo, target, connection, options)
                if target['Tmpfs']
                    connection.exec("sed -i '/ \\/tmp /d' #{FSTAB_FILE}")
                    connection.updateFile(FSTAB_FILE, options, false) do |fileLines|
                        fileLines << "tmpfs                                      /tmp                    tmpfs  nodev,nosuid,size=#{target['Tmpfs']}          0  0\n"
                    end
                end
                if target['Sysctl']
                    connection.updateFile(SYSCTL_FILE, options, false) do |fileLines|
                        target['Sysctl'].each do |name, value|
                            fileLines << "#{name} = #{value}\n"
                            connection.exec("sysctl #{name}=#{value}")
                        end
                        fileLines
                    end
                end
                if target['Users']
                    target['Users'].each do |name, info|
                        userId = connection.exec("id -u #{name} 2>/dev/null", true).strip
                        if userId.empty?
                            shell = ''
                            if info['Shell']
                                shell = "--shell '/usr/bin/#{info['Shell']}'"
                            end
                            badname = '--badname'
                            badname = '--badnames' if distroInfo['Name'] == 'openSUSE Leap'
                            connection.exec("useradd #{badname} --create-home --user-group #{shell} #{name}")
                        elsif info['Shell']
                            shell = "--shell '/usr/bin/#{info['Shell']}'"
                            connection.exec("chsh #{shell} #{name}")
                        end
                        if info['Subuids']
                            connection.exec("sed -i '/^#{name}:.*/d' #{SUBUID_FILE}")
                            info['Subuids'].each do |id|
                                connection.exec("#{distroInfo['ModifyUser']} --add-subuids #{id} #{name}")
                            end
                        end
                        if info['Subgids']
                            connection.exec("sed -i '/^#{name}:.*/d' #{SUBGID_FILE}")
                            info['Subgids'].each do |id|
                                connection.exec("#{distroInfo['ModifyUser']} --add-subgids #{id} #{name}")
                            end
                        end
                        homeDir = connection.exec("getent passwd #{name} | cut -d ':' -f 6").strip
                        keyFile = homeDir + "/.ssh/id_ed25519"
                        if info['SSHKey'] && !connection.filePresent?(keyFile)
                            connection.exec("mkdir -p #{homeDir}/.ssh")
                            connection.exec("ssh-keygen -t ed25519 -f #{keyFile} -P ''")
                            connection.exec("chown -R #{name}:#{name} #{homeDir}/.ssh")
                        end
                    end
                end
                if target['Firewall'] && target['Firewall'] != 'no'
                    connection.ensurePackage(FIREWALL_PACKAGE, options)
                    connection.ensureServiceAutoStart(FIREWALL_SERVICE, options)
                    connection.startService(FIREWALL_SERVICE, options)
                end
                if !target['Packages'].to_a.empty?
                    connection.ensurePackages(target['Packages'], options)
                end
                target['Services'].to_a.each do |service|
                    connection.ensureServiceAutoStart(service, options)
                    connection.startService(service, options)
                end
                self.executeCommands(target['Execute'], connection)
            end

            def convertFlavour(distroInfo, target, connection, options)
                if target['Flavour']
                    if target['Flavour'] == PROXMOXVE_NAME
                        if distroInfo['Name'] != DEBIAN_NAME
                            raise 'Can\'t convert flavour!'
                        end
                        if connection.filePresent?('/etc/apt/sources.list.d/pve-install-repo.list')
                            needInstall = connection.exec('dpkg --status proxmox-ve 2>/dev/null | grep Status | grep installed | wc -l').strip.to_i.zero?
                            if needInstall
                                connection.exec('DEBIAN_FRONTEND=noninteractive apt install --assume-yes proxmox-ve postfix open-iscsi chrony')
                                connection.exec("apt remove --assume-yes os-prober linux-image-amd64 'linux-image-*'")
                                connection.exec('update-grub')
                            end
                        else
                            connection.exec('echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list')
                            File.write(options['output'] + 'proxmox-release-bookworm.gpg', HTTP.follow.get('https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg').body)
                            connection.upload(options['output'] + 'proxmox-release-bookworm.gpg', '/etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg')
                            connection.exec('apt update && apt full-upgrade --assume-yes')
                            connection.exec('apt install --assume-yes proxmox-default-kernel')
                            connection.exec('systemctl reboot')
                        end
                        target['Network'] = {} unless target['Network'].is_a?(Hash)
                        target['Network']['Interfaces'] = {} unless target['Network']['Interfaces'].is_a?(Hash)
                        if !target['Network']['Interfaces'].key?('vmbr0')
                            if target['Network']['IP']
                                target['Network']['Interfaces']['vmbr0'] = {}
                                target['Network']['Interfaces']['vmbr0']['Type'] = 'Bridge'
                                target['Network']['Interfaces']['vmbr0']['IP'] = target['Network']['IP']
                                target['Network']['Interfaces']['vmbr0']['Gateway'] = target['Network']['Gateway']
                                target['Network']['Interfaces']['vmbr0']['DNS'] = target['Network']['DNS']
                            else
                                target['Network']['Interfaces']['vmbr0'] = 'dhcp'
                            end
                        end
                    else
                        raise 'Unimplemented flavour!'
                    end
                end
            end

            def configureNetwork(distroInfo, target, connection, options)
                if target['Network']
                    if distroInfo['Name'] == 'openSUSE Leap'
                        updateNetworkInterface(target['Network'], 'eth0', connection, options)
                        if target['Network']['Interfaces']
                            target['Network']['Interfaces'].each do |interface, config|
                                updateNetworkInterface(config, interface, connection, options)
                            end
                        end
                        if target['Network']['DNS']
                            configFile = '/etc/sysconfig/network/config'
                            dns = target['Network']['DNS']
                            dns = [dns] unless dns.is_a?(Array)
                            connection.exec("sed -i 's|^NETCONFIG_DNS_STATIC_SERVERS=.*|NETCONFIG_DNS_STATIC_SERVERS=\"#{dns.join(' ')}\"|' #{configFile}")
                        end
                        if target['Network']['Gateway']
                            routesFile = '/etc/sysconfig/network/routes'
                            connection.exec("sed -i 's|^default |#default |' #{routesFile}")
                            connection.updateFile(routesFile, options) do |fileLines|
                                fileLines << "default #{target['Network']['Gateway']}\n"
                            end
                        end
                    elsif distroInfo['Name'] == 'Debian'
                        links = self.networkLinks(connection)
                        raise 'Didn\'t find network links!' if links.empty?
                        linkType = nil
                        dnsSearch = connection.exec('cat /etc/resolv.conf | grep search').strip.split(' ').last
                        if target['Network'].is_a?(String)
                            linkType = target['Network']
                            target['Network'] = {}
                        end
                        if !target['Network'].key?('Interfaces') ||
                           target['Network']['Interfaces'].to_h.empty? ||
                           !target['Network']['Interfaces'].key?(links.first)
                           target['Network']['Interfaces'] ||= {}
                           if !linkType.nil?
                               target['Network']['Interfaces'][links.first] = linkType
                           else
                               target['Network']['Interfaces'][links.first] = {}
                               target['Network']['Interfaces'][links.first]['IP'] = target['Network']['IP']
                               target['Network']['Interfaces'][links.first]['Gateway'] = target['Network']['Gateway']
                               target['Network']['Interfaces'][links.first]['DNS'] = target['Network']['DNS']
                           end
                        end
                        if target['Network']['Interfaces'].key?('vmbr0')
                            if target['Network']['Interfaces']['vmbr0']['Ports'].nil?
                                target['Network']['Interfaces']['vmbr0']['Ports'] = [links.first]
                                target['Network']['Interfaces'][links.first] = 'manual'
                            end
                        end
                        interfacesFile = '/etc/network/interfaces'
                        localFile = options['output'] + '/' + SecureRandom.alphanumeric(10)
                        connection.download(interfacesFile, localFile)
                        fileLines = File.read(localFile).lines
                        if fileLines.index(IO::Local::CONFIGLMM_SECTION_BEGIN).nil?
                            lines = []
                            iface = false
                            fileLines.each do |line|
                                if line.start_with?('iface')
                                    if line.strip.split(' ')[1].start_with?('enp')
                                        iface = true
                                    else
                                        lines << line
                                    end
                                elsif iface && (line.start_with?(' ') || line.start_with?("\t"))
                                    # Drop line
                                else
                                    iface = false
                                    lines << line
                                end
                            end
                            fileWrite(localFile, lines.join(), options[:dry])
                            connection.upload(localFile, interfacesFile)
                        end
                        connection.updateFile(interfacesFile, options) do |fileLines|
                            target['Network']['Interfaces'].each do |name, data|
                                fileLines << "auto #{name}\n"
                                data = 'manual' if data.nil?
                                if data.is_a?(String)
                                    fileLines << "iface #{name} inet #{data}\n"
                                else
                                    if data['IP']
                                        fileLines << "iface #{name} inet static\n"
                                        fileLines << "        address #{data['IP']}\n"
                                        fileLines << "        gateway #{data['Gateway']}\n"
                                    else
                                        fileLines << "iface #{name} inet manual\n"
                                    end
                                    if data['Ports']
                                        fileLines << "        bridge-ports #{data['Ports'].join(' ')}\n"
                                        fileLines << "        bridge-stp off\n"
                                        fileLines << "        bridge-fd 0\n"
                                    end
                                    fileLines << "        # dns-* options are implemented by the resolvconf package, if installed\n" if data['DNS']
                                    fileLines << "        dns-nameservers #{data['DNS']}\n" if data['DNS']
                                    fileLines << "        dns-search #{dnsSearch}\n" if dnsSearch
                                end
                                fileLines << "\n"
                            end
                            fileLines
                        end
                    else
                        # TODO
                        raise 'Not Unimplemented!'
                    end
                end
            end

            def updateNetworkInterface(config, interface, connection, options)
                baseFile = '/etc/sysconfig/network/ifcfg-'
                networkFile = baseFile + interface
                connection.exec("touch #{networkFile}")
                connection.exec("sed -i \"/^BOOTPROTO=.*/d\" #{networkFile}")
                connection.exec("sed -i \"/^STARTMODE=.*/d\" #{networkFile}")
                connection.exec("sed -i \"/^ZONE=.*/d\" #{networkFile}")
                if config['IP']
                    connection.exec("sed -i 's|^IPADDR=|#IPADDR=|' #{networkFile}")
                end
                connection.updateFile(networkFile, options, false) do |fileLines|
                    fileLines << "STARTMODE=auto\n"
                    fileLines << "ZONE=public\n"
                    if config == 'dhcp'
                        fileLines << "BOOTPROTO=dhcp\n"
                    else
                        fileLines << "BOOTPROTO=static\n"
                        fileLines << "\n"
                        if config['IP']
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

            def networkLinks(connection)
                connection.exec("ls /sys/class/net/").strip.split("\n").select { |name| name.start_with?('enp') }
            end

            def deployLocal(connection, target, options)
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
                        userId = connection.exec("id -u #{name} 2>/dev/null", true).strip
                        if userId.empty?
                            shell = ''
                            if info['Shell']
                                shell = "--shell '/usr/bin/#{info['Shell']}'"
                            end
                            badname = '--badname'
                            badname = '--badnames' if connection.distroName == 'openSUSE Leap'
                            connection.exec("useradd #{badname} --create-home --user-group #{shell} #{name}", false, options)
                        end
                        homeDir = connection.exec("getent passwd #{name} | cut -d ':' -f 6", false, options).strip
                        keyFile = homeDir + "/.ssh/id_ed25519"
                        if info['SSHKey'] && !connection.filePresent?(keyFile, options)
                            connection.exec("mkdir -p #{homeDir}/.ssh", false, options)
                            connection.exec("ssh-keygen -t ed25519 -f #{keyFile} -P ''", false, options)
                            connection.exec("chown -R #{name}:#{name} #{homeDir}/.ssh", false, options)
                        end
                    end
                end
                if target['Firewall'] && target['Firewall'] != 'no'
                    connection.ensurePackage(FIREWALL_PACKAGE, options)
                    connection.ensureServiceAutoStart(FIREWALL_SERVICE, options)
                    connection.startService(FIREWALL_SERVICE, options)
                end
                self.executeCommands(target['Execute'])
            end

            def executeCommands(commands, connection)
                return unless commands

                commands.each do |type, data|
                    case type
                    when 'sh'
                        data = [data] unless data.is_a?(Array)
                        data.each do |cmd|
                            connection.exec(cmd)
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
                if plugins[:Libvirt].createVM(target['Name'], target, target['Location'], iso, activeState)
                    context.secrets.print('Root password', target['Users']['root']['Password']) if target['Users']['root'].key?('Password')
                end
            end

            def deployOverProxmox(id, target, activeState, context, options)
                if target['LXC']
                    info = flavourInfo(target['Distro'], target['Flavour'])
                    if plugins[:Proxmox].createContainer(target, target['Location'], info, activeState, context)
                        context.secrets.print('Root password', target['Users']['root']['Password']) if target['Users']['root'].key?('Password')
                    end
                else
                    location = Proxmox.getLocation(target['Location'])
                    iso = installationISO(target['Distro'], target['Flavour'], location)
                    iso = buildAutoInstallISO(id, iso, target, options)
                    if plugins[:Proxmox].createVM(target['Name'], target, target['Location'], iso, activeState, context)
                        context.secrets.print('Root password', target['Users']['root']['Password']) if target['Users']['root'].key?('Password')
                    end
                end
            end

            def buildHostsFile(id, target, options)
                if target['Hosts']
                    hosts  = "#\n"
                    hosts += "# /etc/hosts: static lookup table for host names\n"
                    hosts += "#\n\n"
                    hosts += "#<ip-address>   <hostname.domain.org>   <hostname>\n"
                    hosts += "127.0.0.1       localhost\n"
                    hosts += "::1             localhost\n\n"
                    hosts += IO::Local::CONFIGLMM_SECTION_BEGIN
                    target['Hosts'].each do |ip, entries|
                        hosts += ip.ljust(16) + entries.join(' ') + "\n"
                    end
                    hosts += IO::Local::CONFIGLMM_SECTION_END

                    path = options['output'] + '/' + id
                    mkdir(path + '/etc', options[:dry])
                    fileWrite(path + HOSTS_FILE, hosts, options[:dry])
                end
            end

            def buildSSHConfig(id, target, options)
                if !target['SSH']['Config'].empty?
                    sshConfig  = "\n"
                    sshConfig += IO::Local::CONFIGLMM_SECTION_BEGIN
                    target['SSH']['Config'].each do |name, info|
                        sshConfig += "Host #{name} #{info['HostName']}\n"
                        sshConfig += "    HostName " + info['HostName'] + "\n" if info['HostName']
                        sshConfig += "    Port " + info['Port'] + "\n" if info['Port']
                        sshConfig += "    User " + info['User'] + "\n" if info['User']
                        sshConfig += "    IdentityFile " + info['IdentityFile'] + "\n" if info['IdentityFile']
                        sshConfig += "\n"
                    end
                    sshConfig += IO::Local::CONFIGLMM_SECTION_END
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

            def flavourInfo(distro, flavour)
                url = nil
                flavour = distro unless flavour
                flavourInfo = YAML.load_file(__dir__ + '/Flavours.yaml')[flavour]
                if flavourInfo.nil?
                    raise Framework::PluginProcessError.new("#{id}: Unknown Linux Distro: #{flavour}!")
                end
                flavourInfo
            end

            def installationISO(distro, flavour, location)
                info = flavourInfo(distro, flavour)
                url = info['ISO']
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

                cfg = outputFolder + "EFI/BOOT/grub.cfg"
                self.class.exec("sed -i 's|timeout=.*|timeout=1|' #{cfg}")
                self.class.exec("sed -i 's|linux splash=silent|linux splash=silent autoyast=device://sr0/autoinst.xml|' #{cfg}")

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

            def self.withConnection(connection)
                yield(LinuxConnection.new(connection))
            end

            def prepareConfig(target, context)
                target['SSH'] ||= {}
                target['SSH']['Config'] ||= {}
                target['Users'] ||= {}
                target['HostName'] = target['Name'] unless target['HostName']

                if context.secrets.load(target['SecretId'], 'ROOT_PASSWORD_HASH')
                    target['Users']['root'] ||= {}
                    target['Users']['root']['PasswordHash'] = context.secrets.load(target['SecretId'], 'ROOT_PASSWORD_HASH')
                elsif context.secrets.load(target['SecretId'], 'ROOT_PASSWORD')
                    target['Users']['root'] ||= {}
                    target['Users']['root']['Password'] = context.secrets.load(target['SecretId'], 'ROOT_PASSWORD')
                    target['Users']['root']['PasswordHash'] = self.class.linuxPasswordHash(target['Users']['root']['Password'])
                elsif target['Users'].key?('root')
                    if !target['Users']['root'].key?('Password') &&
                       !target['Users']['root'].key?('PasswordHash')
                        password = SecureRandom.urlsafe_base64(20)
                        context.secrets.store(target['SecretId'], 'ROOT_PASSWORD', password)
                        target['Users']['root']['Password'] = password
                        target['Users']['root']['PasswordHash'] = self.class.linuxPasswordHash(password)
                    elsif target['Users']['root']['Password'] == false
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
                target['Packages'] = target['Apps'].dup
                if target['Apps'].to_a.include?('sshd')
                    target['Services'] << :sshd
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
