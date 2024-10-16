
require_relative 'Connection'

module ConfigLMM
    module LMM
        class Podman < Framework::Plugin

            SYSTEM_CONTAINERS_PATH = '/etc/containers/systemd'
            USER_CONTAINERS_PATH = '~/.config/containers/systemd'
            HOST_IP = '10.0.2.2'

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

            def self.containersPath(homeDir = nil)
                if homeDir.nil?
                    SYSTEM_CONTAINERS_PATH
                else
                    USER_CONTAINERS_PATH.gsub('~', homeDir)
                end
            end

        end
    end
end
