
module ConfigLMM
    module LMM
        class Nginx < Framework::NginxApp

            CONFIG_DIR = '/etc/nginx/'
            HTTP_DIR = '/srv/http/'

            def actionNginxBuild(id, target, activeState, context, options)
                dir = options['output'] + '/nginx/'
                mkdir(dir, options[:dry])
                copy(__dir__ + '/config-lmm', dir, options[:dry])
                # TODO, maybe evaluate them as template?
                copy(__dir__ + '/nginx.conf', dir, options[:dry])
                copy(__dir__ + '/main.conf', dir, options[:dry])
                mkdir(options['output'] + HTTP_DIR + 'root', options[:dry])
                mkdir(options['output'] + HTTP_DIR + 'errors', options[:dry])
            end

            # TODO
            # def actionNginxDiff(id, target, activeState, context, options)
            #     I think we need nginx config parser to implement this
            # end

            def actionNginxDeploy(id, target, activeState, context, options)
                dir = options['output'] + '/nginx/'

                if !target['Location'] || target['Location'] == '@me'
                    copy(dir + '/config-lmm', CONFIG_DIR, options[:dry])
                    copyNotPresent(dir + '/nginx.conf', CONFIG_DIR, options[:dry])
                    copyNotPresent(dir + '/main.conf', CONFIG_DIR, options[:dry])
                    copyNotPresent(dir + '/servers-lmm', CONFIG_DIR, options['dry'])
                    mkdir(HTTP_DIR + 'root', options[:dry])
                    mkdir(HTTP_DIR + 'errors', options[:dry])
                end
                # Consider:
                # * Deploy on current host
                # * Deploy on remote host thru SSH (eg. VPS)
                # * Using already existing solution like Chef/Puppet/Ansible/etc
                # * Provision from some Cloud provider
                # We implement this as we go - what people actually use
            end

            def actionNginxProxyBuild(id, target, activeState, context, options)
                updateTargetConfig(target)

                template = ERB.new(File.read(__dir__ + '/proxy.conf.erb'))
                renderTemplate(template, target, options['output'] + '/nginx/servers-lmm/' + target['Name'] + '.conf', options)

                actionNginxBuild(id, target, activeState, context, options)
            end

            def actionNginxProxyDeploy(id, target, activeState, context, options)
                if !target['Location'] || target['Location'] == '@me'
                    deployNginxConfig(id, target, activeState, context, options)
                    activeState['Location'] = '@me'
                end
            end

        end
    end
end
