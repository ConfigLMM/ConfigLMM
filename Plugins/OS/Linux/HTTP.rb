
require 'securerandom'

module ConfigLMM
    module LMM
        class HttpConnection
            attr_reader :connection

            def initialize(connection, options)
                @connection = connection
                @options = options
                @cookieFile = '/tmp/cookies_' + SecureRandom.urlsafe_base64(20) + '.txt'
            end

            def cleanup
               @connection.rm(@cookieFile, @options['dry'])
            end

            def get(url, options, headers = {})
                @connection.http(url, options, headers, 'GET', nil, @cookieFile)
            end

            def post(url, data, options, headers = {})
                @connection.http(url, options, headers, 'POST', data, @cookieFile)
            end

            def cookie(name, options)
                @connection.exec("cat #{@cookieFile} | grep #{name} | cut -f 7", false, options)
            end
        end
    end
end
