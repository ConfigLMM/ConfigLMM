
module ConfigLMM
    module LMM
        class Jellyfin < Framework::NginxApp

            def actionJellyfinBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Jellyfin', id, target, state, context, options)
            end

            def actionJellyfinDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionJellyfinDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
