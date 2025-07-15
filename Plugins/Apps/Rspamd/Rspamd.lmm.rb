
module ConfigLMM
    module LMM
        class Rspamd < Framework::Plugin
            PACKAGE_NAME = 'Rspamd'
            SERVICE_NAME = 'rspamd'

            def actionRspamdDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.ensurePackage(PACKAGE_NAME, options)
                        linuxConnection.ensureServiceAutoStart(SERVICE_NAME, options)

                        linuxConnection.restartService(SERVICE_NAME, options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Rspamd, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.disableService(SERVICE_NAME, options)
                        linuxConnection.stopService(SERVICE_NAME, options)
                        linuxConnection.removePackage(PACKAGE_NAME, options)

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            linuxConnection.rm('/etc/rspamd', options[:dry])

                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end

        end

    end
end
