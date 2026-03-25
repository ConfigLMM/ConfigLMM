
module ConfigLMM
    module LMM
        class Cassandra < Framework::Plugin
            PACKAGE_NAME = 'Cassandra'
            SERVICE_NAME = 'cassandra'

            def actionCassandraDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.ensurePackage(PACKAGE_NAME, options)
                        linuxConnection.ensureServiceAutoStart(SERVICE_NAME, options)

                        if linuxConnection.distroInfo['Name'] == 'openSUSE Leap'
                            configFile = '/etc/cassandra/conf/cassandra.yaml'
                        end

                        linuxConnection.fileReplace(configFile, /^uuid_sstable_identifiers_enabled:.*/, 'uuid_sstable_identifiers_enabled: true', options)
                        if target['ClusterName']
                            linuxConnection.fileReplace(configFile, /^cluster_name:.*/, "cluster_name: #{target['ClusterName']}", options)
                        end

                        linuxConnection.restartService(SERVICE_NAME, options)
                    end
                end
            end

        end

    end
end
