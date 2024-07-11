
module ConfigLMM
    module LMM
        class ArchiSteamFarm < Framework::NginxApp

            def actionArchiSteamFarmBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'ArchiSteamFarm', id, target, state, context, options)
            end

            def actionArchiSteamFarmDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
