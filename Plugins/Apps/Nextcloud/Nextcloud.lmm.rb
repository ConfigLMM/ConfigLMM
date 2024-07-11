
module ConfigLMM
    module LMM
        class Nextcloud < Framework::NginxApp

            def actionNextcloudBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Nextcloud', id, target, state, context, options)
            end

            def actionNextcloudDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionNextcloudDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
