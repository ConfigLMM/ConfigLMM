require 'faye/websocket'
require 'eventmachine'
require 'strings-ansi'
require 'digest'

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

                def adminExec(command, allowFailure = false, dry = false)
                    self.exec(command, allowFailure, dry)
                end

                def download(source, target, dry = false)
                    if dry
                        message = "Would download proxmox+xterm:#{source}"
                        prompt.say(message)
                        return
                    end
                    checksum = self.exec("md5sum #{source}").split(' ').first.strip
                    begin
                        @State[:mutex].synchronize {
                            @State[:stage] = :raw
                            ProxmoxXTerm.sendMessage($WS, "stty raw -onlcr -echo -echonl\n")
                            @State[:condition].wait(@State[:mutex])
                        }
                        @State[:mutex].synchronize {
                            @State[:stage] = :raw
                            ProxmoxXTerm.sendMessage($WS, "cat #{source}\n")
                            @State[:condition].wait(@State[:mutex])
                        }
                        compare = Digest::MD5.hexdigest(@State[:data])
                        if checksum != compare
                            raise "Failed to download #{source} file"
                        end
                        File.write(target, @State[:data])
                    ensure
                        self.exec("stty -raw onlcr echo echonl")
                    end
                end

                def upload(source, target, dry = false)
                    if dry
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
                    self.download(file, localFile, options['dry'])
                    IO::Local.new(self.prompt, self.logger).updateFile(localFile, options, atTop, comment, &block)
                    self.upload(localFile, file, options['dry'])
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
                            self.processMessage($WS, event, state, username, password)
                        end

                        $WS.on(:error) do |event|
                            prompt.say(event.message, color: :red)
                        end

                        $WS.on :close do |event|
                            $WS = nil
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
                state[:mutex].synchronize {
                    state[:stage] = :exit
                    self.sendMessage($WS, "exit\n")
                    state[:condition].wait(state[:mutex])
                }
                EM.stop_event_loop
                thread.join
            end

            def self.processMessage(ws, event, state, username, password)
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
                    state[:timer] = EM.add_timer(state[:delay]) { self.handleData(ws, state, username, password) }
                end
            end

            def self.handleData(ws, state, username, password)
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
                    raise 'Unexpected response!' unless data.start_with?('OK')
                    state[:delay] = 3
                    self.sendMessage(ws, "\n")
                when :login
                    self.doLogin(ws, data, state, username)
                when :password
                    self.doPassword(ws, data, state, password)
                when :checkPassword
                    if data.lines.last.include?('login:') && data.include?('Login incorrect')
                        state[:invalidLogin] += 1
                        state[:stage] = :login
                        self.doLogin(ws, data, state, username)
                        return
                    end
                    raise 'Unexpected Console state!' unless data.lines.last.strip.end_with?('#')
                    state[:stage] = :shell
                    # Couldn't get Fish shell to work properly so force using `sh`
                    self.sendMessage(ws, "sh\n")
                when :shell
                    raise 'Unexpected Console state!' unless data.lines.last.strip.end_with?('#')
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

            def self.doLogin(ws, data, state, username)
                if data.include?('login:')
                    if state[:invalidLogin] >= 2
                        raise 'Too many failed login attempts!'
                    end
                    state[:stage] = :password
                    self.sendMessage(ws, "#{username}\n")
                elsif data.strip.end_with?('#')
                    state[:stage] = :shell
                    state[:mutex].synchronize {
                        state[:condition].signal()
                    }
                elsif data.include?('Password:')
                    state[:delay] = 3
                    self.sendMessage(ws, "\n")
                elsif data == "\n"
                    state[:delay] = 10
                    self.sendMessage(ws, "\n")
                else
                    raise 'Unexpected Console state!'
                end
            end

            def self.doPassword(ws, data, state, password)
                if data.include?('Password:')
                    state[:stage] = :checkPassword
                    raise 'Missing ROOT_PASSWORD!' unless password
                    state[:delay] = 3
                    self.sendMessage(ws, password + "\n")
                else
                    raise 'Unexpected Console state!'
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
        end
    end
end
