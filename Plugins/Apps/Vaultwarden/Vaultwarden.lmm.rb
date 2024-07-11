
require 'fileutils'

module ConfigLMM
    module LMM
        class Vaultwarden < Framework::NginxApp

            def actionVaultwardenBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Vaultwarden', id, target, state, context, options)
            end

            def actionVaultwardenDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionVaultwardenDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
