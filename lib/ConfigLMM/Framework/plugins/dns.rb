
# frozen_string_literal: true
require_relative 'plugin'

module ConfigLMM
    module Framework

        class DNS < Framework::Plugin
            DEFAULT_TTL = 600

            def processDNS(domain, items)
                records = {}

                if items.is_a?(Hash)
                    # More complicated structure with Hash
                    # TODO Implement TTL
                    raise 'Hash object not implemented!'
                end

                if items.is_a?(String)
                    items = items.split(';')
                end

                items.each do |item|
                    type, content = item.strip.split('=')
                    content = domain if content == '@'
                    content = self.class.externalIp if content == '@me'
                    records[type] ||= []
                    records[type] << { type: type, content: content, ttl: DEFAULT_TTL }
                end

                records
            end

            def showManualDNSSteps(target, message)
                if !target['DNS'].to_h.empty?
                    target['DNS'].each do |domain, data|
                        yield(domain)
                        prompt.say(message, :color => :magenta) if message
                        data.each do |name, data|
                            self.processDNS(domain, data).each do |type, records|
                                records.each do |record|
                                    prompt.say("  * Type: #{record[:type]}\n    Name: #{name}\n    Content: #{record[:content]}", :color => :bold)
                                end
                            end
                        end
                    end
                end
            end

            def self.externalIp
                return @ExternalIp if @ExternalIp
                @ExternalIp = HTTP.get('https://api.ipify.org').body.to_s
            end

            def self.externalIp=(ip)
                @ExternalIp = ip
            end

        end
    end
end
