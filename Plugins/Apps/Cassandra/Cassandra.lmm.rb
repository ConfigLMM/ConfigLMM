
module ConfigLMM
    module LMM
        class Cassandra < Framework::Plugin
            PACKAGE_NAME = 'Cassandra'
            SERVICE_NAME = 'cassandra'

            def actionCassandraDeploy(id, target, activeState, context, options)
                plugins[:Linux].ensurePackage(PACKAGE_NAME, target['Location'])
                plugins[:Linux].ensureServiceAutoStart(SERVICE_NAME, target['Location'])

                if target['Location'] && target['Location'] != '@me'
                    uri = Addressable::URI.parse(target['Location'])
                    raise Framework::PluginProcessError.new("#{id}: Unknown Protocol: #{uri.scheme}!") if uri.scheme != 'ssh'

                    self.class.sshStart(uri) do |ssh|
                        distroInfo = Framework::LinuxApp.currentDistroInfo(ssh)
                        configFile = '/etc/cassandra/cassandra.yaml'
                        if distroInfo['Name'] == 'openSUSE Leap'
                            configFile = '/etc/cassandra/conf/cassandra.yaml'
                        end

                        cmd = "sed -i 's|^uuid_sstable_identifiers_enabled:.*|uuid_sstable_identifiers_enabled: true|' #{configFile}"
                        self.class.sshExec!(ssh, cmd)
                        if target['ClusterName']
                            cmd = "sed -i 's|^cluster_name:.*|cluster_name: #{target['ClusterName']}|' #{configFile}"
                            self.class.sshExec!(ssh, cmd)
                        end
                    end
                else
                    # TODO
                end

                plugins[:Linux].startService(SERVICE_NAME, target['Location'])
            end

        end

    end
end

