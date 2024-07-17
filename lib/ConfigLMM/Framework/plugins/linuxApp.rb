# frozen_string_literal: true

module ConfigLMM
    module Framework

        class LinuxApp < Framework::Plugin

            LINUX_FOLDER = __dir__ + '/../../../../Plugins/OS/Linux/'
            SUSE_NAME = 'openSUSE Leap'
            SUSE_ID = 'opensuse-leap'

            def ensurePackage(name, location)
              self.class.ensurePackage(name, location)
            end

            def self.ensurePackage(name, location)
                if location && location != '@me'
                    uri = Addressable::URI.parse(location)
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.ensurePackageOverSSH(name, uri)
                else
                    # TODO
                end
            end

            def self.ensurePackageOverSSH(name, locationOrSSH)

                closure = Proc.new do |ssh|
                    distroInfo = self.distroInfoFromSSH(ssh)
                    pkg = self.mapPackages([name], distroInfo['Name']).first

                    command = distroInfo['InstallPackage'] + ' ' + pkg.shellescape
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

            def ensureServiceAutoStart(name, location)
                if location && location != '@me'
                    uri = Addressable::URI.parse(location)
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.class.sshStart(uri) do |ssh|
                        distroInfo = self.class.distroInfoFromSSH(ssh)

                        command = distroInfo['AutoStartService'] + ' ' + name.shellescape
                        self.class.sshExec!(ssh, command)
                    end
                else
                    # TODO
                end
            end

            def startService(name, location)
                if location && location != '@me'
                    uri = Addressable::URI.parse(location)
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.class.sshStart(uri) do |ssh|
                        distroInfo = self.class.distroInfoFromSSH(ssh)

                        command = distroInfo['StartService'] + ' ' + name.shellescape
                        self.class.sshExec!(ssh, command)
                    end
                else
                    # TODO
                end
            end

            def self.mapPackages(packages, distroName)
                distroPackages = YAML.load_file(LINUX_FOLDER + 'Packages.yaml')
                names = []
                packages.to_a.each do |pkg|
                    packageName = distroPackages[distroName][pkg]
                    if packageName
                        names << packageName
                    else
                        names << pkg.downcase
                    end
                end
                names
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
