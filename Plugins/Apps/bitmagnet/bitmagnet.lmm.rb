
module ConfigLMM
    module LMM
        class Bitmagnet < Framework::NginxApp

            def actionBitmagnetBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'bitmagnet', id, target, state, context, options)
            end

            def actionBitmagnetDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
