
module ConfigLMM
    module LMM
        class Utils < Framework::Plugin

            def actionFilesystemDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if target['Copy']
                            target['Copy'].each do |source, target|
                                linuxConnection.upload(source, target, options)
                            end
                        end
                    end
                end
            end

        end
    end
end
