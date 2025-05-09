
module ConfigLMM
    module IO
        def self.error?(error)
            [Errno::EHOSTUNREACH, Errno::ECONNREFUSED, Net::SSH::ConnectionTimeout, Excon::Error::Socket, IO::ConnectError].each do |type|
                return true if error.is_a?(type)
            end
            false
        end
    end
end

require_relative 'io/configList'
require_relative 'io/connection'
require_relative 'io/pxe'
