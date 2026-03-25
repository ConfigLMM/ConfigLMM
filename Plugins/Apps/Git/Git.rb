
module ConfigLMM
    module LMM
        class Git

            def self.getBranch(systemConnection, options)
                systemConnection.exec('git branch --show-current', false, options).to_s.strip
            end

            def self.getCommit(systemConnection, options)
                systemConnection.exec('git rev-parse HEAD', false, options).to_s.strip
            end

            def self.getRefName(systemConnection, options)
                systemConnection.exec('git describe --tags', false, options).to_s.strip
            end

            def self.getRemoteUrl(systemConnection, options)
                systemConnection.exec('git remote get-url origin', false, options).to_s.strip
            end

        end
    end
end
