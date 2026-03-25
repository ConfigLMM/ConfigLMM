require_relative 'Connection'
require_relative '../Git/Git'

require 'uri'

module ConfigLMM
    module LMM
        class Podman < Framework::Plugin

            PACKAGE_NAME = 'Podman'
            IMAGE_DOMAIN = 'ConfigLM.moe'
            NAMESPACE = 'moe.configlm'
            SYSTEM_CONTAINERS_PATH = '/etc/containers/systemd'
            USER_CONTAINERS_PATH = '~/.config/containers/systemd'
            HOST_IP = '10.0.2.2'
            HOST_LOOPBACK_IP = '10.0.2.2'
            HOST_LOOPBACK = 'host.loopback.internal'
            HOST_IP = '169.254.1.2'
            HOST_NAME = 'host.containers.internal'

            def self.ensurePresent(linuxConnection, options = {})
                linuxConnection.ensurePackage(PACKAGE_NAME, options)
                # This is needed for openSUSE Leap so that rootless Podman works
                Systemd::enableUserCgroups(linuxConnection, options)

                # Temporary HACK till Podman fixes their stuff...
                # see:
                # * https://github.com/containers/podman/issues/22197
                # * https://github.com/containers/podman/issues/24796
                # Podman ships with broken `podman-user-wait-network-online.service`
                # that runs `systemctl is-active network-online.target`
                # which will never become active unless something wants it
                # so we just make it always wanted
                linuxConnection.createSymlink('/etc/systemd/system/multi-user.target.wants/network-online.target', '/usr/lib/systemd/system/network-online.target', options)
                linuxConnection.restartService('network-online.target', options)
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

            def self.buildGitAnnotations(systemConnection, options)
                annotations = {}
                annotations['org.opencontainers.image.created'] = Time.now.utc.iso8601
                annotations['org.opencontainers.image.source'] = Git::getRemoteUrl(systemConnection, options)
                annotations['org.opencontainers.image.revision'] = Git::getCommit(systemConnection, options)
                annotations['org.opencontainers.image.vendor'] = 'ConfigLMM'
                annotations['org.opencontainers.image.ref.name'] = Git::getRefName(systemConnection, options)
                annotations
            end

            def self.buildImage(containerfile, imageID, args, systemConnection,  options)
                args = args.map(&:shellescape)
                systemConnection.exec("podman build --tag=#{imageID} --file images/custom/Containerfile #{args.join(' ')} .", false, options)
            end

            def self.buildGitImage(containerfile, imageID, args, systemConnection, options)
                args += self.buildGitAnnotations(systemConnection, options).map { |pair| pair.join('=') }.map { |annotation| ['--annotation', annotation] }.flatten
                self.buildImage(containerfile, imageID, args, systemConnection,  options)
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

            def self.loopback?(host, systemConnection, options)
                return true if host.to_s.empty?
                hostname, port = host.to_s.split(':')
                return true if ['localhost', '127.0.0.1', '::1'].include?(hostname)

                return false unless systemConnection
                ip = systemConnection.resolve(hostname, options)
                ['127.0.0.1', '::1'].include?(ip)
            end

            def self.updateHost(host, systemConnection = nil, options = {})
                if self.loopback?(host, systemConnection, options)
                    hostname, port = host.to_s.split(':')
                    return port.nil? ? HOST_LOOPBACK : HOST_LOOPBACK + ':' + port
                end

                return host unless systemConnection

                hostname, port = host.to_s.split(':')
                ip = systemConnection.resolve(hostname, options)
                if systemConnection.gatewayIPs(options).include?(ip)
                    return port.nil? ? HOST_NAME : HOST_NAME + ':' + port
                end
                host
            end

            def self.removeLoopback(containerFile, systemConnection, options)
                systemConnection.fileRemoveLines(containerFile, 'loopback', options)
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
