
require_relative '../General/Common'

require_relative 'Network'
require_relative 'Connection'

require 'addressable/uri'
require 'http'
require 'securerandom'
require 'shellwords'
require 'ipaddr'

module ConfigLMM
    module LMM
        class Linux < Framework::Plugin

            include OS::Common
            include OS::LinuxNetwork

            HOSTS_FILE = '/etc/hosts'
            FSTAB_FILE = '/etc/fstab'
            SUBUID_FILE = '/etc/subuid'
            SUBGID_FILE = '/etc/subgid'
            SSH_CONFIG = '~/.ssh/config'
            SYSCTL_FILE = '/etc/sysctl.d/90-configlmm.conf'
            FIREWALL_PACKAGE = 'firewalld'
            FIREWALL_SERVICE = 'firewalld'

            ARCH_NAME = 'Arch Linux'
            SUSE_NAME = 'openSUSE Leap'
            PROXMOXVE_NAME = 'Proxmox VE'
            DEBIAN_NAME = 'Debian'
            ALMA_NAME = 'AlmaLinux'

            def actionLinuxBuild(id, target, activeState, context, options)
                prepareConfig(target, context)
                buildHostsFile(id, target, options)
                buildSSHConfig(id, target, options)
                buildAutoInstall(id, target, options)
            end

            def cacheLinuxConnection(id, target, context, options)
                connectionInfos = []
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    case uri.scheme
                    when 'qemu'
                        # Not implemented
                    when 'proxmox'
                        # Not implemented
                    when 'pxe', 'pxe+http'
                        # Not cachable
                    when 'ssh'
                        cacheInfo = buildConnectionCache(uri, target)
                        cacheInfo << lambda { |connection, &block| self.class.withConnection(connection, context, &block) }
                        connectionInfos << cacheInfo
                    else
                        raise Framework::PluginProcessError.new("#{id}: Unknown protocol: #{uri.scheme}!")
                    end
                end
                if target['AlternativeLocation']
                    cacheInfo = buildConnectionCache(target['AlternativeLocation'], target)
                    cacheInfo << lambda { |connection, &block| self.class.withConnection(connection, context, &block) }
                    connectionInfos << cacheInfo
                end
                connectionInfos
            end

            def actionLinuxDeploy(id, target, activeState, context, options)
                prepareConfig(target, context)
                if target['ProvisionLocation'] && (!activeState['Status'] ||
                                                   [State::STATUS_CREATED, State::STATUS_DELETED, State::STATUS_DESTROYED].include?(activeState['Status']))
                    provision = true
                    # Safety check so that we don't accidently destroy existing system by trying to provision it again
                    if target['Location']
                        if self.ping(target['Location'], target, { **options, 'fast' => true })
                            logger.error("#{target['ID']}: #{target['Type'].to_s} at #{target['Location']} seems to be running, skipping provisioning!")
                            provision = false
                        end
                    end
                    if provision
                        deployLinux(target['ProvisionLocation'], id, target, activeState, context, options)
                        if target['Location']
                            logger.info("#{target['ID']}: #{target['Type'].to_s} - #{options['dry'] ? 'would be ': ''}waiting for host to respond...")
                            if options['dry'] || try(5 * 60, options) { self.ping(target['Location'], target, { **options, 'fast' => true }) }
                                activeState['Config'] ||= {}
                                activeState['Config']['ProvisionLocation'] = target['ProvisionLocation']
                                activeState['Config']['Domain'] = target['Domain'] if target.key?('Domain')
                                activeState['Config']['Distro'] = target['Distro'] if target.key?('Distro')
                                activeState['Config']['Network'] = target['Network'] if target.key?('Network')
                                activeState['Status'] = State::STATUS_PROVISIONING
                                state.save
                                logger.info("#{target['ID']}: #{target['Type'].to_s} - #{options['dry'] ? 'would be ': ''}waiting for provisioning to complete...")
                                if options['dry'] || try(20 * 60, options) {
                                        result = false
                                        sshOptions = { :non_interactive => true, :verify_host_key => :never }
                                        begin
                                            self.withConnection(target['Location'], target, { **options, 'disableCache' => true, 'ssh' => sshOptions }) do |connection|
                                                result = true if connection.exec('echo OK', false, options).strip == 'OK'
                                            end
                                        rescue StandardError => error
                                            raise error unless IO.error?(error) || error.is_a?(Net::SSH::Exception)
                                            # ignore
                                        end
                                        result
                                    }
                                    logger.info("#{target['ID']}: #{target['Type'].to_s} provisioning #{options['dry'] ? 'would be ': ''}complete!")
                                    activeState['Status'] = State::STATUS_PROVISIONED
                                    state.save
                                end
                            else
                                logger.error("#{target['ID']}: #{target['Type'].to_s} - host not responding, provisioning might have failed!")
                            end
                        end
                    end
                end
                deployLinux(target['Location'], id, target, activeState, context, options)
                if target['AlternativeLocation']
                    self.withConnection(target['AlternativeLocation'], target) do |connection|
                        self.class.withConnection(connection, context) do |connection|
                            deployOverConnection(connection, id, target, activeState, context, options)
                        end
                    end
                end
            end

            def actionLinuxTest(id, activeState, context, options)
                target = activeState['Config'].to_h
                location = target['AlternativeLocation'] ? target['AlternativeLocation'] : target['Location']
                result = false
                self.withConnection(location, target) do |connection|
                    result = true if connection.exec('echo OK', false, options).strip == 'OK'
                end
                options[:dry] ? nil : result
            end

            def actionLinuxBackup(id, activeState, context, options)
                target = activeState['Config'].to_h
                if target['AlternativeLocation']
                    self.withConnection(target['AlternativeLocation'], target) do |connection|
                        self.class.withConnection(connection, context) do |connection|
                            backupOverConnection(connection, id, activeState, context, options)
                        end
                    end
                end
                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    case uri.scheme
                    when 'qemu'
                        return if target['AlternativeLocation']
                        prompt.warn('Backing up on QEMU not implemented!')
                    when 'proxmox'
                        backupInProxmox(id, target, activeState, context, options)
                    when 'pxe', 'pxe+http'
                        return
                    when 'ssh'
                        return if target['AlternativeLocation']
                        self.withConnection(uri, target) do |connection|
                            self.class.withConnection(connection, context) do |connection|
                                backupOverConnection(connection, id, activeState, context, options)
                            end
                        end
                    else
                        raise Framework::PluginProcessError.new("#{id}: Unknown protocol: #{uri.scheme}!")
                    end
                else
                    # Local backup not implemented - TODO FIXME
                    prompt.warn('Local backup not implemented!')
                end
            end

            def actionLinuxUpdates?(id, activeState, context, options)
                hasUpdates = false
                target = activeState['Config'].to_h
                if target['AlternativeLocation']
                    self.withConnection(target['AlternativeLocation'], target) do |connection|
                        self.class.withConnection(connection, context) do |connection|
                            hasUpdates = hasUpdates?(connection, id, activeState, context, options)
                        end
                    end
                elsif target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    case uri.scheme
                    when 'qemu', 'pxe', 'pxe+http', 'proxmox'
                        return nil
                    when 'ssh'
                        self.withConnection(uri, target) do |connection|
                            self.class.withConnection(connection, context) do |connection|
                                hasUpdates = hasUpdates?(connection, id, activeState, context, options)
                            end
                        end
                    else
                        raise Framework::PluginProcessError.new("#{id}: Unknown protocol: #{uri.scheme}!")
                    end
                else
                    hasUpdates = hasUpdates?(local, id, activeState, context, options)
                end
                hasUpdates
            end

            def actionLinuxUpdate(id, activeState, context, options)
                target = activeState['Config'].to_h
                if target['AlternativeLocation']
                    self.withConnection(target['AlternativeLocation'], target) do |connection|
                        self.class.withConnection(connection, context) do |connection|
                            updateOverConnection(connection, id, activeState, context, options)
                        end
                    end
                elsif target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    case uri.scheme
                    when 'qemu', 'pxe', 'pxe+http', 'proxmox'
                        return
                    when 'ssh'
                        self.withConnection(uri, target) do |connection|
                            self.class.withConnection(connection, context) do |connection|
                                updateOverConnection(connection, id, activeState, context, options)
                            end
                        end
                    else
                        raise Framework::PluginProcessError.new("#{id}: Unknown protocol: #{uri.scheme}!")
                    end
                else
                    updateOverConnection(local, id, activeState, context, options)
                end
            end

            def deployOverConnection(connection, id, target, activeState, context, options)
                if target['Domain'] || target['Hosts']
                    hostsLines = []
                    if target['Domain']
                        connection.updateHostname(target['Domain'], context, options)
                        envs = connection.exec("env", false, { **options, 'dry' => false }).split("\n")
                        envVars = Hash[envs.map { |vars| vars.split('=', 2) }]
                        if envVars['SSH_CONNECTION']
                            ipAddr = envVars['SSH_CONNECTION'].split[-2]
                            hostsLines << getHostsLine(ipAddr, [Addressable::IDNA.to_ascii(target['Domain']), target['Name']]) + "\n"
                        end
                    end
                    target['Hosts'].to_a.each do |ip, entries|
                        hostsLines << getHostsLine(ip, entries) + "\n"
                    end
                    connection.updateHosts(hostsLines, context, options)
                end
                distroInfo = connection.distroInfo
                convertFlavour(distroInfo, target, connection, options)
                configureNetwork(distroInfo, target, connection, options)
                if target['Tmpfs']
                    connection.exec("sed -i '/ \\/tmp /d' #{FSTAB_FILE}", false, options)
                    connection.updateFile(FSTAB_FILE, options, false) do |fileLines|
                        fileLines << "tmpfs                                      /tmp                    tmpfs  nodev,nosuid,size=#{target['Tmpfs']}          0  0\n"
                    end
                end
                if target['Sysctl']
                    connection.updateFile(SYSCTL_FILE, options, false) do |fileLines|
                        target['Sysctl'].each do |name, value|
                            fileLines << "#{name} = #{value}\n"
                            connection.exec("sysctl #{name}=#{value}", false, options)
                        end
                        fileLines
                    end
                end
                if target['Users']
                    target['Users'].each do |name, info|
                        userId = connection.exec("id -u #{name} 2>/dev/null", true, { **options, 'dry' => false }).strip
                        if userId.empty?
                            shell = ''
                            if info['Shell']
                                result = connection.exec("which #{info['Shell']}", true, { **options, 'dry' => false }).strip
                                if !result.empty? && !result.include?("no #{info['Shell']}")
                                    shell = "--shell '#{result}'"
                                else
                                    prompt.say("Shell '#{info['Shell']}' not found! Skipping setting!", :color => :red)
                                end
                            end
                            params = '--create-home --user-group'
                            badname = '--badname'
                            badname = '--badnames' if distroInfo['Name'] == 'openSUSE Leap'
                            if info['System']
                                params += ' --system'
                            end
                            connection.exec("useradd #{badname} #{params} #{shell} #{name}", false, options)
                        elsif info['Shell']
                            result = connection.exec("which #{info['Shell']}", true, { **options, 'dry' => false }).strip
                            if !result.empty? && !result.include?("no #{info['Shell']}")
                                connection.ensurePackage('chsh', options) unless connection.hasBinaries?('chsh', options)
                                shell = "--shell '#{result}'"
                                connection.exec("chsh #{shell} #{name}", false, options)
                            else
                                prompt.say("Shell '#{info['Shell']}' not found! Skipping setting!", :color => :red)
                            end
                        end
                        if info['Subuids']
                            connection.exec("sed -i '/^#{name}:.*/d' #{SUBUID_FILE}", false, options)
                            info['Subuids'].each do |id|
                                connection.exec("#{distroInfo['ModifyUser']} --add-subuids #{id} #{name}", false, options)
                            end
                        end
                        if info['Subgids']
                            connection.exec("sed -i '/^#{name}:.*/d' #{SUBGID_FILE}", false, options)
                            info['Subgids'].each do |id|
                                connection.exec("#{distroInfo['ModifyUser']} --add-subgids #{id} #{name}", false, options)
                            end
                        end
                        homeDir = connection.exec("getent passwd #{name} | cut -d ':' -f 6", false, { **options, 'dry' => false }).strip
                        hostname = connection.exec("hostnamectl hostname", false, { **options, 'dry' => false }).strip
                        keyFile = homeDir + "/.ssh/id_ed25519"
                        if info['SSH'].to_h['Key'] && !connection.filePresent?(keyFile, options)
                            connection.exec("mkdir -p #{homeDir}/.ssh", false, options)
                            connection.exec("ssh-keygen -t ed25519 -f #{keyFile} -P '' -C '#{name}@#{hostname}'", false, options)
                            connection.exec("chown -R #{name}:#{name} #{homeDir}/.ssh", false, options)
                        end
                        if !info['SSH'].to_h['Config'].to_h.empty?
                            connection.exec("mkdir -p #{homeDir}/.ssh", false, options)
                            deploySSHConfig(connection, info['SSH']['Config'], "#{homeDir}/.ssh/config", target, options)
                            connection.exec("chown -R #{name}:#{name} #{homeDir}/.ssh", false, options)
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

            def backupOverConnection(connection, id, activeState, context, options)
                filename = options['output'] + '/etc.tar.gz'
                connection.downloadStream('tar --create --acls --xattrs --selinux --format=posix --gzip /etc', filename, options)

                packageFilename = options['output'] + '/packages.txt'
                packages = connection.execDistroCommand(nil, 'ListPackages', false, options)
                local.fileWrite(packageFilename, packages, options[:dry])
            end

            MAX_SERVICES_RESTART = 12

            def hasUpdates?(connection, id, activeState, context, options)
                result = connection.execDistroCommand(nil, 'ListUpdates', false, options).strip
                if connection.distroName == ARCH_NAME
                    return result.lines.length > 0
                elsif connection.distroName == DEBIAN_NAME
                    # 0 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
                    return result.lines.last.count('0') != 4
                else
                    return !result.downcase.include?('no updates')
                end
            end

            def updateOverConnection(connection, id, activeState, context, options)
                result = connection.execDistroCommand(nil, 'UpdatePackages', false, options).downcase
                local.fileWrite(options['output'] + '/update.txt', result, options[:dry])
                if result.include?('package updates will not be installed') ||
                   result.include?('packages have been kept back')
                    prompt.warn('Manual upgrade required!')
                end

                needReboot = false
                autoRestart = true
                if result.include?('reboot required') ||
                   result.include?('reboot is suggested') ||
                   result.include?('update-initramfs:') ||
                   result.include?('updating linux initcpios') ||
                   result.include?(' kernel ') # For AlmaLinux
                    needReboot = true
                    autoRestart = false
                end

                connection.ensurePackage('lsof', options) unless connection.hasBinaries?('lsof', options)
                pids = connection.exec("lsof -anlPX -d DEL 2>/dev/null | grep -E ' /(usr|lib|bin|sbin|opt)' | tr -s ' ' | cut -d ' ' -f 2 | uniq", false, options).strip.split("\n")
                pids += connection.exec("lsof -anlPX +L1 -d fd,txt 2>/dev/null | grep -E ' /(usr|lib|bin|sbin|opt)' | tr -s ' ' | cut -d ' ' -f 2 | uniq", false, options).strip.split("\n")
                if !pids.empty?
                    if autoRestart
                        services = Set.new
                        processes = {}
                        restartSystemd = false
                        pids.each do |pid|
                            if pid.to_i == 1
                                restartSystemd = true
                                next
                            end
                            cgroup = connection.exec("cat /proc/#{pid}/cgroup 2>/dev/null", true, options).strip
                            info = Systemd.parseCGroup(cgroup)
                            if info
                                services << info
                            else
                                processes[pid] = connection.exec("stat /proc/#{pid}/exe 2>/dev/null | grep File | cut -d '>' -f 2", true, options).strip.gsub(' (deleted)', '')
                            end
                        end
                        services = Systemd.removeRedundantServices(services)
                        if services.length <= MAX_SERVICES_RESTART
                            if restartSystemd
                                prompt.warn('Reexecuting systemd!')
                                connection.exec("systemctl daemon-reexec", false, options)
                            end
                            timeoutOptions = { **options, commandTimeout: 20*60 } # 20min timeout
                            services.each do |service|
                                prompt.warn("Restarting #{service[:service] ? service[:service] : service[:specialService]}")
                                if service[:service] && !service[:uid]
                                    connection.exec("systemctl restart #{service[:service]}", false, timeoutOptions)
                                elsif service[:service] && service[:uid]
                                    connection.exec("systemctl --user --machine=#{service[:uid]}@ restart #{service[:service]}", false, timeoutOptions)
                                elsif service[:specialService]
                                    connection.exec("systemctl restart #{service[:specialService]}", false, timeoutOptions)
                                else
                                    raise 'This shouldn\'t happen!'
                                end
                            end
                        else
                            needReboot = true
                            prompt.warn('Many services need to be restarted!')
                        end
                        if !processes.empty?
                            prompt.warn('These processes need to be restarted:')
                            processes.each do |pid, process|
                                prompt.warn(' * ' + pid.to_s + ' - '+ process)
                            end
                        end
                    else
                        prompt.warn('Some processes need to be restarted!')
                    end
                end

                if needReboot
                    prompt.warn('System reboot required!')
                end
            end

            def convertFlavour(distroInfo, target, connection, options)
                if target['Flavour']
                    if target['Flavour'] == PROXMOXVE_NAME
                        if distroInfo['Name'] != DEBIAN_NAME
                            raise 'Can\'t convert flavour!'
                        end
                        if connection.filePresent?('/etc/apt/sources.list.d/pve-install-repo.list', { **options, 'dry' => false })
                            needInstall = connection.exec('dpkg --status proxmox-ve 2>/dev/null | grep Status | grep installed | wc -l', false, { **options, 'dry' => false }).strip.to_i.zero?
                            if needInstall
                                connection.exec('DEBIAN_FRONTEND=noninteractive apt install --assume-yes proxmox-ve postfix open-iscsi chrony', false, options)
                                connection.exec("apt remove --assume-yes os-prober linux-image-amd64 'linux-image-*'", false, options)
                                connection.exec('update-grub', false, options)
                            end
                        else
                            connection.exec('echo "deb [arch=amd64] http://download.proxmox.com/debian/pve bookworm pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list', false, options)
                            File.write(options['output'] + 'proxmox-release-bookworm.gpg', HTTP.follow.get('https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg').body)
                            connection.upload(options['output'] + 'proxmox-release-bookworm.gpg', '/etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg', options)
                            connection.exec('apt update && apt full-upgrade --assume-yes', false, options)
                            connection.exec('apt install --assume-yes proxmox-default-kernel', false, options)
                            connection.exec('systemctl reboot', false, options)
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
                    if networkManagerEnabled?(target, connection, options)
                        configureNetworkManager(target, connection, options)
                    elsif networkingEnabled?(target, connection, options)
                        configureNetworking(target, connection, options)
                    else
                        # TODO
                        raise 'Not Unimplemented!'
                    end
                end
            end

            def deployLocal(connection, target, options)
                deployLocalHostsFile(target, options)
                deployLocalSSHConfig(connection, target, options)
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
                        userId = connection.exec("id -u #{name} 2>/dev/null", true, { **options, 'dry' => false }).strip
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
                        if info['SSH'].to_h['Key'] && !connection.filePresent?(keyFile, options)
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
                self.executeCommands(target['Execute'], connection)
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

            def deployLinux(location, id, target, activeState, context, options)
                if location && location != '@me'
                    uri = Addressable::URI.parse(location)
                    case uri.scheme
                    when 'qemu'
                        deployOverLibvirt(uri, id, target, activeState, context, options)
                    when 'proxmox'
                        deployOverProxmox(uri, id, target, activeState, context, options)
                    when 'pxe', 'pxe+http'
                        deployOverPXE(uri, id, target, activeState, context, options)
                    when 'ssh'
                        self.withConnection(uri, target) do |connection|
                            self.class.withConnection(connection, context) do |connection|
                                deployOverConnection(connection, id, target, activeState, context, options)
                            end
                        end
                    else
                        raise Framework::PluginProcessError.new("#{id}: Unknown protocol: #{uri.scheme}!")
                    end
                else
                    self.class.withConnection(IO::Local.new(prompt, logger)) do |connection|
                        deployLocal(connection, target, options)
                    end
                end
            end

            def deployOverLibvirt(uri, id, target, activeState, context, options)
                iso = installationISO(target['Distro'], target['Flavour'])
                iso = buildAutoInstallISO(id, iso, target, options)
                if plugins[:Libvirt].createVM(target['Name'], target, uri, iso, activeState, context, options)
                    context.secrets.print('Root password', target['Users']['root']['Password']) if target['Users']['root'].key?('Password')
                end
            end

            def deployOverProxmox(uri, id, target, activeState, context, options)
                if target['LXC']
                    info = flavourInfo(target['Distro'], target['Flavour'])
                    if plugins[:Proxmox].createContainer(target, uri, info, activeState, context, options)
                        context.secrets.print('Root password', target['Users']['root']['Password']) if target['Users']['root'].key?('Password')
                    end
                else
                    iso = installationISO(target['Distro'], target['Flavour'])
                    iso = buildAutoInstallISO(id, iso, target, options)
                    if plugins[:Proxmox].createVM(target['Name'], target, uri, iso, activeState, context, options)
                        context.secrets.print('Root password', target['Users']['root']['Password']) if target['Users']['root'].key?('Password')
                    end
                end
            end

            def backupInProxmox(id, target, activeState, context, options)
                # TODO FIXME
            end

            def findNetworkIP(ipaddr)
                addrs = Socket.getifaddrs.select { |ifaddr| ifaddr.addr.ipv4? && !ifaddr.addr.ipv4_loopback? }
                addrs.each do |addr|
                    ip = addr.addr.ip_unpack.first
                    netmask = addr.netmask.ip_unpack.first
                    prefix = netmask.split('.').map(&:to_i).map { |octet| octet.to_s(2).count('1') }.sum
                    if IPAddr.new("#{ip}/#{prefix}") == IPAddr.new(ipaddr)
                        return ip
                    end
                end
                nil
            end

            def deployOverPXE(uri, id, target, activeState, context, options)
                networkOptions = target['DefaultNetwork'].dup
                networkOptions['ID'] = id
                clientIp = networkOptions['IP']
                if clientIp == 'dhcp'
                    networkOptions['IP'] = nil
                    networkOptions['ClientIP'] = nil
                else
                    networkOptions['ClientIP'] = clientIp.split('/').first
                    networkOptions['IP'] = findNetworkIP(clientIp)
                end
                dir = preparePXE(id, target['Distro'], target['Flavour'], options)
                bootFileResolver = Proc.new do |clientArch|
                    bootFile = 'lpxelinux.0'
                    bootFile = 'pxelinux.0' unless File.exist?(dir + bootFile)
                    if [0x0007, 0x0010].include?(clientArch) # EFI x64 and x64 UEFI HTTP
                        if target['Distro'] == SUSE_NAME
                            # Because we reuse Debian netboot archive...
                            bootFile = 'debian-installer/amd64/bootnetx64.efi'
                        elsif target['Distro'] == DEBIAN_NAME
                            bootFile = 'debian-installer/amd64/bootnetx64.efi'
                        end
                    end
                    bootFile
                end
                IO::PXE.boot(dir, uri, networkOptions, bootFileResolver, options, logger)
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
                        hosts += getHostsLine(ip, entries) + "\n"
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
                        sshConfig += "    HostName " + Addressable::IDNA.to_ascii(info['HostName']) + "\n" if info['HostName']
                        sshConfig += "    Port " + info['Port'].to_s + "\n" if info['Port']
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
                config = prepareAutoInstallConfig(target)
                if config['Flavour'] == PROXMOXVE_NAME
                    outputFolder = options['output'] + '/' + id + '/'
                    template = ERB.new(File.read(__dir__ + '/Proxmox/answer.toml.erb'))
                    renderTemplate(template, config, outputFolder + 'answer.toml', options)
                    File.write("#{outputFolder}/auto-installer-mode.toml", 'mode = "iso"')
                elsif config['Distro'] == SUSE_NAME
                    outputFolder = options['output'] + '/' + id + '/'
                    template = ERB.new(File.read(__dir__ + '/openSUSE/autoinst.xml.erb'))
                    renderTemplate(template, config, outputFolder + 'autoinst.xml', options)
                elsif config['Distro'] == DEBIAN_NAME
                    variables = prepareDebianStorage(config, options)
                    outputFolder = options['output'] + '/' + id + '/'
                    template = ERB.new(File.read(__dir__ + '/Debian/preseed.cfg.erb'))
                    renderTemplate(template, variables, outputFolder + 'preseed.cfg', options)
                end
            end

            def prepareAutoInstallConfig(target)
                config = target.dup
                if config['Apps'].to_a.include?('sshd')
                    config['Services'] << :sshd
                    config['Services'].uniq!
                end
                config['Apps'] = Framework::LinuxApp.mapPackages(config['Apps'], config['Distro']) if config['Distro']
                config['Apps'].delete_if { |app| app.include?('|') } if config['Apps']
                config
            end

            def prepareDebianStorage(target, options)
                variables = target.dup
                variables['AutoPartition'] = true
                variables['Disks'] = []
                if target.key?('StorageDevices')
                    if target['StorageDevices'].length == 1
                        variables['Disks'] = [target['StorageDevices'].first['Device']]
                        if !target['StorageDevices'].first['Partitions'].to_a.empty?
                            variables['AutoPartition'] = false
                        end
                    elsif !target['StorageDevices'].empty?
                        variables['AutoPartition'] = false
                    end
                end
                if target.key?('Mounts') && !target['Mounts'].empty?
                    variables['AutoPartition'] = false
                end
                if !variables['AutoPartition']
                    logger.warn('Specified disk/partition configuration is not implemented! You will have to configure it manually!')
                end
                variables
            end

            def getHostsLine(ip, entries)
                entries = entries.map { |entry| Addressable::IDNA.to_ascii(entry) }
                # Hostnames should be case-insensitive but some implementations like in Alpine aren't
                # so in case someone specified UpperCase hostname we also add lowercase one so that both would resolve
                entries = (entries + entries.map(&:downcase)).uniq
                ip.ljust(16) + entries.join(' ')
            end

            def deployLocalHostsFile(target, options)
                if target['Hosts']
                    updateLocalFile(HOSTS_FILE, options) do |hostsLines|
                        target['Hosts'].each do |ip, entries|
                            hostsLines << getHostsLine(ip, entries) + "\n"
                        end
                        hostsLines
                    end
                end
            end

            def deployLocalSSHConfig(connection, target, options)
                deploySSHConfig(connection, target['SSH']['Config'], File.expand_path(SSH_CONFIG), target, options)
            end

            def deploySSHConfig(connection, config, path, target, options)
                if !config.to_h.empty?
                    connection.updateFile(path, options) do |configLines|
                        processSSHConfig(config, configLines)
                    end
                end
            end

            def processSSHConfig(config, lines)
                config.each do |name, info|
                    lines << "Host #{name} #{info['HostName']}\n"
                    lines << "    HostName " + Addressable::IDNA.to_ascii(info['HostName']) + "\n" if info['HostName']
                    lines << "    Port " + info['Port'].to_s + "\n" if info['Port']
                    lines << "    User " + info['User'] + "\n" if info['User']
                    lines << "    IdentityFile " + info['IdentityFile'] + "\n" if info['IdentityFile']
                end
                lines
            end

            def installationISO(distro, flavour)
                info = flavourInfo(distro, flavour)
                downloadImage(info['ISO'], info['Checksum'], info['Signature'], info['SignatureKey'])
            end

            def preparePXE(id, distro, flavour, options)
                outputFolder = options['output'] + '/pxe/'
                local.mkdir(outputFolder, false)
                info = flavourInfo(distro, flavour)
                image = nil
                if info['PXE']
                    image = downloadImage(info['PXE'])
                    local.exec("tar --extract --file=#{image.shellescape} --directory=#{outputFolder}", false)
                    if distro == DEBIAN_NAME
                        local.copy(options['output'] + '/' + id + '/preseed.cfg', outputFolder, false)
                        local.exec("sed -i 's|default .*|default auto|' #{outputFolder}debian-installer/amd64/boot-screens/syslinux.cfg", false)
                        local.exec("sed -i 's|--- quiet|file=/preseed.cfg --- quiet|' #{outputFolder}debian-installer/amd64/boot-screens/adtxt.cfg", false)
                        local.exec("echo \"set default='... Automated install'\" >> #{outputFolder}debian-installer/amd64/grub/grub.cfg", false)
                        local.exec("echo 'set timeout=1' >> #{outputFolder}debian-installer/amd64/grub/grub.cfg", false)
                        local.exec("gunzip #{outputFolder}debian-installer/amd64/initrd.gz", false)
                        local.exec("cd #{options['output'] + '/' + id} && echo preseed.cfg | cpio -H newc -o -O #{outputFolder}debian-installer/amd64/initrd --append", false)
                        local.exec("gzip #{outputFolder}debian-installer/amd64/initrd", false)
                    end
                elsif distro == SUSE_NAME
                    # openSUSE doesn't provide netboot archive
                    # and grub.efi from it's ISO doesn't work
                    # so let's just reuse Debian archive
                    debianInfo = flavourInfo('Debian', nil)
                    debianImage = downloadImage(debianInfo['PXE'])
                    local.exec("tar --extract --file=#{debianImage.shellescape} --directory=#{outputFolder}", false)
                    local.exec("rm -rf #{outputFolder}pxelinux.cfg", false)

                    syslinux = downloadImage(flavourInfo('Syslinux', nil)['Archive'])
                    syslinuxFolder = options['output'] + '/syslinux'
                    local.mkdir(syslinuxFolder, false)
                    local.mkdir(outputFolder + 'pxelinux.cfg', false)
                    local.copy(options['output'] + '/' + id + '/autoinst.xml', outputFolder, false)
                    local.exec("tar --extract --file=#{syslinux.shellescape} --directory=#{syslinuxFolder}", false)
                    local.exec("cp #{syslinuxFolder}/*/bios/core/lpxelinux.0 #{outputFolder}", false)
                    local.exec("cp #{syslinuxFolder}/*/bios/com32/elflink/ldlinux/ldlinux.c32 #{outputFolder}", false)
                    local.exec("cp #{__dir__ + '/Syslinux/default'} #{outputFolder}pxelinux.cfg/", false)
                    local.exec("sed -i 's|$OPTIONS|install=#{info['FILES']} autoyast=/autoinst.xml|' #{outputFolder}pxelinux.cfg/default", false)

                    # If you have Network/IP configured in UEFI firmware which is different than what we use
                    # then Syslinux will use that IP instead of ours so you need to reset those settings
                    #
                    # Not using Syslinux.efi because for some reason it doesn't work - reboots after loading initrd
                    #local.exec("cp #{syslinuxFolder}/*/efi64/efi/syslinux.efi #{outputFolder}", false)
                    #local.exec("cp #{syslinuxFolder}/*/efi64/com32/elflink/ldlinux/ldlinux.e64 #{outputFolder}", false)

                    local.remoteDownload(info['FILES'] + 'boot/x86_64/loader/initrd', outputFolder)
                    local.remoteDownload(info['FILES'] + 'boot/x86_64/loader/linux', outputFolder)

                    # Not using grub.efi because UEFI Firemware says "Unsupported"
                    #local.remoteDownload(info['FILES'] + 'EFI/BOOT/bootx64.efi', outputFolder)
                    #local.remoteDownload(info['FILES'] + 'EFI/BOOT/grub.efi', outputFolder)
                    #local.remoteDownload(info['FILES'] + 'EFI/BOOT/grub.cfg', outputFolder)

                    local.exec("cp #{__dir__ + '/Grub/grub.cfg'} #{outputFolder}debian-installer/amd64/grub/", false)
                    local.exec("sed -i 's|$OPTIONS|install=#{info['FILES']} autoyast=/autoinst.xml|' #{outputFolder}debian-installer/amd64/grub/grub.cfg", false)

                    local.exec("xz --decompress --stdout #{outputFolder}initrd > #{outputFolder}initrd.decompressed", false)
                    local.exec("cd #{options['output'] + '/' + id} && echo autoinst.xml | cpio -H newc -o -O #{outputFolder}initrd.decompressed --append", false)
                    local.exec("xz --compress --stdout --check=crc32 #{outputFolder}initrd.decompressed > #{outputFolder}initrd", false)
                else
                    raise 'Not implemented!'
                end
                outputFolder
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
                local.exec("xorriso -osirrox on -indev #{iso} -extract / #{outputFolder}")
                FileUtils.chmod_R(0750, outputFolder) # Need to make it writeable so it can be deleted
                copy(options['output'] + '/' + id + '/autoinst.xml', outputFolder, false)

                cfg = outputFolder + "boot/x86_64/loader/isolinux.cfg"
                local.exec("sed -i 's|default harddisk|default linux|' #{cfg}")
                local.exec("sed -i 's|append initrd=initrd splash=silent showopts|append initrd=initrd splash=silent autoyast=device://sr0/autoinst.xml|' #{cfg}")
                local.exec("sed -i 's|prompt		1|prompt		0|' #{cfg}")
                local.exec("sed -i 's|timeout		600|timeout		1|' #{cfg}")

                ifcfg = ''
                if target['DefaultNetwork']['IP'] != 'dhcp'
                    ifcfg = "ifcfg=\"eth*=#{target['DefaultNetwork']['IP']}"
                    if target['DefaultNetwork']['Gateway'] || target['DefaultNetwork']['DNS']
                        ifcfg +=  ',' + target['DefaultNetwork']['Gateway'].to_s
                        if target['DefaultNetwork']['DNS']
                            ifcfg +=  ',' + target['DefaultNetwork']['DNS']
                            ifcfg +=  ',' + Addressable::IDNA.to_ascii(target['Domain']) if target['Domain']
                        end
                    end
                    ifcfg += '"'
                end

                cfg = outputFolder + "EFI/BOOT/grub.cfg"
                local.exec("sed -i 's|timeout=.*|timeout=1|' #{cfg}")
                local.exec("sed -i 's|linux splash=silent|linux splash=silent #{ifcfg} autoyast=device://sr0/autoinst.xml|' #{cfg}")

                patchedIso = File.dirname(iso) + '/patched.iso'
                local.exec("xorriso -as mkisofs -no-emul-boot -boot-info-table -boot-load-size 4 -iso-level 4 -b boot/x86_64/loader/isolinux.bin -c boot/x86_64/loader/boot.cat -eltorito-alt-boot -no-emul-boot -e boot/x86_64/efi -o #{patchedIso} #{outputFolder}")
                patchedIso
            end

            def buildISOPreseed(id, iso, target, options)
                outputFolder = options['output'] + '/iso/'
                mkdir(outputFolder, false)
                local.exec("xorriso -osirrox on -indev #{iso} -extract / #{outputFolder}", false)
                FileUtils.chmod_R(0750, outputFolder) # Need to make it writeable so it can be deleted
                local.copy(options['output'] + '/' + id + '/preseed.cfg', outputFolder, false)

                local.exec("sed -i 's|vga=788 --- quiet|auto=true file=/cdrom/preseed.cfg vga=788 --- quiet|' #{outputFolder}boot/grub/grub.cfg")
                local.exec("echo \"set default='... Automated install'\" >> #{outputFolder}boot/grub/grub.cfg", false)
                local.exec("echo 'set timeout=1' >> #{outputFolder}boot/grub/grub.cfg", false)
                local.exec("sed -i 's|--- quiet|file=/cdrom/preseed.cfg --- quiet|' #{outputFolder + "isolinux/adgtk.cfg"}")
                local.exec("sed -i 's|default .*|default autogui|' #{outputFolder + "isolinux/isolinux.cfg"}")

                patchedIso = File.dirname(iso) + '/patched.iso'
                local.exec("xorriso -as mkisofs -no-emul-boot -boot-info-table -boot-load-size 4 -iso-level 4 -b isolinux/isolinux.bin -c isolinux/boot.cat -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -o #{patchedIso} #{outputFolder}")
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

            def self.withConnection(connection, context = nil, &block)
                if context
                    context.useConnectionCache(connection, block) do
                        yield(LinuxConnection.new(connection))
                    end
                else
                    yield(LinuxConnection.new(connection))
                end
            end

            def self.linuxPasswordHash(password)
                salt = SecureRandom.alphanumeric(16)
                password.crypt('$6$' + salt)
            end

        end
    end
end
