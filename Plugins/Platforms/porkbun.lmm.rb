# frozen_string_literal: true

require 'porkbun'

module ConfigLMM
    module LMM
        class Porkbun < Framework::DNS

            def actionPorkbunDNSValidate(id, target, activeState, context, options)
                errors = []
                if target['DNS'].to_h.empty?
                    errors << id + ': DNS entries must be provided!'
                end
                errors
            end

            def actionPorkbunDNSRefresh(id, target, activeState, context, options)
                result = ::Porkbun::Domain.list_all
                if result[:status] == "SUCCESS"
                    domainsInfo = result[:domains].map { |info| [ info[:domain], { :_meta_ => info } ] }.flatten
                    activeState['DNS'] = Hash[*domainsInfo]
                    activeState['DNS'].each do |domain, info|
                        records = ::Porkbun::DNS.retrieve(domain)
                        if records.instance_of?(::Porkbun::Error)
                            if records.message.include?('Domain is not opted in to API access')
                                prompt.warn("#{domain}: Skipping, #{records.message}")
                            else
                              raise Framework::PluginProcessError.new("Got error " + records.message)
                            end
                        else
                            info[:_records_] = records.map { |record| record.to_h }
                        end
                    end
                else
                    raise Framework::PluginProcessError.new("Couldn't refresh " + id + "! Invalid PORKBUN_SECRET_API_KEY ?")
                end
            end

            def actionPorkbunDNSDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionPorkbunDNSDeploy(id, target, activeState, context, options)
                if target['DNS'].to_h.empty?
                    raise Framework::PluginProcessError.new(id + ': DNS entries must be provided!')
                end

                actionPorkbunDNSDiff(id, target, activeState, context, options)

                target['DNS'].each do |domain, info|
                    presentRecords = ::Porkbun::DNS.retrieve(domain)
                    if presentRecords.instance_of?(::Porkbun::Error)
                        raise Framework::PluginProcessError.new("#{id}: #{domain} - #{result.message}")
                    end
                    activeState['DNS'] ||= {}
                    activeState['DNS'][domain] ||= {}
                    activeState['DNS'][domain][:_records_] = presentRecords.map { |record| record.to_h }

                    info.each do |name, data|
                        name = '' if name == '@'

                        self.processDNS(domain, data).each do |type, records|
                            records.each do |record|
                                found = false
                                remove = []
                                presentRecords.each do |dns|
                                    if (dns.name.downcase == ((name.empty? ? '' : name + '.') + domain).downcase)
                                        # * Skip when content matches
                                        # * When setting A/AAAA record we need to delete ALIAS
                                        # * When setting ALIAS we need to delete A/AAAA record
                                        if (dns.type == type && dns.content == record[:content])
                                            found = true
                                        elsif (type[0] == 'A' && dns.type == 'ALIAS') ||
                                              (type == 'ALIAS' && dns.type == 'A') ||
                                              (type == 'ALIAS' && dns.type == 'AAAA')
                                            remove << dns
                                        end
                                    end
                                end

                                remove.each do |dns|
                                    dns.delete
                                    # TODO should also remove from activeState
                                end

                                if !found
                                    prompt.say("Updating " + ((name.empty? || name == '@')? '' : name + '.') + domain)
                                    result = ::Porkbun::DNS.create(domain: domain,
                                                                   name: name,
                                                                   type: record[:type],
                                                                   content: record[:content],
                                                                   ttl: record[:ttl]
                                                                  )
                                    if result.message.to_s.include?('unable')
                                        raise Framework::PluginProcessError.new("#{id}: #{name} #{domain} - #{result.message}")
                                    else
                                      result = result.to_h
                                      name = result[:name]
                                      result[:name] = (result[:name].empty? ? '' : result[:name] + '.') + domain
                                      name = '@' if name.empty?
                                      activeState['DNS'][domain][name] = result
                                    end
                                end
                            end
                        end
                    end
                end
            end

            def cleanup(configs, state, context, options)
                # TODO
            end

            def authenticate(actionMethod, target, activeState, context, options)
                if ENV['PORKBUN_API_KEY'].to_s.empty? || ENV['PORKBUN_SECRET_API_KEY'].to_s.empty?
                    prompt.error('Set your porkbun API key to PORKBUN_API_KEY and PORKBUN_SECRET_API_KEY as Environment Variable')
                    raise Framework::PluginPrerequisite.new('Need PORKBUN_API_KEY and PORKBUN_SECRET_API_KEY')
                else
                    result = ::Porkbun.ping
                    if result[:status] != 'SUCCESS'
                        raise Framework::PluginPrerequisite.new(result[:message])
                    end
                end
                true
            end

        end
    end
end
