require 'faye/websocket'
require 'eventmachine'
require 'strings-ansi'
require 'digest'
require 'base64'

module ConfigLMM
    module LMM
        class ProxmoxXTerm

            $WS = nil

            class Tunnel

                attr_reader :prompt
                attr_reader :logger

                def initialize(state, prompt, logger)
                    @State = state
                    @prompt = prompt
                    @logger = logger
                    waitReady()
                end

                def waitReady
                    @State[:mutex].synchronize {
                        @State[:condition].wait(@State[:mutex])
                    }
                end

                def exec(command, allowFailure = false, options = {})
                    if options['dry']
                        message = "Would execute: proxmox+xterm: '#{command}'"
                        prompt.say(message)
                        return ''
                    end
                    if options[:hide]
                        logger.debug("[xterm]# **HIDDEN**")
                    else
                        logger.debug("[xterm]# #{command}")
                    end
                    @State[:mutex].synchronize {
                        @State[:stage] = :command
                        ProxmoxXTerm.sendMessage($WS, command + "\n")
                        @State[:condition].wait(@State[:mutex])
                    }
                    @State[:data]
                end

                def adminExec(command, allowFailure = false, options = {})
                    self.exec(command, allowFailure, options)
                end

                def download(source, target, options = {})
                    if options[:dry]
                        message = "Would download proxmox+xterm:#{source}"
                        prompt.say(message)
                        return
                    end
                    checksum = self.exec("md5sum #{source}").split(' ').first.strip
                    isBinary = self.exec("file --brief --mime-encoding #{source}").include?('binary')
                    encode = ''
                    encode = ' | base64' if isBinary
                    begin
                        @State[:mutex].synchronize {
                            @State[:stage] = :raw
                            ProxmoxXTerm.sendMessage($WS, "stty raw -onlcr -echo -echonl\n")
                            @State[:condition].wait(@State[:mutex])
                        }
                        @State[:mutex].synchronize {
                            @State[:stage] = :raw
                            ProxmoxXTerm.sendMessage($WS, "cat #{source}#{encode}\n")
                            @State[:condition].wait(@State[:mutex])
                        }
                        @State[:data] = Base64.decode64(@State[:data]) if isBinary
                        compare = Digest::MD5.hexdigest(@State[:data])
                        if checksum != compare
                            raise "Failed to download #{source} file"
                        end
                        target += '/' + File.basename(source) if File.directory?(target)
                        File.write(target, @State[:data])
                    ensure
                        self.exec("stty -raw onlcr echo echonl")
                    end
                end

                def downloadStream(command, target, local, options = {})
                    filename = '/tmp/xterm.stream'
                    self.exec("umask 077 && #{command} > #{filename}", false, options)
                    self.download(filename, target, options)
                ensure
                    self.exec("rm -rf #{filename}", false, options)
                end

                def upload(source, target, options = {})
                    if options[:dry]
                        message = "Would upload #{source} to proxmox+xterm:#{target}"
                        prompt.say(message)
                        return
                    end
                    data = File.read(source)
                    checksum = Digest::MD5.hexdigest(data)
                    begin
                        @State[:mutex].synchronize {
                            @State[:stage] = :ignore
                            ProxmoxXTerm.sendMessage($WS, "stty raw isig -onlcr && cat > #{target}\n")
                            @State[:condition].wait(@State[:mutex])
                        }
                        @State[:mutex].synchronize {
                            ProxmoxXTerm.sendMessage($WS, data)
                            @State[:condition].wait(@State[:mutex])
                        }
                        @State[:mutex].synchronize {
                            @State[:stage] = :shell
                            ProxmoxXTerm.sendMessage($WS, "\u0003")
                            @State[:condition].wait(@State[:mutex])
                        }
                        compare = self.exec("md5sum #{target}").split(' ').first.strip
                        if checksum != compare
                            raise "Failed to upload #{source} file"
                        end
                    ensure
                        self.exec("stty -raw onlcr")
                    end
                end

                def updateFile(file, options, atTop = false, comment = '#', &block)
                    localFile = options['output'] + '/' + SecureRandom.alphanumeric(10)
                    File.write(localFile, '')
                    self.exec("touch #{file}", false, options)
                    self.download(file, localFile, options)
                    IO::Local.new(self.prompt, self.logger).updateFile(localFile, options, atTop, comment, &block)
                    self.upload(localFile, file, options)
                end

            end

            def self.tunnel(url, insecure, token, term, username, password, prompt, logger, &block)
                headers = {}
                headers['Cookie'] = 'PVEAuthCookie=' + token
                state = {
                    mutex: Mutex.new,
                    condition: ConditionVariable.new
                }
                $WS = nil
                thread = Thread.new do
                    EM.run do
                        $WS = Faye::WebSocket::Client.new(url, [],
                            :headers => headers,
                            :tls => {
                                :verify_peer => !insecure
                            }
                        )
                        $WS.on :open do |event|
                            $WS.send("#{term['user']}:#{term['ticket']}\n")
                            state[:stage] = :start
                            state[:message] = ''
                            state[:data] = ''
                            state[:invalidLogin] = 0
                            state[:timer] = nil
                            state[:delay] = 0.1
                        end

                        $WS.on :message do |event|
                            self.processMessage($WS, event, state, username, password, url, prompt, logger)
                        end

                        $WS.on(:error) do |event|
                            prompt.say(event.message, color: :red)
                        end

                        $WS.on :close do |event|
                            state[:mutex].synchronize {
                                state[:condition].signal()
                            }
                            EM.stop_event_loop
                        end
                    end
                end
                thread.abort_on_exception = true
                yield(Tunnel.new(state, prompt, logger))
                state[:mutex].synchronize {
                    state[:stage] = :exit
                    self.sendMessage($WS, "exit\n")
                    state[:condition].wait(state[:mutex])
                }
                if $WS.ready_state == Faye::WebSocket::OPEN
                    state[:mutex].synchronize {
                        state[:stage] = :exit
                        self.sendMessage($WS, "exit\n")
                        state[:condition].wait(state[:mutex])
                    }
                end
                $WS.close
                $WS = nil
                thread.join
            end

            def self.processMessage(ws, event, state, username, password, url, prompt, logger)
                state[:message] += event.data.pack('C*')
                if !state[:timer].nil?
                    EM.cancel_timer(state[:timer])
                end
                if state[:stage] == :login && state[:message].include?('unable to find a serial interface')
                    raise 'Console not available!'
                end
                if state[:stage] == :exit && state[:message].strip.end_with?('logout')
                    state[:mutex].synchronize {
                        state[:condition].signal()
                    }
                else
                    state[:timer] = EM.add_timer(state[:delay]) { self.handleData(ws, state, username, password, url, prompt, logger) }
                end
            end

            def self.handleData(ws, state, username, password, url, prompt, logger)
                state[:delay] = 0.1
                if state[:stage] == :raw
                    rawData = data = state[:data] = state[:message]
                else
                    rawData = state[:message]
                    data = state[:data] = self.cleanupMessage(state[:message])
                end
                state[:message] = ''
                case state[:stage]
                when :start
                    state[:stage] = :login
                    self.raiseError('Unexpected response!', data, url, prompt, logger) unless data.start_with?('OK')
                    state[:delay] = 3
                    self.sendMessage(ws, "\n")
                when :login
                    self.doLogin(ws, data, state, username, url, prompt, logger)
                when :password
                    self.doPassword(ws, data, state, password, url, prompt, logger)
                when :checkPassword
                    if data.lines.last.include?('login:') && data.include?('Login incorrect')
                        state[:invalidLogin] += 1
                        state[:stage] = :login
                        self.doLogin(ws, data, state, username, url, prompt, logger)
                        return
                    end
                    self.raiseError('Unexpected Console state!', data, url, prompt, logger) unless data.lines.last.strip.end_with?('#')
                    state[:stage] = :shell
                    state[:delay] = 3
                    # Couldn't get Fish shell to work properly so force using `sh`
                    self.sendMessage(ws, "sh\n")
                when :shell
                    self.raiseError('Unexpected Console state!', data, url, prompt, logger) unless data.lines.last.strip.end_with?('#')
                    state[:mutex].synchronize {
                        state[:condition].signal()
                    }
                when :command
                    lastNewline = state[:data].rindex("\n")
                    if state[:data][lastNewline..-1].strip.end_with?('#')
                        firstNewline = state[:data].index("\n")
                        state[:data] = firstNewline.nil? ? '' : state[:data][(firstNewline + 1)..(lastNewline - 1)]
                        state[:stage] = :shell
                        state[:mutex].synchronize {
                            state[:condition].signal()
                        }
                    else
                        state[:message] = state[:data]
                    end
                when :raw
                    lastNewline = state[:data].rindex("\n")
                    if !lastNewline.nil? && self.cleanupMessage(state[:data][lastNewline..-1]).strip.end_with?('#')
                        state[:data] = state[:data][0..lastNewline]
                                           .gsub("\r\n", "\n")
                                           .gsub("\e[30m\e[m\u000F\e[?2004l", '') # Fish shell...
                                           .gsub(/\e\[2m\^J\e\[m\u000F\s+\r\^J  \r\e\[/, '')
                        state[:stage] = :shell
                        state[:mutex].synchronize {
                            state[:condition].signal()
                        }
                    else
                        state[:message] = state[:data]
                    end
                when :ignore
                    # Ignore
                    state[:mutex].synchronize {
                        state[:condition].signal()
                    }
                when :exit
                    state[:mutex].synchronize {
                        state[:condition].signal()
                    }
                else
                    raise 'Unknown stage!'
                end
            end

            def self.doLogin(ws, data, state, username, url, prompt, logger)
                if data.strip.end_with?('#')
                    state[:stage] = :shell
                    state[:delay] = 3
                    # Couldn't get Fish shell to work properly so force using `sh`
                    self.sendMessage(ws, "sh\n")
                elsif data.include?('Password:')
                    state[:delay] = 3
                    self.sendMessage(ws, "\n")
                elsif data.include?('login:') && !data.downcase.include?('last login')
                    if state[:invalidLogin] >= 2
                        self.raiseError('Too many failed login attempts!', data, url, prompt, logger)
                    end
                    state[:stage] = :password
                    state[:delay] = 3
                    self.sendMessage(ws, "#{username}\n")
                elsif data == "\n"
                    state[:delay] = 10
                    self.sendMessage(ws, "\n")
                else
                    self.raiseError('Unexpected Console state!', data, url, prompt, logger)
                end
            end

            def self.doPassword(ws, data, state, password, url, prompt, logger)
                if data.include?('Password:')
                    state[:stage] = :checkPassword
                    self.raiseError('Missing ROOT_PASSWORD!', nil, url, prompt, logger) unless password
                    state[:delay] = 5
                    self.sendMessage(ws, password + "\n")
                else
                    self.raiseError('Unexpected Console state!', data, url, prompt, logger)
                end
            end

            def self.cleanupMessage(message)
                Strings::ANSI.sanitize(message)
                    .gsub("\r\r\n", "\n")
                    .gsub("\u000F", '')
                    .gsub("\e(B", '') # should be removed by sanitize but looks like bug there https://github.com/piotrmurach/strings-ansi/issues/4
            end

            def self.sendMessage(ws, message)
                return unless ws
                length = message.bytesize
                data = '0:' + length.to_s + ':' + message
                ws.send(data)
            end

            def self.raiseError(message, data, url, prompt, logger)
                url, query = url.split('?')
                logger.error("Error for #{url}")
                logger.warn(data.inspect) if data
                raise message.to_s
            end

        end
    end
end
