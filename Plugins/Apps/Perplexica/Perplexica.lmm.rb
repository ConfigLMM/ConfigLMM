
module ConfigLMM
    module LMM
        class Perplexica < Framework::Plugin

            USER = 'perplexica'
            HOME_DIR = '/var/lib/perplexica'

            def actionPerplexicaDeploy(id, target, activeState, context, options)

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'Perplexica', linuxConnection, options)
                        linuxConnection.withUserShell(USER) do |shell|
                                shell.createDirs(options, '~/data', '~/uploads')
                        end

                        linuxConnection.upload(__dir__ + '/config.toml', HOME_DIR, options)

                        grokKey = target['GrokSecretId'] ? context.secrets.load(target['GrokSecretId'], 'API_KEY') : nil
                        linuxConnection.fileReplace("#{HOME_DIR}/config.toml", '$GROQ_KEY', grokKey, options)

                        anthropicKey = target['AnthropicSecretId'] ? context.secrets.load(target['AnthropicSecretId'], 'API_KEY') : nil
                        linuxConnection.fileReplace("#{HOME_DIR}/config.toml", '$ANTHROPIC_KEY', anthropicKey, options)

                        geminiKey = target['GeminiSecretId'] ? context.secrets.load(target['GeminiSecretId'], 'API_KEY') : nil
                        linuxConnection.fileReplace("#{HOME_DIR}/config.toml", '$GEMINI_KEY', geminiKey, options)

                        deepseekKey = target['DeepSeekSecretId'] ? context.secrets.load(target['DeepSeekSecretId'], 'API_KEY') : nil
                        linuxConnection.fileReplace("#{HOME_DIR}/config.toml", '$DEEPSEEK_KEY', deepseekKey, options)

                        openaiKey = nil
                        openaiURL = nil
                        openaiModel = nil
                        if target['OpenAI'] && !target['OpenAI'].to_h.empty?
                            openaiKey = target['OpenAI']['SecretId'] ? context.secrets.load(target['OpenAI']['SecretId'], 'API_KEY') : nil
                            openaiURL = Podman.updateURL(target['OpenAI']['URL']) unless target['OpenAI']['URL'].to_s.empty?
                            openaiModel = target['OpenAI']['Model']
                        end
                        linuxConnection.fileReplace("#{HOME_DIR}/config.toml", '$OPENAI_KEY', openaiKey, options)
                        linuxConnection.fileReplace("#{HOME_DIR}/config.toml", '$OPENAI_URL', openaiURL, options)
                        linuxConnection.fileReplace("#{HOME_DIR}/config.toml", '$OPENAI_MODEL', openaiModel, options)

                        ollamaURL = nil
                        if target['Ollama'] && !target['Ollama'].to_h.empty?
                            ollamaURL = Podman.updateURL(target['Ollama']['URL'], Ollama::PORT)
                        end
                        linuxConnection.fileReplace("#{HOME_DIR}/config.toml", '$OLLAMA_URL', ollamaURL, options)

                        linuxConnection.setUserGroup("#{HOME_DIR}/config.toml", USER, USER, options)

                        path = Podman.containersPath(HOME_DIR)

                        searxng = Podman.updateURL(target['SearXNG'], SearXNG::PORT)

                        linuxConnection.fileWrite("#{path}/Perplexica.env", "SEARXNG_API_URL=#{searxng}", options)

                        linuxConnection.setUserGroup("#{path}/Perplexica.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/Perplexica.env", options)

                        linuxConnection.upload(__dir__ + '/Perplexica.container', path, options)

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'Perplexica', options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Perplexica, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        linuxConnection.stopUserService(USER, 'Perplexica', options)

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.rm(path + '/Perplexica.container', options[:dry])

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            linuxConnection.deleteUserAndGroup(USER, options)
                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end

        end
    end
end

