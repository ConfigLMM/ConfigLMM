
module ConfigLMM
    module LMM
        class Rspamd < Framework::Plugin
            PACKAGE_NAME = 'Rspamd'
            SERVICE_NAME = 'rspamd'

            DKIM_SECRET_ID = 'DKIM'
            DKIM_KEY_LOCATION = '/etc/dkim/'

            def actionRspamdDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.ensurePackage(PACKAGE_NAME, options)
                        linuxConnection.ensureServiceAutoStart(SERVICE_NAME, options)

                        configureValkey(target, linuxConnection, context, options)
                        configureDKIM(target, linuxConnection, context, options)

                        linuxConnection.restartService(SERVICE_NAME, options)
                    end
                end
            end

            def configureValkey(target, linuxConnection, context, options)
                if target.key?('Valkey') && target['Valkey']
                    valkeyConfig = {}
                    if target['Valkey'].is_a?(Hash)
                        valkeyConfig = target['Valkey'].to_h
                    elsif target['Valkey'].is_a?(String)
                        valkeyConfig['Host'] = target['Valkey'].to_s
                    end
                    valkeyConfig['Host'] = '127.0.0.1' unless valkeyConfig['Host']
                    valkeyPassword = valkeyConfig['SecretId'] ? context.secrets.load(target['Valkey']['SecretId'], 'VALKEY_PASSWORD') : nil
                    linuxConnection.updateFile('/etc/rspamd/local.d/redis.conf', options) do |fileLines|
                        fileLines << "servers = \"#{valkeyConfig['Host']}\"\n"
                        fileLines << "password = \"#{valkeyPassword}\"\n" if valkeyPassword
                    end
                end
            end

            def configureDKIM(target, linuxConnection, context, options)
                generateKeys(target, linuxConnection, context, options)
                linuxConnection.updateFile('/etc/rspamd/local.d/dkim_signing.conf', options) do |fileLines|
                    fileLines << 'path = "' + DKIM_KEY_LOCATION + '$domain.$selector.key";' + "\n"
                    fileLines << 'domain {' + "\n"

                    target['Domains'].to_a.each do |domain|
                        lowercaseDomain = domain.downcase
                        fileLines << '  ' + lowercaseDomain + " {\n"
                        fileLines << "    selectors [\n"
                        rsaSelector = context.secrets.load(DKIM_SECRET_ID, domain + '_RSA_SELECTOR')
                        if rsaSelector
                            fileLines << "      {\n"
                            fileLines << "        selector:  \"#{rsaSelector}\";\n"
                        end
                        edsaSelector = context.secrets.load(DKIM_SECRET_ID, domain + '_ED25519_SELECTOR')
                        if edsaSelector
                            if rsaSelector
                                fileLines << "      },\n"
                            end
                            fileLines << "      {\n"
                            fileLines << "        selector:  \"#{edsaSelector}\";\n"
                        end
                        if rsaSelector || edsaSelector
                            fileLines << "      }\n"
                        end
                        fileLines << "    ]\n"
                        fileLines << "  }\n"
                    end
                    fileLines << '}' + "\n"
                end
            end

            def generateKeys(target, linuxConnection, context, options)
                linuxConnection.createDirs(options, DKIM_KEY_LOCATION)
                linuxConnection.setPrivateDir(DKIM_KEY_LOCATION, options)
                linuxConnection.setUserGroup(DKIM_KEY_LOCATION, '_rspamd', '_rspamd', options)
                target['Domains'].to_a.each do |domain|
                    timestamp = Time.now.to_i
                    rsaSelector = context.secrets.load(DKIM_SECRET_ID, domain + '_RSA_SELECTOR') || generateSelector(timestamp, 'rsa')
                    rsaKey = context.secrets.load(DKIM_SECRET_ID, domain + '_RSA_KEY')
                    edsaSelector = context.secrets.load(DKIM_SECRET_ID, domain + '_ED25519_SELECTOR') || generateSelector(timestamp, 'ed25519')
                    edsaKey = context.secrets.load(DKIM_SECRET_ID, domain + '_ED25519_KEY')
                    rsaKeyFile = getKeyFile(domain, rsaSelector)
                    edsaKeyFile = getKeyFile(domain, edsaSelector)
                    if !linuxConnection.filePresent?(rsaKeyFile, options) || !linuxConnection.filePresent?(edsaKeyFile, options) || !rsaKey || !edsaKey
                        rsaSelector = generateSelector(timestamp, 'rsa')
                        edsaSelector = generateSelector(timestamp, 'ed25519')
                        rsaKeyFile = getKeyFile(domain, rsaSelector)
                        edsaKeyFile = getKeyFile(domain, edsaSelector)
                        rsaKey = linuxConnection.exec("rspamadm dkim_keygen --privkey #{rsaKeyFile} --type RSA --bits 2048 --output dnskey", false, options).strip
                        edsaKey = linuxConnection.exec("rspamadm dkim_keygen --privkey #{edsaKeyFile} --type ED25519 --output dnskey", false, options).strip
                        linuxConnection.setUserGroup(rsaKeyFile, '_rspamd', '_rspamd', options)
                        linuxConnection.setUserGroup(edsaKeyFile, '_rspamd', '_rspamd', options)
                        if !options['dry']
                            context.secrets.store(DKIM_SECRET_ID, domain + '_RSA_SELECTOR', rsaSelector)
                            context.secrets.store(DKIM_SECRET_ID, domain + '_RSA_KEY', rsaKey)
                            context.secrets.store(DKIM_SECRET_ID, domain + '_ED25519_SELECTOR', edsaSelector)
                            context.secrets.store(DKIM_SECRET_ID, domain + '_ED25519_KEY', edsaKey)
                        end
                    end
                end
            end

            def generateSelector(timestamp, type)
                type + '-' + Time.now.to_i.to_s
            end

            def getKeyFile(domain, selector)
                DKIM_KEY_LOCATION + domain.downcase + '.' + selector + '.key'
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Rspamd, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.disableService(SERVICE_NAME, options)
                        linuxConnection.stopService(SERVICE_NAME, options)
                        linuxConnection.removePackage(PACKAGE_NAME, options)

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            linuxConnection.rm('/etc/rspamd', options[:dry])
                            # Not sure if we should delete this...
                            linuxConnection.rm('/etc/dkim', options[:dry])

                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end

        end

    end
end
