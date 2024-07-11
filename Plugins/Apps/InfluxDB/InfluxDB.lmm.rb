
module ConfigLMM
    module LMM
        class InfluxDB < Framework::NginxApp

            def actionInfluxDBBuild(id, target, state, context, options)
                writeNginxConfig(__dir__, 'InfluxDB', id, target, state, context, options)
            end

            def actionInfluxDBDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
