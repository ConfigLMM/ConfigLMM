
require 'fileutils'

module ConfigLMM
    module LMM
        class Sunshine < Framework::NginxApp

            def actionSunshineBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Sunshine', id, target, state, context, options)
            end

            def actionSunshineDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
