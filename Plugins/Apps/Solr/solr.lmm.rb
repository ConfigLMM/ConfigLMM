
module ConfigLMM
    module LMM
        class Solr < Framework::Plugin

            USER = 'solr'
            HOME_DIR = '/var/lib/solr'
            INSTALL_PATH = '/opt/solr'
            VERSION = '9.8.1'
            URL = "https://www.apache.org/dyn/closer.lua/solr/solr/#{VERSION}/solr-#{VERSION}.tgz?action=download"

            # Systemd support will be only with 10.x version but we want to already use it
            INSTALL_SCRIPT = 'https://raw.githubusercontent.com/apache/solr/ccd5ede68bf0cd19be63cda4e35a320842336e07/solr/bin/install_solr_service.sh'
            SYSTEMD_SERVICE = 'https://raw.githubusercontent.com/apache/solr/ccd5ede68bf0cd19be63cda4e35a320842336e07/solr/bin/systemd/solr.service'

            def actionSolrDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if linuxConnection.distroID == OS::ARCH_ID
                            linuxConnection.ensurePackage('solr', options)
                        else
                            if !linuxConnection.filePresent?(INSTALL_PATH)
                                linuxConnection.createServiceUser(USER, HOME_DIR, 'Apache Solr', options)

                                linuxConnection.exec("curl --silent --location --output /tmp/solr-#{VERSION}.tgz '#{URL}'", false, options)

                                # FIXME Once Solr 10.x is released
                                #linuxConnection.exec("tar --extract --strip-components=2 --directory /tmp --file /tmp/solr-#{VERSION}.tgz --wildcards '*/install_solr_service.sh'", false, options)
                                # BEGIN HACK
                                linuxConnection.exec("curl --silent --location --output /tmp/install_solr_service.sh '#{INSTALL_SCRIPT}'", false, options)
                                linuxConnection.exec("curl --silent --location --output /tmp/solr.service '#{SYSTEMD_SERVICE}'", false, options)
                                linuxConnection.exec("sed -i 's|$SOLR_INSTALL_DIR/bin/systemd|/tmp|' /tmp/install_solr_service.sh", false, options)
                                linuxConnection.exec("chmod +x /tmp/install_solr_service.sh", false, options)
                                # END HACK

                                linuxConnection.exec("/tmp/install_solr_service.sh /tmp/solr-#{VERSION}.tgz -u #{USER} -d #{HOME_DIR}", false, options)

                                linuxConnection.exec('rm -rf solr.service', false, options) # CLEANUP HACK

                                linuxConnection.exec("rm -rf /tmp/install_solr_service.sh /tmp/solr-#{VERSION}.tgz", false, options)

                                activeState['Version'] = VERSION

                                # To use JSON logging
                                linuxConnection.upload(__dir__ + '/log4j2.xml', HOME_DIR, options)
                                linuxConnection.restartService("solr.service", options)
                            end
                        end
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:Solr, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|

                        linuxConnection.stopService('solr.service', options)
                        linuxConnection.disableService('solr.service', options)

                        linuxConnection.rm('/etc/systemd/system/solr.service', options[:dry])

                        version = state.item(id)['Version']
                        if !version.to_s.empty?
                            linuxConnection.rm(INSTALL_PATH, options[:dry])
                            linuxConnection.rm(INSTALL_PATH + '-' + version, options[:dry])
                        end

                        state.item(id)['Status'] = State::STATUS_DELETED unless options[:dry]

                        if options[:destroy]
                            linuxConnection.deleteUserAndGroup(USER, options)
                            linuxConnection.rm(HOME_DIR, options[:dry])
                            linuxConnection.rm('/etc/default/solr.in.sh', options[:dry])
                            state.item(id)['Status'] = State::STATUS_DESTROYED unless options[:dry]
                        end
                    end
                end
            end
        end
    end
end

