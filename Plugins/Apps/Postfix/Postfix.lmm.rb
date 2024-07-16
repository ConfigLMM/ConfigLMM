
module ConfigLMM
    module LMM
        class Postfix < Framework::Plugin

            def actionPostfixDeploy(id, target, activeState, context, options)
                plugins[:Linux].ensurePackage('Postfix', target['Location'])
                plugins[:Linux].ensureServiceAutoStart('postfix', target['Location'])
            end

        end

    end
end
