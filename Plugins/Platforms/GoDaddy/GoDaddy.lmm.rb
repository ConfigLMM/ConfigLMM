
require 'http'
require 'addressable/idna'

module ConfigLMM
    module LMM
        class GoDaddy < Framework::DNS

            API_DOMAIN = 'https://api.godaddy.com'
            TEST_API_DOMAIN = 'https://api.ote-godaddy.com'
            # Looks like GoDaddy is garbage and doesn't let people with few domains to use their API
            USE_API = false

            # TODO
            # def actionGoDaddyDNSValidate(id, target, activeState, context, options)
            #    We should check that target['DNS'] looks like valid config
            # end

            def actionGoDaddyDNSBuild(id, target, activeState, context, options)
                outputFolder = options['output'] + '/' + id + '/'

                template = ERB.new(File.read(__dir__ + '/zone.txt.erb'))

                target['DNS'].each do |domain, data|
                    config = { 'Domain' => domain, 'Records' => '' }
                    data.each do |name, data|
                        self.processDNS(domain, data).each do |type, records|
                            records.each do |record|
                                shortName = Addressable::IDNA.to_ascii(name) + '.' if type == 'CNAME' || type == 'ALIAS'
                                if record[:type] == 'MX'
                                    priority, name = record[:content].split(' ')
                                    name = Addressable::IDNA.to_ascii(name) + '.'
                                    record[:content] = [priority, name].join(' ')
                                end
                                config['Records'] += [shortName, record[:ttl], ' IN ', record[:type], record[:content]].join("\t") + "\n"
                            end
                        end
                    end
                    renderTemplate(template, config, outputFolder + domain + '.txt', options)
                end
            end

            def actionGoDaddyDNSRefresh(id, target, activeState, context, options)
                if USE_API
                    http = HTTP.auth("sso-key #{ENV['GODADDY_SECRET']}")
                    apiDomain = (options['dry'] || target['Test']) ? TEST_API_DOMAIN : API_DOMAIN

                    target['DNS'].each do |domain, records|
                        response = http.get("#{apiDomain}/v1/domains/#{Addressable::IDNA.to_ascii(domain)}/records")
                        # TODO
                    end

                    # TODO
                end
            end

            # TODO
            # def actionGoDaddyDNSDiff(id, target, activeState, context, options)
            # end

            persistBuildDir

            def actionGoDaddyDNSDeploy(id, target, activeState, context, options)
                #actionGoDaddyDNSDiff(id, target, activeState, context, options)
                if USE_API
                    # TODO
                else
                    showManualDNSSteps(target, "Click on DNS tab and either import generated Zone file or add these records:") do |domain|
                        prompt.say("Open https://dcc.godaddy.com/control/portfolio/#{domain}/settings", :color => :magenta)
                    end
                end
            end

            def authenticate(actionMethod, target, activeState, context, options)
                if USE_API
                    authSecret = ENV['GODADDY_SECRET']
                    if authSecret.to_s.empty?
                        prompt.say('Open https://developer.godaddy.com/keys and create API Key!')
                        prompt.say('Then set "KEY:SECRET" to GODADDY_SECRET as Environment Variable')
                        raise Framework::PluginPrerequisite.new('Need GODADDY_SECRET')
                    end
                end
                true
            end

        end
    end
end
