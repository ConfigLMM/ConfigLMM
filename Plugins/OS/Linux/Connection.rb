
require_relative 'Shell'

require 'shellwords'

module ConfigLMM
    module LMM
        class LinuxConnection

            attr_reader :connection
            attr_reader :local
            attr_reader :distroID
            attr_reader :distributions
            attr_reader :allServices

            def initialize(connection)
                @connection = connection
                @local = connection.local
                @distroID = self.class.distroID(@connection)
                @distributions = YAML.load_file(__dir__ + '/Distributions.yaml')
                @allServices = YAML.load_file(__dir__ + '/Services.yaml')
            end

            def prompt
                @connection.prompt
            end

            def logger
                @connection.logger
            end

            def distroInfo
                raise Framework::PluginProcessError.new("Unknown Linux Distro: #{distroID}!") unless distributions.key?(distroID)
                distributions[distroID]
            end

            def distroName
                distroInfo['Name']
            end

            def distroVersion
              @VersionId ||= connection.exec('cat /etc/os-release | grep "^VERSION_ID=" | cut -d "=" -f 2').strip.gsub('"', '')
              @VersionId
            end

            def exec(*args)
                connection.exec(*args)
            end

            def rm(*args)
                connection.rm(*args)
            end

            def filePresent?(*args)
                connection.filePresent?(*args)
            end

            def upload(*args)
                connection.upload(*args)
            end

            def download(*args)
                connection.download(*args)
            end

            def updateFile(*args, &block)
                connection.updateFile(*args, &block)
            end

            def uploadFolder(folder, target, options = {})
                createDirs(options, target + '/' + File.basename(folder))
                connection.uploadFolder(folder, target, options)
            end

            def fileWrite(target, data, options = {})
                hide = ''
                hide = ' ' if options[:hide]
                connection.exec("#{hide}echo #{data.shellescape} > #{target}", false, options)
            end

            def fileAppend(target, data, options = {})
                hide = ''
                hide = ' ' if options[:hide]
                connection.exec("#{hide}echo #{data.shellescape} >> #{target}", false, options)
            end

            def fileReplace(target, placeholder, result, options)
                hide = ''
                hide = ' ' if options[:hide]
                pattern = "s|#{placeholder}|#{result.to_s.gsub('\\', '\\\\\\').gsub('&', '\\\\&').gsub('|', '\\\\|')}|"
                connection.exec("#{hide}sed -i #{pattern.shellescape} #{target}", false, options)
            end

            def setUserGroup(path, user, group = nil, options = {})
                if group
                    connection.exec("chown -R #{user}:#{group} #{path.shellescape}", false, options)
                else
                    connection.exec("chown -R #{user} #{path.shellescape}", false, options)
                end
            end

            def setPrivate(path, options = {})
                connection.exec("chmod 600 #{path.shellescape}", false, options)
            end

            def createDirs(options, *paths)
                connection.exec("mkdir -p #{paths.join(' ')}", false, options)
            end

            def withUserShell(user)
               yield(LinuxShell.new(self, user))
            end

            def execDistroCommand(param, commandName, allowFailure = false, options = {})
                command = distroInfo[commandName]
                raise Framework::PluginProcessError.new('Invalid command!') unless command
                command += ' ' + param.shellescape unless param.nil?
                connection.exec(command, allowFailure, options)
            end

            def ensurePackage(name, options = {})
                ensurePackages([name], options)
            end

            def ensurePackages(names, options = {})
                reposPackages = Framework::LinuxApp.mapPackages(names, distroName)

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
                    addRepo(repoName)
                end
                command = distroInfo['InstallPackage'] + ' ' + pkgs.map { |pkg| pkg.shellescape }.join(' ')
                connection.adminExec(command, false, options)
            end

            def removePackage(name, options = {})
                reposPackages = Framework::LinuxApp.mapPackages([name], distroName)

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
                connection.adminExec(command, true, options)
            end

            def addRepo(name)
                if distroName == 'openSUSE Leap'
                    connection.exec("zypper addrepo https://download.opensuse.org/repositories/#{name}/#{distroVersion}/#{name}.repo", true)
                    connection.exec("zypper --gpg-auto-import-keys refresh")
                else
                    raise 'Not Implemented!'
                end
            end

            def ensureServiceAutoStart(name, options = {})
                name = convertServiceName(name)
                execDistroCommand(name, 'AutoStartService', false, options)
            end

            def startService(name, options = {})
                name = convertServiceName(name)
                execDistroCommand(name, 'StartService', false, options)
            end

            def restartService(name, options = {})
                name = convertServiceName(name)
                execDistroCommand(name, 'RestartService', false, options)
            end

            def reloadService(name, options = {})
                name = convertServiceName(name)
                execDistroCommand(name, 'ReloadService', false, options)
            end

            def stopService(name, options = {})
                name = convertServiceName(name)
                execDistroCommand(name, 'StopService', true, options)
            end

            def disableService(name, options = {})
                name = convertServiceName(name)
                execDistroCommand(name, 'DisableService', true, options)
            end

            def reloadServiceManager(options = {})
                execDistroCommand(nil, 'ReloadServiceManager', false, options)
            end

            def deleteUserAndGroup(name, options = {})
                execDistroCommand(name, 'DeleteUser', true, options)
                execDistroCommand(name, 'DeleteGroup', true, options)
            end

            def firewallAddPort(portName, options = {})
                command = 'firewall-cmd --quiet --permanent --add-port ' + portName.shellescape
                connection.exec(command, true, options)
                command = 'firewall-cmd --quiet --add-port ' + portName.shellescape
                connection.exec(command, true, options)
            end

            def firewallRemovePort(portName, options = {})
                command = 'firewall-cmd --quiet --permanent --remove-port ' + portName.shellescape
                connection.exec(command, false, options)
                command = 'firewall-cmd --quiet --remove-port ' + portName.shellescape
                connection.exec(command, false, options)
            end

            def firewallAddService(serviceName, options = {})
                command = 'firewall-cmd --permanent --add-service ' + serviceName.shellescape
                connection.exec(command, true, options)
                command = 'firewall-cmd --add-service ' + serviceName.shellescape
                connection.exec(command, true, options)
            end

            def firewallRemoveService(serviceName, options = {})
                command = 'firewall-cmd --permanent --remove-service ' + serviceName.shellescape
                connection.exec(command, false, options)
                command = 'firewall-cmd --remove-service ' + serviceName.shellescape
                connection.exec(command, false, options)
            end

            def createServiceUser(user, homedir, userComment = '', options = {})
                addUserCmd = "#{distroInfo['CreateServiceUser']} --home-dir #{homedir.shellescape} --create-home --comment #{userComment.shellescape} #{user.shellescape}"
                connection.exec(addUserCmd, true, options)
                connection.exec("chmod o-rwx #{homedir.shellescape}", false, options)
            end

            def createSubuids(user, options, uids = '100000-165535', guids = '100000-165535')
                connection.exec("#{distroInfo['ModifyUser']} --add-subuids #{uids} --add-subgids #{guids} #{user.shellescape}", options)
            end

            def enableLinger(user, options)
                connection.exec("loginctl enable-linger #{user.shellescape}", options)
            end

            def reloadUserServices(user, options = {})
                connection.exec("systemctl --user --machine=#{user}@ daemon-reload", false, options)
            end

            def stopUserService(user, service, options = {})
                connection.exec("systemctl --user --machine=#{user}@ stop #{service}", true, options)
            end

            def restartUserService(user, service, options = {})
                connection.exec("systemctl --user --machine=#{user}@ restart #{service}", false, options)
            end

            def convertServiceName(name)
                if name.is_a?(Symbol)
                    raise "Distro '#{distroName}' not implemented!" unless allServices.key?(distroName)
                    serviceName = allServices[distroName][name.to_s]
                    name = serviceName || name.to_s
                end
                name
            end

            def createWildecardCertificate(options = {})
                dir = "/etc/letsencrypt/live/Wildcard/"
                createDirs(options,  dir)
                # Need this temporarily before real certs are created
                if !connection.filePresent?(dir + 'fullchain.pem', { **options, 'dry' => false })
                    connection.exec("openssl req -x509 -noenc -days 90 -newkey rsa:2048 -keyout #{dir}privkey.pem -out #{dir}fullchain.pem -subj '/C=US/O=ConfigLMM/CN=Wildcard'", false, options)
                    connection.exec("cp #{dir}fullchain.pem #{dir}chain.pem", false, options)
                end
                dir
            end

            def self.distroID(connection = nil)
                cmd = 'cat /etc/os-release | grep "^ID=" | cut -d "=" -f 2'
                if connection
                    if connection.is_a?(IO::Connection) || connection.is_a?(IO::Local)
                        connection.exec(cmd).strip.gsub('"', '')
                    else
                        connection.exec!(cmd).strip.gsub('"', '')
                    end
                else
                    `#{cmd}`.strip.gsub('"', '')
                end
            end

        end
    end
end
