
module ConfigLMM
    module LMM
        class LibreTranslate < Framework::Plugin

            USER = 'libretranslate'
            HOME_DIR = '/var/lib/libretranslate'

            def actionLibreTranslateDeploy(id, target, activeState, context, options)

                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'LibreTranslate', linuxConnection, options)

                        path = Podman.containersPath(HOME_DIR)

                        linuxConnection.upload(__dir__ + '/LibreTranslate.container', path, options)

                        args = ['--metrics']
                        linuxConnection.fileReplace("#{path}/LibreTranslate.container", '\$ARGS', args.join(' '), options)
                        if target['Listen']
                            linuxConnection.fileReplace("#{path}/LibreTranslate.container", '127.0.0.1', target['Listen'], options)
                        end

                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, 'LibreTranslate', options)
                    end
                end
            end

        end
    end
end
