# frozen_string_literal: true

require 'tty-which'

module ConfigLMM
    module Framework

        class LinuxApp < Framework::Plugin

            LINUX_FOLDER = __dir__ + '/../../../../Plugins/OS/Linux/'
            SUSE_NAME = 'openSUSE Leap'
            SUSE_ID = 'opensuse-leap'
            DEBIAN_NAME = 'Debian'
            PROXMOXVE_NAME = 'Proxmox VE'
            PODMAN_PACKAGE = 'Podman'
            SYSTEMD_CONTAINERS_PATH = '~/.config/containers/systemd/'

            def ensurePackage(name, location, binary = nil)
                self.class.ensurePackage(name, location, binary)
            end

            def ensurePackages(names, location)
                self.class.ensurePackages(names, location)
            end

            def self.ensurePackage(name, locationOrConnection, binary = nil)
                if binary && TTY::Which.which(binary)
                    return
                end
                self.ensurePackages([name], locationOrConnection)
            end

            def self.ensurePackages(names, locationOrConnection)
                self.doConnection(locationOrConnection) do |connection|
                    distroInfo = self.currentDistroInfo(connection)
                    reposPackages = self.mapPackages(names, distroInfo['Name'])

                    repos = []
                    pkgs = []
                    reposPackages.each do |pkg|
                        if pkg.include?('|')
                            repoName, pkg = pkg.split('|')
                            repos << repoName
                            pkgs << pkg
                        else
                            pkgs << pkg
                        end
                    end
                    repos.each do |repoName|
                        self.addRepo(repoName, distroInfo, connection)
                    end
                    command = distroInfo['InstallPackage'] + ' ' + pkgs.map { |pkg| pkg.shellescape }.join(' ')
                    connection.adminExec(command)
                    distroInfo
                end
            end

            def self.removePackage(name, locationOrConnection, dry = false)
                self.doConnection(locationOrConnection) do |connection|
                    distroInfo = self.currentDistroInfo(connection)
                    reposPackages = self.mapPackages([name], distroInfo['Name'])

                    pkgs = []
                    reposPackages.each do |pkg|
                        if pkg.include?('|')
                            repoName, pkg = pkg.split('|')
                            pkgs << pkg
                        else
                            pkgs << pkg
                        end
                    end

                    command = distroInfo['RemovePackage'] + ' ' + pkgs.map { |pkg| pkg.shellescape }.join(' ')
                    connection.adminExec(command, true, dry)
                    distroInfo
                end
            end

            def ensureServiceAutoStart(name, locationOrConnection)
                self.class.ensureServiceAutoStart(name, locationOrConnection)
            end

            def self.ensureServiceAutoStart(name, locationOrConnection)
                name = self.convertServiceName(name, locationOrConnection)
                self.execDistroCommand(name, 'AutoStartService', locationOrConnection)
            end

            # Deprecated
            def self.ensureServiceAutoStartOverSSH(name, locationOrConnection)
                self.ensureServiceAutoStart(name, locationOrConnection)
            end

            def startService(name, locationOrConnection, dry = false)
                self.class.startService(name, locationOrConnection, dry = false)
            end

            def self.startService(name, locationOrConnection, dry = false)
                name = self.convertServiceName(name, locationOrConnection)
                self.execDistroCommand(name, 'StartService', locationOrConnection, false, dry)
            end

            # Deprecated
            def self.startServiceOverSSH(name, locationOrConnection, dry = false)
                self.startService(name, locationOrConnection, dry)
            end

            def self.restartService(name, locationOrConnection, dry = false)
                name = self.convertServiceName(name, locationOrConnection)
                self.execDistroCommand(name, 'RestartService', locationOrConnection, false, dry)
            end

            def self.reloadService(name, locationOrConnection, dry = false)
                name = self.convertServiceName(name, locationOrConnection)
                self.execDistroCommand(name, 'ReloadService', locationOrConnection, false, dry)
            end

            def self.stopService(name, locationOrConnection, dry = false)
                name = self.convertServiceName(name, locationOrConnection)
                self.execDistroCommand(name, 'StopService', locationOrConnection, true, dry)
            end

            def self.disableService(name, locationOrConnection, dry = false)
                name = self.convertServiceName(name, locationOrConnection)
                self.execDistroCommand(name, 'DisableService', locationOrConnection, true, dry)
            end

            def self.reloadServiceManager(locationOrConnection, dry = false)
                self.execDistroCommand(nil, 'ReloadServiceManager', locationOrConnection, false, dry)
            end

            def self.deleteUserAndGroup(name, locationOrConnection, dry = false)
                self.execDistroCommand(name, 'DeleteUser', locationOrConnection, true, dry)
                self.execDistroCommand(name, 'DeleteGroup', locationOrConnection, true, dry)
            end

            def self.execDistroCommand(param, commandName, locationOrConnection, allowFailure = false, dry = false)
                self.doConnection(locationOrConnection) do |connection|
                    distroInfo = self.currentDistroInfo(connection)

                    command = distroInfo[commandName]
                    command += ' ' + param.shellescape unless param.nil?
                    connection.exec(command, allowFailure, dry)
                end
            end

            def self.convertServiceName(name, connection)
                self.doConnection(connection) do |connection|
                    if name.is_a?(Symbol)
                        distroInfo = self.currentDistroInfo(connection)
                        allServices = YAML.load_file(LINUX_FOLDER + 'Services.yaml')
                        distroName = distroInfo['Name']
                        raise "Distro '#{distroName}' not implemented!" unless allServices.key?(distroName)
                        name = allServices[distroName][name.to_s]
                    end
                end
                name
            end

            def self.doConnection(locationOrConnection, &block)
                if locationOrConnection.nil? || locationOrConnection == '@me'
                    result = block.call(nil)
                elsif locationOrConnection.is_a?(String) || locationOrConnection.is_a?(Addressable::URI)
                    prompt = TTY::Prompt.new
                    logger = TTY::Logger.new
                    IO::Connection.tunnel(locationOrConnection, {}, prompt, logger, &block)
                else
                    if locationOrConnection.is_a?(IO::Connection)
                        result = block.call(locationOrConnection)
                    else
                        prompt = TTY::Prompt.new
                        logger = TTY::Logger.new
                        result = block.call(IO::Connection.new(:SSH, IO::SSH.new(prompt, logger, locationOrConnection), prompt, logger))
                    end
                end
                result
            end

            # Deprecated
            def self.firewallAddServiceOverSSH(serviceName, locationOrConnection)
                self.firewallAddService(serviceName, locationOrConnection)
            end

            # Deprecated
            def self.firewallAddPortOverSSH(portName, locationOrConnection)
                self.firewallAddPort(portName, locationOrConnection)
            end

            def self.firewallAddService(serviceName, locationOrConnection = nil, dry = false)
                self.doConnection(locationOrConnection) do |connection|
                     command = 'firewall-cmd --permanent --add-service ' + serviceName.shellescape
                     connection.exec(command, true, dry)
                     command = 'firewall-cmd --add-service ' + serviceName.shellescape
                     connection.exec(command, true, dry)
                end
            end

            def self.firewallRemoveService(serviceName, locationOrConnection = nil, dry = false)
                self.doConnection(locationOrConnection) do |connection|
                     command = 'firewall-cmd --permanent --remove-service ' + serviceName.shellescape
                     connection.exec(command, false, dry)
                     command = 'firewall-cmd --remove-service ' + serviceName.shellescape
                     connection.exec(command, false, dry)
                end
            end

            def self.firewallAddPort(portName, locationOrConnection = nil, dry = false)
                self.doConnection(locationOrConnection) do |connection|
                     command = 'firewall-cmd --permanent --add-port ' + portName.shellescape
                     connection.exec(command, true, dry)
                     command = 'firewall-cmd --add-port ' + portName.shellescape
                     connection.exec(command, true, dry)
                end
            end

            def self.firewallRemovePort(portName, locationOrConnection = nil, dry = false)
                self.doConnection(locationOrConnection) do |connection|
                     command = 'firewall-cmd --permanent --remove-port ' + portName.shellescape
                     connection.exec(command, false, dry)
                     command = 'firewall-cmd --remove-port ' + portName.shellescape
                     connection.exec(command, false, dry)
                end
            end

            def self.mapPackages(packages, distroName)
                allPackages = YAML.load_file(LINUX_FOLDER + 'Packages.yaml')
                names = []
                raise "Distro '#{distroName}' not implemented!" unless allPackages.key?(distroName)
                distroPackages = allPackages[distroName].to_h
                packages.to_a.each do |pkg|
                    packageName = distroPackages[pkg]
                    if packageName
                        if packageName.is_a?(Array)
                            names += packageName
                        else
                            names << packageName
                        end
                    else
                        names << pkg.downcase
                    end
                end
                names
            end

            def self.createCertificateOverSSH(ssh)
                dir = "/etc/letsencrypt/live/Wildcard/"
                self.sshExec!(ssh, "mkdir -p #{dir}")
                # Need this temporarily before real certs are created
                if !self.remoteFilePresent?(dir + 'fullchain.pem', ssh)
                    self.sshExec!(ssh, "openssl req -x509 -noenc -days 90 -newkey rsa:2048 -keyout #{dir}privkey.pem -out #{dir}fullchain.pem -subj '/C=US/O=ConfigLMM/CN=Wildcard'")
                    self.sshExec!(ssh, "cp #{dir}fullchain.pem #{dir}chain.pem")
                end
                dir
            end

            def self.configurePodmanService(user, homedir, userComment, distroInfo, connection)
                self.configurePodmanServiceOverSSH(user, homedir, userComment, distroInfo, connection)
            end

            # DEPRECATED
            def self.configurePodmanServiceOverSSH(user, homedir, userComment, distroInfo, connectionOrSSH)
                if connectionOrSSH.is_a?(IO::Connection)
                    Framework::LinuxApp.ensurePackages([PODMAN_PACKAGE], connectionOrSSH)
                    addUserCmd = "#{distroInfo['CreateServiceUser']} --home-dir '#{homedir}' --create-home --comment '#{userComment}' #{user}"
                    connectionOrSSH.exec(addUserCmd, true)
                    connectionOrSSH.exec("chmod o-rwx #{homedir}")
                    self.createSubuids(user, distroInfo, connectionOrSSH)
                    connectionOrSSH.exec("loginctl enable-linger #{user}")
                    connectionOrSSH.exec("su --login #{user} --shell /bin/sh --command 'mkdir -p #{SYSTEMD_CONTAINERS_PATH}'")
                else
                    Framework::LinuxApp.ensurePackages([PODMAN_PACKAGE], connectionOrSSH)
                    addUserCmd = "#{distroInfo['CreateServiceUser']} --home-dir '#{homedir}' --create-home --comment '#{userComment}' #{user}"
                    self.sshExec!(connectionOrSSH, addUserCmd, true)
                    self.sshExec!(connectionOrSSH, "chmod o-rwx #{homedir}")
                    self.createSubuidsOverSSH(user, distroInfo, connectionOrSSH)
                    self.sshExec!(connectionOrSSH, "loginctl enable-linger #{user}")
                    self.sshExec!(connectionOrSSH, "su --login #{user} --shell /bin/sh --command 'mkdir -p #{SYSTEMD_CONTAINERS_PATH}'")
                end
            end

            def self.addRepo(name, distroInfo, connection)
                if distroInfo['Name'] == 'openSUSE Leap'
                    versionId = connection.exec('cat /etc/os-release | grep "^VERSION_ID=" | cut -d "=" -f 2').strip.gsub('"', '')
                    connection.exec("zypper addrepo https://download.opensuse.org/repositories/#{name}/#{versionId}/#{name}.repo", true)
                    connection.exec("zypper --gpg-auto-import-keys refresh")
                else
                    # TODO
                end
            end

            def self.createSubuids(user, distroInfo, connection)
                connection.exec("#{distroInfo['ModifyUser']} --add-subuids 100000-165535 --add-subgids 100000-165535 #{user}")
            end

            # DEPRECATED
            def self.createSubuidsOverSSH(user, distroInfo, ssh)
                self.sshExec!(ssh, "#{distroInfo['ModifyUser']} --add-subuids 100000-165535 --add-subgids 100000-165535 #{user}")
            end

            def self.distroID(connection = nil)
                cmd = 'cat /etc/os-release | grep "^ID=" | cut -d "=" -f 2'
                if connection
                    if connection.is_a?(IO::Connection)
                        connection.exec(cmd).strip.gsub('"', '')
                    else
                        connection.exec!(cmd).strip.gsub('"', '')
                    end
                else
                    `#{cmd}`.strip.gsub('"', '')
                end
            end

            def self.currentDistroInfo(connection)
                self.distroInfo(self.distroID(connection))
            end

            def self.distroInfo(distroID)
                distributions = YAML.load_file(LINUX_FOLDER + 'Distributions.yaml')
                raise Framework::PluginProcessError.new("Unknown Linux Distro: #{distroID}!") unless distributions.key?(distroID)
                distributions[distroID]
            end

        end
    end
end
