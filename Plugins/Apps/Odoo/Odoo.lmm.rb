
module ConfigLMM
    module LMM
        class Odoo < Framework::NginxApp

            def actionOdooBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'Odoo', id, target, state, context, options)
            end

            def actionOdooDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionOdooDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
