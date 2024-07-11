
require 'expect'
require 'securerandom'
require 'socket'
require 'pty'
require 'tty-which'
require 'webrick'

module ConfigLMM
    module LMM
        class ArubaInstant < Framework::SSH

            CERT_BASE = '/etc/letsencrypt/live/'
            HTTP_PORT = 6582

            def actionArubaInstantDeploy(id, target, activeState, context, options)
                if !target['Location']
                    raise Framework::PluginProcessError.new(id + ': Location must be provided!')
                end
                if target['CertificateName']
                    fullchain = CERT_BASE + target['CertificateName'] + '/fullchain.pem'
                    privkey = CERT_BASE + target['CertificateName'] + '/privkey.pem'
                    if !File.exist?(fullchain) || !File.exist?(privkey)
                        prompt.error('Couldn\'t find certificate!')
                        prompt.error("Looked at #{fullchain} and #{privkey}")
                        raise Framework::PluginProcessError.new(id + ': Certificate not found!')
                    end
                    certData = File.read(fullchain)
                    certData += File.read(privkey)
                    certFileName = SecureRandom.hex(10)
                    File.write(options['output'] + '/' + certFileName, certData)

                    httpThread = Thread.new do
                        server = WEBrick::HTTPServer.new(Port: HTTP_PORT,
                                                         DocumentRoot: options['output'],
                                                         Logger: WEBrick::Log.new("/dev/null"),
                                                         AccessLog: [])
                        server.start
                    end

                    ourIP = Socket.ip_address_list.select { |addr| addr.ipv4_private? }.first.ip_address

                    firewallcmd = TTY::Which.which("firewall-cmd")
                    if firewallcmd
                        `#{firewallcmd} --add-port #{HTTP_PORT}/tcp >/dev/null 2>&1`
                    end

                    creds = parseLocation(target['Location'])
                    password = ENV['ARUBA_INSTANT_PASSWORD']

                    # Couldn't get it working with net-ssh gem so using `ssh` as workaround
                    # Net::SSH.start(creds[:hostname], creds[:user], password: password, port: creds[:port]) do |ssh|
                    PTY.spawn("ssh -o NumberOfPasswordPrompts=1 -o HostKeyAlgorithms=ssh-rsa #{creds[:user]}@#{creds[:hostname]}") do |reader, writer, pid|
                        reader.expect(/password:/) do |result|
                            writer.puts(password)
                        end

                        output = ''
                        lastWrite = nil
                        error = nil
                        thread = Thread.new do
                            reader.each do |line|
                                output += line
                                lastWrite = Time.now.to_f
                            end
                        rescue SystemCallError => err
                            # Most likely wrong password
                            error = err
                        end
                        while lastWrite.nil? || Time.now.to_f - lastWrite < 5 # It takes while to respond
                            sleep(0.2)
                            if error
                                raise Framework::PluginProcessError.new(id + ': ' + error.message)
                            end
                        end
                        output = ''
                        lastWrite = nil
                        writer.puts('show version')
                        while lastWrite.nil? || Time.now.to_f - lastWrite < 2
                            sleep(0.2)
                        end
                        thread.terminate
                        if output.include?('ArubaOS')
                            result = output.match(/MODEL: (\d+)., Version ([\d\.]+)/)
                            prompt.say("ArubaOS Version: #{result[2]}")
                            prompt.say("MODEL: #{result[1]}")
                            if result[1] == '275'
                                output = ''
                                lastWrite = nil
                                # See Aruba Instant 8.x Command-Line Interface Reference Guide
                                # download-cert ui <url> format pem [psk <psk>]
                                writer.puts("download-cert ui http://#{ourIP}:#{HTTP_PORT}/#{certFileName}")
                                thread = Thread.new do
                                    reader.each do |line|
                                        output += line
                                        lastWrite = Time.now.to_f
                                        prompt.say(line)
                                    end
                                end
                                while lastWrite.nil? || Time.now.to_f - lastWrite < 4
                                    sleep(0.2)
                                end
                                thread.terminate
                                if output.include?('error')
                                    message = 'Something went wrong! :('
                                    prompt.error(message)
                                    raise Framework::PluginProcessError.new(id + ': ' + message)
                                end
                            else
                                message = 'Not risking with untested device! Please test and submit PR! :)'
                                prompt.error(message)
                                raise Framework::PluginProcessError.new(id + ': ' + message)
                            end
                        else
                            message = 'This is not Aruba device!'
                            prompt.error(message)
                            raise Framework::PluginProcessError.new(id + ': ' + message)
                        end
                        reader.close
                        writer.close
                    rescue Framework::PluginProcessError => error
                        `#{firewallcmd} --remove-port #{HTTP_PORT}/tcp` if firewallcmd
                        raise error
                    end
                    httpThread.terminate
                    `#{firewallcmd} --remove-port #{HTTP_PORT}/tcp` if firewallcmd
                end
            end

            def authenticate(actionMethod, target, activeState, context, options)
                if ENV['ARUBA_INSTANT_PASSWORD'].to_s.empty? || ENV['ARUBA_INSTANT_PASSWORD'].to_s.empty?
                    prompt.error('Set your Aruba Instant SSH password to ARUBA_INSTANT_PASSWORD as Environment Variable')
                    raise Framework::PluginPrerequisite.new('Need ARUBA_INSTANT_PASSWORD')
                else
                    if !target['Location']
                        raise Framework::PluginProcessError.new('Location must be provided!')
                    end
                    checkSSHAuth!(target['Location'], ENV['ARUBA_INSTANT_PASSWORD'])
                end
                true
            end
        end
    end
end
