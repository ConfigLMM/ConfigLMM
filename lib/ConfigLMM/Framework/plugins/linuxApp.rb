# frozen_string_literal: true

require 'tty-which'

module ConfigLMM
    module Framework

        class LinuxApp < Framework::Plugin

            LINUX_FOLDER = __dir__ + '/../../../../Plugins/OS/Linux/'
            SUSE_ID = 'opensuse-leap'
            PODMAN_PACKAGE = 'Podman'
            SYSTEMD_CONTAINERS_PATH = '~/.config/containers/systemd/'

            # DEPRECATED
            def ensurePackage(name, location, binary = nil)
                self.class.ensurePackage(name, location, binary)
            end

            # DEPRECATED
            def ensurePackages(names, location)
                self.class.ensurePackages(names, location)
            end

            # DEPRECATED
            def self.ensurePackage(name, locationOrConnection, binary = nil)
                if binary && TTY::Which.which(binary)
                    return
                end
                self.ensurePackages([name], locationOrConnection)
            end

            # DEPRECATED
            def self.ensurePackages(names, locationOrConnection)
                self.doConnection(locationOrConnection) do |connection|
                    linuxConnection = LMM::LinuxConnection.new(connection)
                    linuxConnection.ensurePackages(names)
                    linuxConnection.distroInfo
                end
            end

            # DEPRECATED
            def self.removePackage(name, locationOrConnection, dry = false)
                self.doConnection(locationOrConnection) do |connection|
                    linuxConnection = LMM::LinuxConnection.new(connection)
                    linuxConnection.removePackage(name)
                    linuxConnection.distroInfo
                end
            end

            # DEPRECATED
            def ensureServiceAutoStart(name, locationOrConnection)
                self.class.ensureServiceAutoStart(name, locationOrConnection)
            end

            # DEPRECATED
            def self.ensureServiceAutoStart(name, locationOrConnection)
                name = self.convertServiceName(name, locationOrConnection)
                self.execDistroCommand(name, 'AutoStartService', locationOrConnection)
            end

            # DEPRECATED
            def self.ensureServiceAutoStartOverSSH(name, locationOrConnection)
                self.ensureServiceAutoStart(name, locationOrConnection)
            end

            # DEPRECATED
            def startService(name, locationOrConnection, dry = false)
                self.class.startService(name, locationOrConnection, dry = false)
            end

            # DEPRECATED
            def self.startService(name, locationOrConnection, dry = false)
                name = self.convertServiceName(name, locationOrConnection)
                self.execDistroCommand(name, 'StartService', locationOrConnection, false, dry)
            end

            # DEPRECATED
            def self.startServiceOverSSH(name, locationOrConnection, dry = false)
                name = self.convertServiceName(name, locationOrConnection)
                self.startService(name, locationOrConnection, dry)
            end

            # DEPRECATED
            def self.restartService(name, locationOrConnection, dry = false)
                name = self.convertServiceName(name, locationOrConnection)
                self.execDistroCommand(name, 'RestartService', locationOrConnection, false, dry)
            end

            # DEPRECATED
            def self.reloadService(name, locationOrConnection, dry = false)
                name = self.convertServiceName(name, locationOrConnection)
                self.execDistroCommand(name, 'ReloadService', locationOrConnection, false, dry)
            end

            # DEPRECATED
            def self.stopService(name, locationOrConnection, dry = false)
                name = self.convertServiceName(name, locationOrConnection)
                self.execDistroCommand(name, 'StopService', locationOrConnection, true, dry)
            end

            # DEPRECATED
            def self.disableService(name, locationOrConnection, dry = false)
                name = self.convertServiceName(name, locationOrConnection)
                self.execDistroCommand(name, 'DisableService', locationOrConnection, true, dry)
            end

            # DEPRECATED
            def self.reloadServiceManager(locationOrConnection, dry = false)
                self.execDistroCommand(nil, 'ReloadServiceManager', locationOrConnection, false, dry)
            end

            # DEPRECATED
            def self.deleteUserAndGroup(name, locationOrConnection, dry = false)
                self.execDistroCommand(name, 'DeleteUser', locationOrConnection, true, dry)
                self.execDistroCommand(name, 'DeleteGroup', locationOrConnection, true, dry)
            end

            # DEPRECATED
            def self.execDistroCommand(param, commandName, locationOrConnection, allowFailure = false, dry = false)
                self.doConnection(locationOrConnection) do |connection|
                    LMM::LinuxConnection.new(connection).execDistroCommand(param, commandName, allowFailure, { 'dry': dry })
                end
            end

            # DEPRECATED
            def self.convertServiceName(name, connection)
                self.doConnection(connection) do |connection|
                    name = LMM::LinuxConnection.new(connection).convertServiceName(name)
                end
                name
            end

            def self.doConnection(locationOrConnection, &block)
                if locationOrConnection.nil? || locationOrConnection == '@me'
                    result = block.call(nil)
                elsif locationOrConnection.is_a?(String) || locationOrConnection.is_a?(Addressable::URI)
                    prompt = TTY::Prompt.new
                    logger = TTY::Logger.new
                    IO::Connection.tunnel(locationOrConnection, {}, {}, {}, prompt, logger, &block)
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

            # DEPRECATED
            def self.firewallAddServiceOverSSH(serviceName, locationOrConnection)
                self.firewallAddService(serviceName, locationOrConnection)
            end

            # DEPRECATED
            def self.firewallAddPortOverSSH(portName, locationOrConnection)
                self.firewallAddPort(portName, locationOrConnection)
            end

            # DEPRECATED
            def self.firewallAddService(serviceName, locationOrConnection = nil, dry = false)
                self.doConnection(locationOrConnection) do |connection|
                    LMM::LinuxConnection.new(connection).firewallAddService(serviceName, { 'dry': dry })
                end
            end

            # DEPRECATED
            def self.firewallRemoveService(serviceName, locationOrConnection = nil, dry = false)
                self.doConnection(locationOrConnection) do |connection|
                    LMM::LinuxConnection.new(connection).firewallRemoveService(serviceName, { 'dry': dry })
                end
            end

            # DEPRECATED
            def self.firewallAddPort(portName, locationOrConnection = nil, dry = false)
                self.doConnection(locationOrConnection) do |connection|
                    LMM::LinuxConnection.new(connection).firewallAddPort(portName, { 'dry': dry })
                end
            end

            # DEPRECATED
            def self.firewallRemovePort(portName, locationOrConnection = nil, dry = false)
                self.doConnection(locationOrConnection) do |connection|
                    LMM::LinuxConnection.new(connection).firewallRemovePort(portName, { 'dry': dry })
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

            # DEPRECATED
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

            # DEPRECATED
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

            # DEPRECATED
            def self.createSubuids(user, distroInfo, connection)
                connection.exec("#{distroInfo['ModifyUser']} --add-subuids 100000-165535 --add-subgids 100000-165535 #{user}")
            end

            # DEPRECATED
            def self.createSubuidsOverSSH(user, distroInfo, ssh)
                self.sshExec!(ssh, "#{distroInfo['ModifyUser']} --add-subuids 100000-165535 --add-subgids 100000-165535 #{user}")
            end

            # DEPRECATED
            def self.distroID(connection = nil)
                id = nil
                self.doConnection(connection) do |connection|
                    id = LMM::LinuxConnection.new(connection).distroID
                end
                id
            end

            # DEPRECATED
            def self.currentDistroInfo(connection)
                self.distroInfo(self.distroID(connection))
            end

            # DEPRECATED
            def self.distroInfo(distroID)
                YAML.load_file(LINUX_FOLDER + 'Distributions.yaml')[distroID]
            end

        end
    end
end
