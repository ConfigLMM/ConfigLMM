
module ConfigLMM
    module LMM
        class Mastodon < Framework::NginxApp

            def actionMastodonBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Mastodon', id, target, state, context, options)
            end

            def actionMastodonDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionMastodonDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
