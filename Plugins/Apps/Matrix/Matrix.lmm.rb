
module ConfigLMM
    module LMM
        class Matrix < Framework::NginxApp

            def actionMatrixBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Matrix', id, target, state, context, options)
            end

            def actionMatrixDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionMatrixDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
