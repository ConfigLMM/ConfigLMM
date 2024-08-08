# frozen_string_literal: true

module ConfigLMM
    module Framework

        class LinuxApp < Framework::Plugin

            LINUX_FOLDER = __dir__ + '/../../../../Plugins/OS/Linux/'
            SUSE_NAME = 'openSUSE Leap'
            SUSE_ID = 'opensuse-leap'
            PODMAN_PACKAGE = 'Podman'
            SYSTEMD_CONTAINERS_PATH = '~/.config/containers/systemd/'

            def ensurePackage(name, location)
              self.class.ensurePackages([name], location)
            end

            def ensurePackages(names, location)
              self.class.ensurePackages(names, location)
            end

            def self.ensurePackages(names, location)
                if location && location != '@me'
                    uri = Addressable::URI.parse(location)
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.ensurePackagesOverSSH(names, uri)
                else
                    # TODO
                end
            end

            def self.ensurePackagesOverSSH(names, locationOrSSH)
                distroInfo = nil
                closure = Proc.new do |ssh|
                    distroInfo = self.distroInfoFromSSH(ssh)
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
                        self.addRepoOverSSH(repoName, distroInfo, ssh)
                    end
                    command = distroInfo['InstallPackage'] + ' ' + pkgs.map { |pkg| pkg.shellescape }.join(' ')
                    self.sshExec!(ssh, command)
                    distroInfo
                end

                if locationOrSSH.is_a?(String) || locationOrSSH.is_a?(Addressable::URI)
                    self.sshStart(locationOrSSH) do |ssh|
                        distroInfo = closure.call(ssh)
                    end
                else
                    distroInfo = closure.call(locationOrSSH)
                end
                distroInfo
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

            def self.ensureServiceAutoStartOverSSH(name, locationOrSSH)
                closure = Proc.new do |ssh|
                    distroInfo = self.distroInfoFromSSH(ssh)

                    command = distroInfo['AutoStartService'] + ' ' + name.shellescape
                    self.sshExec!(ssh, command)
                end

                if locationOrSSH.is_a?(String) || locationOrSSH.is_a?(Addressable::URI)
                    self.sshStart(locationOrSSH) do |ssh|
                        closure.call(ssh)
                    end
                else
                    closure.call(locationOrSSH)
                end
            end

            def startService(name, location)
                if location && location != '@me'
                    uri = Addressable::URI.parse(location)
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.class.startServiceOverSSH(name, location)
                else
                    # TODO
                end
            end

            def self.startServiceOverSSH(name, locationOrSSH)
                 closure = Proc.new do |ssh|
                     distroInfo = self.distroInfoFromSSH(ssh)

                     command = distroInfo['StartService'] + ' ' + name.shellescape
                     self.sshExec!(ssh, command)
                 end

                if locationOrSSH.is_a?(String) || locationOrSSH.is_a?(Addressable::URI)
                    self.sshStart(locationOrSSH) do |ssh|
                        closure.call(ssh)
                    end
                else
                    closure.call(locationOrSSH)
                end
            end


            def self.firewallAddServiceOverSSH(serviceName, locationOrSSH)
                 closure = Proc.new do |ssh|
                     command = 'firewall-cmd --permanent --add-service ' + serviceName.shellescape
                     self.sshExec!(ssh, command, true)
                     command = 'firewall-cmd --add-service ' + serviceName.shellescape
                     self.sshExec!(ssh, command, true)
                 end

                if locationOrSSH.is_a?(String) || locationOrSSH.is_a?(Addressable::URI)
                    self.sshStart(locationOrSSH) do |ssh|
                        closure.call(ssh)
                    end
                else
                    closure.call(locationOrSSH)
                end
            end

            def self.firewallAddPortOverSSH(portName, locationOrSSH)
                 closure = Proc.new do |ssh|
                     command = 'firewall-cmd --permanent --add-port ' + portName.shellescape
                     self.sshExec!(ssh, command, true)
                     command = 'firewall-cmd --add-port ' + portName.shellescape
                     self.sshExec!(ssh, command, true)
                 end

                if locationOrSSH.is_a?(String) || locationOrSSH.is_a?(Addressable::URI)
                    self.sshStart(locationOrSSH) do |ssh|
                        closure.call(ssh)
                    end
                else
                    closure.call(locationOrSSH)
                end
            end

            def self.mapPackages(packages, distroName)
                distroPackages = YAML.load_file(LINUX_FOLDER + 'Packages.yaml')
                names = []
                packages.to_a.each do |pkg|
                    packageName = distroPackages[distroName][pkg]
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
                Framework::LinuxApp.ensurePackagesOverSSH([PODMAN_PACKAGE], ssh)
                addUserCmd = "#{distroInfo['CreateServiceUser']} --home-dir '#{homedir}' --create-home --comment '#{userComment}' #{user}"
                self.sshExec!(ssh, addUserCmd, true)
                self.createSubuidsOverSSH(user, distroInfo, ssh)
                self.sshExec!(ssh, "loginctl enable-linger #{user}")
                self.sshExec!(ssh, "su --login #{user} --shell /bin/sh --command 'mkdir -p #{SYSTEMD_CONTAINERS_PATH}'")
            end

            def self.addRepoOverSSH(name, distroInfo, ssh)
                if distroInfo['Name'] == 'openSUSE Leap'
                    versionId = ssh.exec!('cat /etc/os-release | grep "^VERSION_ID=" | cut -d "=" -f 2').strip.gsub('"', '')
                    self.sshExec!(ssh, "zypper addrepo https://download.opensuse.org/repositories/#{name}/#{versionId}/#{name}.repo", true)
                    self.sshExec!(ssh, "zypper --gpg-auto-import-keys refresh")
                else
                    # TODO
                end
            end

            def self.createSubuidsOverSSH(user, distroInfo, ssh)
                self.sshExec!(ssh, "#{distroInfo['ModifyUser']} --add-subuids 100000-165535 --add-subgids 100000-165535 #{user}")
            end

            def self.distroID
                `cat /etc/os-release | grep "^ID=" | cut -d "=" -f 2`.strip.gsub('"', '')
            end

            def self.distroIDfromSSH(ssh)
                ssh.exec!('cat /etc/os-release | grep "^ID=" | cut -d "=" -f 2').strip.gsub('"', '')
            end

            def self.distroInfoFromSSH(ssh)
                distroInfo = self.distroInfo(self.distroIDfromSSH(ssh))
            end

            def self.distroInfo(distroID)
                distributions = YAML.load_file(LINUX_FOLDER + 'Distributions.yaml')
                raise Framework::PluginProcessError.new("Unknown Linux Distro: #{distroID}!") unless distributions.key?(distroID)
                distributions[distroID]
            end

        end
    end
end
