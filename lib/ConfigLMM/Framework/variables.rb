# frozen_string_literal: true

module ConfigLMM
    module Framework
        class Variable

            attr_reader :name

            def initialize(name, args, context)
                @name = name
                @args = args
                @context = context
            end

            def eval()
                if name == 'ENV'
                    value = ENV[@args.first]
                    raise "Environment variable #{@args.first} not found!" if value.nil?
                    value
                elsif name == 'SECRET'
                    value = @context.secrets.load(*@args)
                    raise "Secret #{@args.join(':')} not found!" if value.nil?
                    value
                elsif name == 'GENERATE'
                    secretId, secretName, length = @args
                    raise 'Not enough arguments for GENERATE!' if secretId.to_s.empty? || secretName.to_s.empty?
                    value = @context.secrets.load(secretId, secretName)
                    if value.nil?
                        length = 30 unless length
                        value = SecureRandom.alphanumeric(length)
                        @context.secrets.store(secretId, secretName, value)
                    end
                    value
                else
                    raise "Unsupported function #{name}!"
                end
            end

            def to_s()
                eval()
            end
        end

        def Value
            def initialize(value)
                @value = value
            end

            def to_s()
                @value.to_s
            end
        end

        class Variables
            def self.parse(value, context)
                if value.to_s[0, 2] == '${'
                    raise "Unterminated variable: #{value}" if value[-1] != '}'
                    parts = value[2...-1].split(':')
                    Variable.new(parts.shift, parts, context)
                else
                    Value.new(value)
                end
            end

            def self.stringEval(data, context)
                variableStart = data.index('${')
                return data unless variableStart
                variableEnd = data.index('}', variableStart + 2)
                raise "Unterminated variable: #{data}" if variableEnd.nil?
                parts = data[variableStart + 2...variableEnd].split(':')
                data[0...variableStart].to_s + Variable.new(parts.shift, parts, context).to_s + data[(variableEnd + 1)..-1].to_s
            end
        end
    end
end
