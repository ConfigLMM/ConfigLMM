
# frozen_string_literal: true

require_relative 'errors'
require 'net/ssh'

module ConfigLMM
    module Framework

        class SSH < Framework::Plugin

            def parseLocation(location)
                  user, hostname = location.split('@')
                  if hostname.nil?
                      hostname = user
                      user = nil
                  end
                  hostname, port = hostname.split(':')
                  port = 22 unless port
                  {
                      hostname: hostname,
                      user: user,
                      port: port
                  }
            end

            def checkSSHAuth!(location, password)
                creds = parseLocation(location)
                Net::SSH.start(creds[:hostname], creds[:user], password: password, port: creds[:port]) do |ssh|
                    # All good if we got here
                end
            end

        end
    end
end
