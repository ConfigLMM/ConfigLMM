
module ConfigLMM
    module LMM
        class IPFS < Framework::NginxApp

            def actionIPFSBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'IPFS', id, target, state, context, options)
            end

            def actionIPFSDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionIPFSDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
