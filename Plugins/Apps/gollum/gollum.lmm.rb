
module ConfigLMM
    module LMM
        class Gollum < Framework::NginxApp

            NAME = 'gollum'
            GOLLUM_PATH = '/srv/gollum'

            def actionGollumBuild(id, target, activeState, context, options)
                if !target['Root'] && (!target['Location'] || target['Location'] == '@me')
                    target['Root'] = File.dirname(`gem which gollum`.strip) + '/gollum/public'
                end
                writeNginxConfig(__dir__, NAME, id, target, activeState, context, options)
                targetDir = options['output'] + GOLLUM_PATH
                mkdir(targetDir, options['dry'])
                copy(__dir__ + '/config.ru', targetDir, options['dry'])
                `git init #{targetDir}/repo`
            end

            def actionGollumRefresh(id, target, activeState, context, options)
                # Would need to parse deployed config to implement
            end

            def actionGollumDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    targetDir = GOLLUM_PATH
                    mkdir(targetDir, options['dry'])
                    deployNginxConfig(id, target, activeState, context, options)
                    copy(options['output'] + GOLLUM_PATH + '/config.ru', GOLLUM_PATH, options['dry'])
                    copyNotPresent(options['output'] + GOLLUM_PATH + '/repo', GOLLUM_PATH, options['dry'])
                    chown('http', 'http', GOLLUM_PATH, options['dry'])
                    activeState['Location'] = '@me'
                else
                    # TODO
                end
            end

            def cleanup(configs, state, context, options)
                items = state.selectType(:Gollum)
                items.each do |id, item|
                    if !configs.key?(id)
                        if item['Location'] == '@me'
                            cleanupNginxConfig(NAME, id, state, context, options)
                        else
                            # TODO
                        end
                    end
                end
            end
        end
    end
end
