
module ConfigLMM
    module LMM
        class Netdata < Framework::NginxApp

            def actionNetdataBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Netdata', id, target, state, context, options)
            end

            def actionNetdataDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionNetdataDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
