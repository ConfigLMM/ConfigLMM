
# frozen_string_literal: true

require_relative 'errors'
require_relative 'store'
require 'addressable/idna'
require 'http'
require 'fileutils'

module ConfigLMM
    module Framework

        class NginxApp < Framework::Plugin

            def writeNginxConfig(dir, name, id, target, activeState, context, options)
                outputFolder = options['output']

                updateTargetConfig(target)

                template = ERB.new(File.read(dir + '/' + name + '.conf.erb'))
                renderTemplate(template, target, outputFolder + '/nginx/servers-lmm/' + name + '.conf', options)
                plugins[:Nginx].actionNginxBuild(id, target, activeState, context, options)
            end

            def deployNginxConfig(id, target, activeState, context, options)
                outputFolder = options['output']

                if !target['Location'] || target['Location'] == '@me'
                    copy(outputFolder + '/nginx/servers-lmm', '/etc/nginx/', options['dry'])
                end

                plugins[:Nginx].actionNginxDeploy(id, target, activeState, context, options)
            end

            def cleanupNginxConfig(name, id, state, context, options)
                rm('/etc/nginx/servers-lmm/' + name + '.conf', options['dry'])
            end

            private

            def updateTargetConfig(target)
                target['TLS'] = true if target['TLS'].nil?

                if !target['Port']
                    target['Port'] = target['TLS'] ? 443 : 80
                end
                if target['Domain']
                    target['Domain'] = Addressable::IDNA.to_ascii(target['Domain'])
                end
            end

        end
    end
end
