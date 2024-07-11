

require 'http'
require 'addressable/idna'

module ConfigLMM
    module LMM
        class NICLV < Framework::DNS

            def actionNICLVDNSDeploy(id, target, activeState, context, options)
                showManualDNSSteps(target, "and add these records:") do |domain|
                    prompt.say("Open https://www.nic.lv/client/topview/edit_domain?dname=#{domain}", :color => :magenta)
                end
            end

        end
    end
end
