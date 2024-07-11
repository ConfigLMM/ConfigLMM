
module ConfigLMM
    module LMM
        class ArubaItDNS < Framework::DNS

            def actionArubaItDNSDeploy(id, target, activeState, context, options)
                showManualDNSSteps(target, "then click on 'DNS and Name Server Management' and add these records:") do |domain|
                    prompt.say("Open https://admin.aruba.it/PannelloAdmin/LoginDomain.aspx and select #{domain}", :color => :magenta)
                end
            end

        end
    end
end
