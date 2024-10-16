
module ConfigLMM
    module LMM
        class PodmanConnection

            attr_reader :connection

            def initialize(connection, container)
                @connection = connection
                @container = container
            end

            def exec(command, allowFailure = false, options = {})
                cmd = "podman exec #{@container['Id']} sh -c '#{LinuxShell.escapeSingleQuotes(command)}'"
                @connection.exec(cmd, allowFailure, options)
            end

        end
    end
end
