
require_relative 'Shell'
require_relative 'HTTP'

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

            def fileLink?(*args)
                connection.fileLink?(*args)
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

            def ensureFile(file, options = {})
                connection.exec("touch #{file.shellescape}", false, options)
            end

            def fileContains?(file, content, options = {})
                !connection.exec("grep #{content.shellescape} #{file}", true, options).strip.empty?
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

            def fileMerge(target, file, options = {})
                connection.exec("cat #{file.shellescape} >> #{target}", false, options)
            end

            def fileReplace(target, placeholder, result, options = {})
                hide = ''
                hide = ' ' if options[:hide]
                result = result.to_s.gsub('\\', '\\\\\\') if options[:escape] != false
                pattern = "s|#{placeholder}|#{result.to_s.gsub('&', '\\\\&').gsub('|', '\\\\|')}|"
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

            def makeAccessible(path, options = {})
                connection.exec("chmod og+rX #{path.shellescape}", false, options)
            end

            def createDirs(options, *paths)
                connection.exec("mkdir -p #{paths.join(' ')}", false, options)
            end

            def http(url, options, headers = {}, method = 'GET', data = nil, cookieFile = nil)
                cmd = "curl --no-progress-meter #{url.shellescape} -X #{method}"
                if cookieFile
                    cmd += " --cookie #{cookieFile.shellescape} --cookie-jar #{cookieFile.shellescape}"
                end
                headers.each do |name, value|
                    cmd += " -H '#{name}: #{value}'"
                end
                if !data.nil?
                    cmd += " --data-raw #{data.shellescape}"
                end
                connection.exec(cmd, false, options)
            end

            def withHTTP(options)
                http = HttpConnection.new(self, options)
                result = yield(http)
                result
            ensure
                http.cleanup
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
                githubPackages = []

                reposPackages.each do |pkg|
                    if pkg.include?('|')
                        repoName, pkg = pkg.split('|')
                        if repoName == 'GitHub'
                            githubPackages << pkg
                        else
                            repos << repoName
                            pkgs << pkg
                        end
                    else
                        pkgs << pkg
                    end
                end
                repos.each do |repoName|
                    addRepo(repoName, options)
                end

                if !pkgs.empty?
                    command = distroInfo['InstallPackage'] + ' ' + pkgs.map { |pkg| pkg.shellescape }.join(' ')
                    connection.adminExec(command, false, options)
                end

                handleGitHubPackages(githubPackages, options) unless githubPackages.empty?
            end

            def handleGitHubPackages(githubPackages, options)
                githubPackages.each do |pkg|
                    repo, name = pkg.split(':')
                    namePattern = name.gsub('.', '\\.').gsub('*', '.*')
                    releases = GitHub::getReleases(repo, logger, {}, options)
                    releases.each do |release|
                        break if installGitHubRelease(release, namePattern, options)
                    end
                end
            end

            def installGitHubRelease(release, namePattern, options)
                release['assets'].each do |asset|
                    if asset['name'].match?(namePattern)
                        if asset['name'].end_with?('.rpm')
                            installRPM(asset['name'], asset['browser_download_url'], options)
                        elsif asset['name'].end_with?('.deb')
                            installDeb(asset['name'], asset['browser_download_url'], options)
                        elsif !asset['name'].include?('.')
                            binaryName = asset['name'].gsub(/\-(linux|amd64|x64|bin)/, '')
                            connection.exec("curl --silent --location --output /tmp/#{binaryName} #{asset['browser_download_url']}", false, options)
                            connection.exec("chmod +rx /tmp/#{binaryName}", false, options)
                            connection.adminExec("mv /tmp/#{binaryName} /usr/local/bin/", false, options)
                        else
                            $stderr.puts(asset)
                            raise 'Not Implemented!'
                        end
                        return true
                    end
                end
                false
            end

            def installRPM(name, url, options)
                command = "rpm -U #{url.shellescape}"
                connection.adminExec(command, true, options)
            end

            def installDeb(name, url, options)
                pkgName = name.split('_').first
                command = "dpkg-query --status #{pkgName.shellescape} | grep Version: | cut -d ' ' -f 2"
                version = connection.exec(command, false, { **options, 'dry' => false }).strip
                if version.empty? || !name.include?(version)
                    command = "curl --silent --location --output /tmp/pkg.deb #{url.shellescape}"
                    connection.exec(command, false, options)

                    command = "dpkg --install /tmp/pkg.deb"
                    connection.adminExec(command, false, options)

                    connection.rm('/tmp/pkg.deb', options['dry'])
                end
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

            def addRepo(name, options)
                if distroName == Linux::SUSE_NAME
                    connection.exec("zypper addrepo https://download.opensuse.org/repositories/#{name}/#{distroVersion}/#{name}.repo", true, options)
                    connection.exec("zypper --gpg-auto-import-keys refresh", false, options)
                else
                    raise 'Not Implemented!'
                end
            end

            def hasBinaries?(names, options)
                names = [names] unless names.is_a?(Array)
                names.each do |name|
                    connection.exec("which #{name}", true, options) if options['dry']
                    result = connection.exec("which #{name}", true, { **options, 'dry' => false }).strip
                    return false if result.empty? || result.include?("no #{name}")
                end
                true
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
                result = connection.exec(addUserCmd, true, options)
                raise Framework::PluginProcessError.new(result) if result.strip.start_with?('useradd:') && !result.include?("user '#{user}' already exists")
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
