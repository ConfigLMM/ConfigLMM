
require 'addressable/idna'
require 'http'
require 'nokogiri'

module ConfigLMM
    module LMM
        class Tonic < Framework::DNS

            EDIT_URL = 'https://www.tonic.to/editdns.htm'
            # UPDATE_URL = 'https://www.tonic.to/upddnssucc.htm'

            def actionTonicDNSValidate(id, target, activeState, context, options)
                errors = []
                if target['Domain'].to_s.empty?
                    errors << id + ': Domain must be provided!'
                end
                if target['Nameservers'].to_h.empty?
                    errors <<  id + ': Nameservers must be provided!'
                end
                errors
            end

            def getPassword(target, context)
                tonicPassword = context.secrets.load(target['SecretId'], 'PASSWORD')
                tonicPassword = context.secrets.load('TONIC', 'PASSWORD') if tonicPassword.nil?
                raise Framework::PluginProcessError.new('Missing Tonic DNS password!') unless tonicPassword
                tonicPassword
            end

            def actionTonicDNSRefresh(id, target, activeState, context, options)
                domain = target['Domain'].split('.').first
                if domain.empty?
                    raise Framework::PluginProcessError.new('Invalid Domain for ' + id)
                end

                tonicPassword = getPassword(target, context)

                response = HTTP.post(EDIT_URL, :form => {
                                            command: 'editdns',
                                            error: 'badpass.htm',
                                            sld: domain,
                                            password: tonicPassword,
                                            'B1.x' => "40",
                                            'B1.y' => "20"
                                    })

                fields = Nokogiri::HTML(response.to_s).xpath('//input[@value]/@value')
                if !fields.empty?
                    if fields.first.value == 'updatedns'
                        values = fields.map { |attrs| attrs.value }
                                       .reject { |v| v.empty? ||
                                                     v == 'updatedns' ||
                                                     v == 'Submit'
                                               }
                        nameservers = Hash[*values].invert
                        activeState['Nameservers'] = nameservers
                    else
                        raise Framework::PluginProcessError.new('Unexpected value in response for  ' + id)
                    end
                else
                    raise Framework::PluginProcessError.new("Couldn't refresh " + id + "! Invalid Tonic password?")
                end
            end

            def actionTonicDNSDiff(id, target, activeState, context, options)
                shouldMatch(id, activeState['Config'], 'Domain', target, 'Domain')
                nameservers = activeState['Nameservers']&.transform_keys { |ns| Addressable::IDNA.to_unicode(ns) }
                if target['Nameservers'] != nameservers
                    @Diff.update({'Nameservers' => [target['Nameservers'], nameservers]})
                end
            end

            def actionTonicDNSDeploy(id, target, activeState, context, options)
                domain = target['Domain'].split('.').first
                if domain.empty?
                    raise Framework::PluginProcessError.new('Invalid Domain for ' + id)
                end

                actionTonicDNSDiff(id, target, activeState, context, options)

                hosts = target['Nameservers'].keys.map { |ns| Addressable::IDNA.to_ascii(ns) }
                addrs = target['Nameservers'].values

                tonicPassword = getPassword(target, context)

                response = HTTP.post(EDIT_URL, :form => {
                                            command: 'editdns',
                                            error: 'badpass.htm',
                                            sld: domain,
                                            password: tonicPassword,
                                            'B1.x' => "40",
                                            'B1.y' => "20"
                                    })

                updateURL = Nokogiri::HTML(response.to_s).at('//form[@action]/@action')
                if updateURL.nil?
                    raise Framework::PluginProcessError.new("Couldn't deploy " + id + "! Invalid TONIC_PASSWORD ?")
                end

                if options['dry']
                    prompt.say("Would HTTP POST #{updateURL.value}")
                else
                    response = HTTP.cookies(response.cookies)
                                   .post(updateURL.value, :form => {
                                           command: 'updatedns',
                                           priadd: addrs[0].to_s,
                                           prihost: hosts[0].to_s,
                                           secadd1: addrs[1].to_s,
                                           sechost1: hosts[1].to_s,
                                           secadd2: addrs[2].to_s,
                                           sechost2: hosts[2].to_s,
                                           secadd3: addrs[3].to_s,
                                           sechost3: hosts[3].to_s,
                                           'B1.x': 45,
                                           'B1.y': 30
                                        })

                    prompt.say(Nokogiri::HTML(response.to_s).at('//title/text()'))
                end
            end

            def authenticate(actionMethod, target, activeState, context, options)
                authSecret = context.secrets.load(target['SecretId'], 'PASSWORD')
                authSecret = context.secrets.load('TONIC', 'PASSWORD') if authSecret.nil?
                if authSecret.to_s.empty?
                    prompt.say("Set your Tonic DNS password in #{target['SecretId']}_PASSWORD")
                    raise Framework::PluginPrerequisite.new('Need Tonic DNS password!')
                end
                true
            end

        end
    end
end
