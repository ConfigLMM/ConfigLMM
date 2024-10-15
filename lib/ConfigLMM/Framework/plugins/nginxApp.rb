
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
                name = target['ConfigName'] if target['ConfigName']
                renderTemplate(template, target, outputFolder + '/nginx/servers-lmm/' + name + '.conf', options)
            end

            def deployNginxConfig(id, target, activeState, context, options)
                outputFolder = options['output'] + '/nginx/servers-lmm'

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'
                    self.class.sshStart(uri) do |ssh|
                        self.class.uploadFolder(outputFolder, CONFIG_DIR, ssh)
                        if target['TLS']
                            Framework::LinuxApp.firewallAddServiceOverSSH('https', ssh)
                        else
                            Framework::LinuxApp.firewallAddServiceOverSSH('http', ssh)
                        end
                    end
                else
                    copy(outputFolder, CONFIG_DIR, options['dry'])
                end
            end

            def cleanupNginxConfig(name, id, state, context, options, connection)
                connection.rm('/etc/nginx/servers-lmm/' + name + '.conf', options['dry'])
            end

            def self.prepareNginxConfig(target, connectionOrSSH = nil)
                if connectionOrSSH.is_a?(IO::Connection)
                    target['NginxVersion'] = connectionOrSSH.exec('nginx -v').strip.split('/')[1].to_f
                elsif connectionOrSSH
                    target['NginxVersion'] = self.sshExec!(connectionOrSSH, 'nginx -v').strip.split('/')[1].to_f
                else
                    target['NginxVersion'] = `nginx -v`.strip.split('/')[1].to_f
                end
            end

            def self.reload(connection = nil, dry = false)
                if connection.is_a?(IO::Connection)
                    connection.exec("systemctl reload nginx", false, { 'dry' => dry })
                else
                    self.exec("systemctl reload nginx", connection, false, dry)
                end
            end

            def self.ensurePackage(connection = nil)
                Framework::LinuxApp.ensurePackages([NGINX_PACKAGE], connection)
                Framework::LinuxApp.ensureServiceAutoStartOverSSH(NGINX_PACKAGE, connection)
            end

            def useNginxProxy(dir, configName, id, target, activeState, state, context, options, connectionOrSSH)
                self.class.ensurePackage(connectionOrSSH)
                self.class.prepareNginxConfig(target, connectionOrSSH)
                self.writeNginxConfig(dir, configName, id, target, state, context, options)
                self.deployNginxConfig(id, target, activeState, context, options)
                Framework::LinuxApp.startServiceOverSSH(NGINX_PACKAGE, connectionOrSSH)
                self.class.reload(connectionOrSSH)
            end

            def deployNginxProxyConfig(server, name, id, target, activeState, state, context, options, connectionOrSSH)
                target = target.dup
                target['Proxy'] = server
                target['Name'] = name if name
                target['ConfigName'] = target['Name']
                useNginxProxy(__dir__ + '/../../../../Plugins/Apps/Nginx', 'proxy', id, target, activeState, state, context, options, connectionOrSSH)
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
