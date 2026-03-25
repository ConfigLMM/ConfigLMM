require_relative 'Connection'

require 'uri'

module ConfigLMM
    module LMM
        class Podman < Framework::Plugin

            PACKAGE_NAME = 'Podman'
            SYSTEM_CONTAINERS_PATH = '/etc/containers/systemd'
            USER_CONTAINERS_PATH = '~/.config/containers/systemd'
            HOST_IP = '10.0.2.2'

            def self.ensurePresent(linuxConnection, options = {})
                linuxConnection.ensurePackage(PACKAGE_NAME, options)
                # This is needed for openSUSE Leap so that rootless Podman works
                Systemd::enableUserCgroups(linuxConnection, options)
            end

            def self.container(name, connection, options = {})
                result = connection.exec("podman ps --format json --filter name='^#{name}$'", false, { **options, dry: false }).strip
                containers = JSON.parse(result)
                raise "Failed to find container #{name}!" if containers.empty?
                containers.first
            rescue JSON::ParserError => error
                return { 'Id' => name } if options['dry']
                raise error
            end

            def self.withConnection(connection, container)
                yield(PodmanConnection.new(connection, container))
            end

            def self.run(imageId, name, cmd, linuxConnection, options)
                linuxConnection.exec("podman run --name #{name} --replace --rm -it #{imageId} #{cmd}")
            end

            def self.createUser(user, homedir, userComment, linuxConnection, options)
                linuxConnection.createServiceUser(user, homedir, userComment, options)
                linuxConnection.createSubuids(user, options)
                linuxConnection.enableLinger(user, options)
                linuxConnection.withUserShell(user) do |shell|
                    shell.createDirs(options, USER_CONTAINERS_PATH)
                end
                # This is a workaround for performance issue with Podman --userns keep-id
                # See https://github.com/containers/podman/issues/16541
                linuxConnection.upload(__dir__ + '/storage.conf', homedir + '/.config/containers/', options)
            end

            def self.loadImage(userShell, imageFile, options = {})
                cmd = "podman image load --input '#{imageFile.shellescape}'"
                userShell.exec(cmd, false, options)
            end

            def self.removeImage(userShell, imageFile, options = {})
                cmd = "podman image rm --ignore '#{imageFile.shellescape}'"
                userShell.exec(cmd, false, options)
            end

            def self.containersPath(homeDir = nil)
                if homeDir.nil?
                    SYSTEM_CONTAINERS_PATH
                else
                    USER_CONTAINERS_PATH.gsub('~', homeDir)
                end
            end

            def self.updateHost(host)
                host = HOST_IP if host.to_s.empty? || ['localhost', '127.0.0.1', '::1'].include?(host)
                host
            end

            def self.updateURL(url, defaultPort = nil)
                uri = URI.parse(url.to_s)
                uri.scheme = 'http' unless uri.scheme
                uri.port = defaultPort if !uri.port && defaultPort
                uri.host = self.updateHost(uri.host)
                uri.to_s
            end
        end
    end
end
