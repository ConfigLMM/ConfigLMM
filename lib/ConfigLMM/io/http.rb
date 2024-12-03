
require 'forwardable'
require 'webrick'

module ConfigLMM
    module IO

        class HTTPLogger
            extend Forwardable

            def_delegators :@Logger, :debug, :info, :warn, :error, :fatal

            def initialize(logger, level)
                @Logger = logger
                @Level = level
            end

            def debug?
                @Level == 'debug'
            end

            def <<(message)
                @Logger.info(message)
            end
        end

        class HTTP
            PORT = 6582

            def initialize(dir, ip, options, logger)
                @IP = ip
                @Logger = HTTPLogger.new(logger, options[:level])
                @LastReadTime = nil
                requestCallback = Proc.new do |request, response|
                    @LastReadTime = Time.now
                    response
                end
                @Server = WEBrick::HTTPServer.new(BindAddress: @IP,
                                                  Port: PORT,
                                                  DocumentRoot: dir,
                                                  RequestCallback: requestCallback,
                                                  Logger: @Logger,
                                                  AccessLog: { @Logger => WEBrick::AccessLog::COMMON_LOG_FORMAT })
            end

            def url(path)
                "http://#{@IP}:#{PORT}/#{path}"
            end

            def start()
                Thread.new do
                    @Server.start
                end
            end

            def stop()
                @Server.stop
            end

            def wait(timeout)
                timeoutTime = Time.now + timeout
                previousReadTime = @LastReadTime
                loop do
                    if previousReadTime != @LastReadTime
                        previousReadTime = @LastReadTime
                        timeoutTime = Time.now + timeout
                    end
                    return if Time.now >= timeoutTime
                    sleep(0.1)
                end
            end

            def hadRead?
                !@LastReadTime.nil?
            end
        end
    end
end
