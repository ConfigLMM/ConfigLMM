# frozen_string_literal: true

module ConfigLMM
    module Secrets
        class FileStore < EnvStore

            def initialize(logger, prompt, secretsFile)
              super(logger, prompt)
              @File = secretsFile
              loadSecrets
            end

            def store(id, name, value)
                super
                save
            end

            def print(message, value)
                # Don't print
            end

            private

            def loadSecrets()
                save unless File.exist?(@File)
                @Secrets = Hash[(File.read(@File).lines.select { |line| !line.strip.empty? }.map { |line| keyValue(line.strip) })]
                @Secrets.transform_keys!(&:upcase)
            end

            def save()
                secrets = @Secrets.map { |name, value| "#{name}=#{value}" }.join("\n") + "\n"
                File.write(@File, secrets)
            end

            private

            def keyValue(line)
                pos = line.index('=')
                [line[0..(pos - 1)], line[(pos + 1)..-1]]
            end
        end
    end
end
