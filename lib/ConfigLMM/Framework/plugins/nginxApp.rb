
# frozen_string_literal: true

require_relative 'plugin'
require_relative 'errors'
require_relative 'store'
require 'addressable/idna'
require 'http'
require 'fileutils'

module ConfigLMM
    module Framework

        class NginxApp < Framework::Plugin

            NGINX_PACKAGE = 'nginx'
            CONFIG_DIR = '/etc/nginx/'
            WWW_DIR = '/srv/www/'

            def writeNginxConfig(dir, name, id, target, activeState, context, options)
                outputFolder = options['output']

                updateTargetConfig(target)

                target = target.dup
                target['NginxVersion'] = 0 unless target['NginxVersion']
                template = ERB.new(File.read(dir + '/' + name + '.conf.erb'))
                renderTemplate(template, target, outputFolder + '/nginx/servers-lmm/' + name + '.conf', options)
            end

            def deployNginxConfig(id, target, activeState, context, options)
                outputFolder = options['output'] + '/nginx/servers-lmm'

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.class.sshStart(uri) do |ssh|
                        self.class.uploadFolder(outputFolder, CONFIG_DIR, ssh)
                        Framework::LinuxApp.firewallAddServiceOverSSH('https', ssh)
                    end
                else
                    copy(outputFolder, CONFIG_DIR, options['dry'])
                end
            end

            def cleanupNginxConfig(name, id, state, context, options)
                rm('/etc/nginx/servers-lmm/' + name + '.conf', options['dry'])
            end

            def self.prepareNginxConfig(target, ssh)
                if ssh
                    target['NginxVersion'] = self.sshExec!(ssh, 'nginx -v').strip.split('/')[1].to_f
                else
                    target['NginxVersion'] = `nginx -v`.strip.split('/')[1].to_f
                end
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
