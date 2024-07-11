
module ConfigLMM
    module LMM
        class Pterodactyl < Framework::NginxApp

            def actionPterodactylBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Pterodactyl', id, target, state, context, options)
            end

            def actionPterodactylDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

            def actionWingsBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Wings', id, target, state, context, options)
            end

            def actionWingsDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end
        end

    end
end
