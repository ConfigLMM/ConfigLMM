
module ConfigLMM
    module LMM
        class ZooKeeper < Framework::Plugin

            USER = 'zookeeper'
            HOME_DIR = '/var/lib/zookeeper'
            SERVICE_NAME = 'ZooKeeper'

            def actionZooKeeperDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        Podman.ensurePresent(linuxConnection, options)
                        Podman.createUser(USER, HOME_DIR, 'ZooKeeper', linuxConnection, options)
                        linuxConnection.withUserShell(USER) do |shell|
                            shell.createDirs(options, '~/data')
                        end

                        username = target['Username'] || context.secrets.load(target['SecretId'], 'USERNAME') || 'zookeeper'
                        context.secrets.store(target['SecretId'], 'USERNAME', username)
                        password = context.secrets.load(target['SecretId'], 'PASSWORD')
                        if password.nil?
                            password = SecureRandom.alphanumeric(20)
                            context.secrets.store(target['SecretId'], 'PASSWORD', password)
                            context.secrets.print("#{username} password", password)
                        end

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.fileWrite("#{path}/ZooKeeper.env", 'ZOO_ENABLE_AUTH=yes', options)
                        linuxConnection.fileAppend("#{path}/ZooKeeper.env", 'ZOO_AUTOPURGE_INTERVAL=1', options)

                        if target['ServerID']
                            linuxConnection.fileAppend("#{path}/ZooKeeper.env", "ZOO_SERVER_ID=#{target['ServerID']}", options)
                        end

                        linuxConnection.fileAppend("#{path}/ZooKeeper.env", "ZOO_SERVER_USERS=#{username}", options)
                        linuxConnection.fileAppend("#{path}/ZooKeeper.env", "ZOO_SERVER_PASSWORDS=#{password}", { **options, hide: true })
                        linuxConnection.setUserGroup("#{path}/ZooKeeper.env", USER, USER, options)
                        linuxConnection.setPrivate("#{path}/ZooKeeper.env", options)

                        linuxConnection.upload(__dir__ + '/ZooKeeper.container', path, options)
                        linuxConnection.reloadUserServices(USER, options)
                        linuxConnection.restartUserService(USER, SERVICE_NAME, options)
                    end
                end
            end

            def cleanup(configs, state, context, options)
                cleanupType(:ZooKeeper, configs, state, context, options) do |item, id, state, context, options, connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        linuxConnection.stopUserService(USER, SERVICE_NAME, options)

                        path = Podman.containersPath(HOME_DIR)
                        linuxConnection.rm("#{path}/ZooKeeper.container", options[:dry])

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
