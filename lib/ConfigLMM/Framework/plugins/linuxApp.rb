# frozen_string_literal: true

require 'tty-which'

module ConfigLMM
    module Framework

        class LinuxApp < Framework::Plugin

            LINUX_FOLDER = __dir__ + '/../../../../Plugins/OS/Linux/'
            SUSE_NAME = 'openSUSE Leap'
            SUSE_ID = 'opensuse-leap'
            PROXMOXVE_NAME = 'Proxmox VE'
            PODMAN_PACKAGE = 'Podman'
            SYSTEMD_CONTAINERS_PATH = '~/.config/containers/systemd/'

            def ensurePackage(name, location, binary = nil)
                self.class.ensurePackage(name, location, binary)
            end

            def ensurePackages(names, location)
                self.class.ensurePackages(names, location)
            end

            def self.ensurePackage(name, location, binary = nil)
                if binary && TTY::Which.which(binary)
                    return
                end
                self.ensurePackages([name], location)
            end

            def self.ensurePackages(names, locationOrSSH)
                self.doSSH(locationOrSSH) do |ssh|
                    distroInfo = self.currentDistroInfo(ssh)
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
                        self.addRepo(repoName, distroInfo, ssh)
                    end
                    command = distroInfo['InstallPackage'] + ' ' + pkgs.map { |pkg| pkg.shellescape }.join(' ')
                    if ssh
                        self.sshExec!(ssh, command)
                    else
                        if `echo $EUID`.strip == '0'
                            `#{command} >/dev/null`
                        else
                            `sudo #{command} >/dev/null`
                        end
                    end
                    distroInfo
                end
            end

            def self.removePackage(name, locationOrSSH, dry = false)
                self.doSSH(locationOrSSH) do |ssh|
                    distroInfo = self.currentDistroInfo(ssh)
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
                    if ssh
                        self.sshExec!(ssh, command, true, dry)
                    else
                        if `echo $EUID`.strip == '0'
                            if dry
                                puts "Would execute: #{command} >/dev/null"
                            else
                                `#{command} >/dev/null`
                            end
                        else
                            if dry
                                puts "Would execute: sudo #{command} >/dev/null"
                            else
                                `sudo #{command} >/dev/null`
                            end
                        end
                    end
                    distroInfo
                end
            end

            def ensureServiceAutoStart(name, location)
                if location && location != '@me'
                    uri = Addressable::URI.parse(location)
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.class.ensureServiceAutoStartOverSSH(name, uri)
                else
                    # TODO
                end
            end

            def self.ensureServiceAutoStart(name, locationOrSSH)
                self.execDistroCommand(name, 'AutoStartService', locationOrSSH)
            end

            # Deprecated
            def self.ensureServiceAutoStartOverSSH(name, locationOrSSH)
                self.ensureServiceAutoStart(name, locationOrSSH)
            end

            def startService(name, location, dry = false)
                if location && location != '@me'
                    uri = Addressable::URI.parse(location)
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.class.startService(name, location, dry = false)
                else
                    # TODO
                end
            end

            def self.startService(name, locationOrSSH, dry = false)
                self.execDistroCommand(name, 'StartService', locationOrSSH, false, dry)
            end

            # Deprecated
            def self.startServiceOverSSH(name, locationOrSSH, dry = false)
                self.startService(name, locationOrSSH, dry)
            end

            def self.restartService(name, locationOrSSH, dry = false)
                self.execDistroCommand(name, 'RestartService', locationOrSSH, false, dry)
            end

            def self.reloadService(name, locationOrSSH, dry = false)
                self.execDistroCommand(name, 'ReloadService', locationOrSSH, false, dry)
            end

            def self.stopService(name, locationOrSSH, dry = false)
                self.execDistroCommand(name, 'StopService', locationOrSSH, true, dry)
            end

            def self.disableService(name, locationOrSSH, dry = false)
                self.execDistroCommand(name, 'DisableService', locationOrSSH, true, dry)
            end

            def self.reloadServiceManager(locationOrSSH, dry = false)
                self.execDistroCommand(nil, 'ReloadServiceManager', locationOrSSH, false, dry)
            end

            def self.deleteUserAndGroup(name, locationOrSSH, dry = false)
                self.execDistroCommand(name, 'DeleteUser', locationOrSSH, true, dry)
                self.execDistroCommand(name, 'DeleteGroup', locationOrSSH, true, dry)
            end

            def self.execDistroCommand(param, commandName, locationOrSSH, allowFailure = false, dry = false)
                self.doSSH(locationOrSSH) do |ssh|
                    distroInfo = self.currentDistroInfo(ssh)

                    command = distroInfo[commandName]
                    command += ' ' + param.shellescape unless param.nil?
                    self.exec(command, ssh, allowFailure, dry)
                end
            end

            def self.doSSH(locationOrSSH, &block)
                if locationOrSSH.nil? || locationOrSSH == '@me'
                    result = block.call(nil)
                elsif locationOrSSH.is_a?(String) || locationOrSSH.is_a?(Addressable::URI)
                    uri = Addressable::URI.parse(locationOrSSH)
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.sshStart(locationOrSSH) do |ssh|
                        result = block.call(ssh)
                    end
                else
                    result = block.call(locationOrSSH)
                end
                result
            end

            # Deprecated
            def self.firewallAddServiceOverSSH(serviceName, locationOrSSH)
                self.firewallAddService(serviceName, locationOrSSH)
            end

            # Deprecated
            def self.firewallAddPortOverSSH(portName, locationOrSSH)
                self.firewallAddPort(portName, locationOrSSH)
            end

            def self.firewallAddService(serviceName, locationOrSSH = nil, dry = false)
                self.doSSH(locationOrSSH) do |ssh|
                     command = 'firewall-cmd --permanent --add-service ' + serviceName.shellescape
                     self.exec(command, ssh, true, dry)
                     command = 'firewall-cmd --add-service ' + serviceName.shellescape
                     self.exec(command, ssh, true, dry)
                end
            end

            def self.firewallRemoveService(serviceName, locationOrSSH = nil, dry = false)
                self.doSSH(locationOrSSH) do |ssh|
                     command = 'firewall-cmd --permanent --remove-service ' + serviceName.shellescape
                     self.exec(command, ssh, false, dry)
                     command = 'firewall-cmd --remove-service ' + serviceName.shellescape
                     self.exec(command, ssh, false, dry)
                end
            end

            def self.firewallAddPort(portName, locationOrSSH = nil, dry = false)
                self.doSSH(locationOrSSH) do |ssh|
                     command = 'firewall-cmd --permanent --add-port ' + portName.shellescape
                     self.exec(command, ssh, true, dry)
                     command = 'firewall-cmd --add-port ' + portName.shellescape
                     self.exec(command, ssh, true, dry)
                end
            end

            def self.firewallRemovePort(portName, locationOrSSH = nil, dry = false)
                self.doSSH(locationOrSSH) do |ssh|
                     command = 'firewall-cmd --permanent --remove-port ' + portName.shellescape
                     self.exec(command, ssh, false, dry)
                     command = 'firewall-cmd --remove-port ' + portName.shellescape
                     self.exec(command, ssh, false, dry)
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

            def self.configurePodmanServiceOverSSH(user, homedir, userComment, distroInfo, ssh)
                Framework::LinuxApp.ensurePackages([PODMAN_PACKAGE], ssh)
                addUserCmd = "#{distroInfo['CreateServiceUser']} --home-dir '#{homedir}' --create-home --comment '#{userComment}' #{user}"
                self.sshExec!(ssh, addUserCmd, true)
                self.sshExec!(ssh, "chmod o-rwx #{homedir}")
                self.createSubuidsOverSSH(user, distroInfo, ssh)
                self.sshExec!(ssh, "loginctl enable-linger #{user}")
                self.sshExec!(ssh, "su --login #{user} --shell /bin/sh --command 'mkdir -p #{SYSTEMD_CONTAINERS_PATH}'")
            end

            def self.addRepo(name, distroInfo, ssh = nil)
                if distroInfo['Name'] == 'openSUSE Leap'
                    if ssh
                        versionId = ssh.exec!('cat /etc/os-release | grep "^VERSION_ID=" | cut -d "=" -f 2').strip.gsub('"', '')
                        self.sshExec!(ssh, "zypper addrepo https://download.opensuse.org/repositories/#{name}/#{versionId}/#{name}.repo", true)
                        self.sshExec!(ssh, "zypper --gpg-auto-import-keys refresh")
                    else
                        versionId = `cat /etc/os-release | grep "^VERSION_ID=" | cut -d "=" -f 2`.strip.gsub('"', '')
                        `zypper addrepo https://download.opensuse.org/repositories/#{name}/#{versionId}/#{name}.repo`
                        `zypper --gpg-auto-import-keys refresh`
                    end
                else
                    # TODO
                end
            end

            def self.createSubuidsOverSSH(user, distroInfo, ssh)
                self.sshExec!(ssh, "#{distroInfo['ModifyUser']} --add-subuids 100000-165535 --add-subgids 100000-165535 #{user}")
            end

            def self.distroID(ssh = nil)
                if ssh
                    ssh.exec!('cat /etc/os-release | grep "^ID=" | cut -d "=" -f 2').strip.gsub('"', '')
                else
                    `cat /etc/os-release | grep "^ID=" | cut -d "=" -f 2`.strip.gsub('"', '')
                end
            end

            def self.currentDistroInfo(ssh)
                self.distroInfo(self.distroID(ssh))
            end

            def self.distroInfo(distroID)
                distributions = YAML.load_file(LINUX_FOLDER + 'Distributions.yaml')
                raise Framework::PluginProcessError.new("Unknown Linux Distro: #{distroID}!") unless distributions.key?(distroID)
                distributions[distroID]
            end

        end
    end
end
