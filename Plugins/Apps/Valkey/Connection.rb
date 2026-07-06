
module ConfigLMM
    module LMM
        class ValkeyConnection
            Error = Class.new(Framework::PluginProcessError)

            attr_reader :connection

            def initialize(connection, settings)
                @connection = connection
                @settings = settings.dup
                @password = settings['Password']
                @settings.delete('Password')
                @url = Valkey.connectionURL(@settings)
            end

            def exec(commands, options = {})
                commands = [commands] unless commands.is_a?(Array)

                @cli ||= @connection.hasBinaries?('valkey-cli', options) ? 'valkey-cli' : 'redis-cli'
                cmdBase = @cli + ' -u ' + @url.shellescape + ' ' + commands.map(&:to_s).map(&:shellescape).join(' ')

                cmd = cmdBase
                options = options.dup
                if @password
                    options[:hide] = true
                    cmd = 'REDISCLI_AUTH=' + @password.shellescape + ' ' + cmd
                end

                result = @connection.exec(cmd, false, options)
                raise Error.new("Failed '#{cmdBase}'\n" + result) if result.include?(' failed: ')
                result
            end

            def get(name, options = {})
                self.exec([:GET, name], options)
            end

            def delete(name, options = {})
                self.exec([:DEL, name], options)
            end

            def save(options = {})
                self.exec(:SAVE, options)
            end

        end
    end
end
