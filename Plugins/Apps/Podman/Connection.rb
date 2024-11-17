
module ConfigLMM
    module LMM
        class PodmanConnection

            attr_reader :connection

            def initialize(connection, container)
                @connection = connection
                @container = container
            end

            def exec(command, allowFailure = false, options = {})
                workdir = ''
                if options[:workdir]
                    workdir = "--workdir #{options[:workdir].shellescape}"
                end
                cmd = "podman exec #{workdir} #{@container['Id'].shellescape} sh -c '#{LinuxShell.escapeSingleQuotes(command)}'"
                @connection.exec(cmd, allowFailure, options)
            end

        end
    end
end
