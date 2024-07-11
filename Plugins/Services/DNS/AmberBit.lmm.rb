
module ConfigLMM
    module LMM
        class AmberBit < Framework::DNS

            def actionAmberBitDNSDeploy(id, target, activeState, context, options)
                showManualDNSSteps(target, "Click on Technical information and add these records:") do |domain|
                    prompt.say("Open https://my.amberbit.eu/domain/list/ and under #{domain}", :color => :magenta)
                end
            end

        end
    end
end
