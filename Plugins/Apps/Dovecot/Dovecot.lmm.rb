
module ConfigLMM
    module LMM
        class Dovecot < Framework::Plugin
            PACKAGE_NAME = 'Dovecot'
            SERVICE_NAME = 'dovecot'

            def actionDovecotDeploy(id, target, activeState, context, options)
                plugins[:Linux].ensurePackage(PACKAGE_NAME, target['Location'])
                plugins[:Linux].ensureServiceAutoStart(SERVICE_NAME, target['Location'])
                plugins[:Linux].startService(SERVICE_NAME, target['Location'])
            end

        end

    end
end
