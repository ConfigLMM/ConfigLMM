
module ConfigLMM
    module LMM
        class Dovecot < Framework::Plugin

            def actionDovecotDeploy(id, target, activeState, context, options)
                plugins[:Linux].ensurePackage('Dovecot', target['Location'])
                plugins[:Linux].ensureServiceAutoStart('dovecot', target['Location'])
            end

        end

    end
end
