
module ConfigLMM
    module LMM
        class RVM < Framework::Plugin

            LATEST_RUBY_VERSION = '3.4.1'

            def actionRVMDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        installPackages(linuxConnection, target, options)
                        installRVM(linuxConnection, true, target, options)
                        if target['User']
                            linuxConnection.exec("usermod --append --groups rvm #{target['User']}")
                        end
                        installGems(linuxConnection, target, options)
                    end
                end
            end

            def installPackages(connection, target, options)
                packages = target['Packages'].to_a
                if !packages.empty?
                    connection.ensurePackages(packages, options)
                end
            end

            def installRVM(connection, installDeps, target, options)
                if !connection.hasBinaries?('rvm', options)
                    # Needs dirmngr
                    # connection.exec('gpg2 --keyserver hkp://keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB', false, options)

                    connection.exec('curl -sSL https://rvm.io/mpapis.asc | gpg --import -', false, options)
                    connection.exec('curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -', false, options)
                    extra = ''
                    if !installDeps
                        extra = ' --autolibs=read-fail'
                    end
                    connection.exec("curl --silent --show-error --location https://get.rvm.io | bash -s stable --ruby=#{LATEST_RUBY_VERSION}#{extra}", false, options)
                    installFishFunction(connection, target, options)
                end
            end

            def installFishFunction(connection, target, options)
                connection.exec('curl --silent --show-error --location --create-dirs --output /etc/fish/conf.d/rvm.fish https://raw.github.com/lunks/fish-nuggets/master/functions/rvm.fish', false, options)
                connection.fileAppend("/etc/fish/conf.d/rvm.fish", 'rvm default', options)
            end

            def installGems(connection, target, options)
                gems = target['Gems'].to_a.join(' ')
                if !gems.empty?
                    connection.exec("gem install #{gems}", false, options)
                end
            end
        end
    end
end
