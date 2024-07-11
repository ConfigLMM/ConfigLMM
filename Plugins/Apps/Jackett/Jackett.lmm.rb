
module ConfigLMM
    module LMM
        class Jackett < Framework::NginxApp

            def actionJackettBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Jackett', id, target, state, context, options)
            end

            def actionJackettDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
