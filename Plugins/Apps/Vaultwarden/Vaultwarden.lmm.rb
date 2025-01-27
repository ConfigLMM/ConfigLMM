
require 'fileutils'
require 'argon2'
require 'securerandom'

module ConfigLMM
    module LMM
        class Vaultwarden < Framework::Plugin

            NAME = 'Vaultwarden'
            USER = 'vaultwarden'
            HOME_DIR = '/var/lib/vaultwarden'
            SERVICE_PORT = '18000'

            def actionVaultwardenBuild(id, target, state, context, options)
                Nginx.withConnection(local) do |nginxConnection|
                    nginxConnection.writeConfig(__dir__, NAME, target, state, context, options)
                end
            end

            def actionVaultwardenDiff(id, target, activeState, context, options)
                # TODO
            end

            def actionVaultwardenDeploy(id, target, activeState, context, options)
                self.withConnection(target['Location'], target) do |connection|
                    Linux.withConnection(connection) do |linuxConnection|
                        if !target.key?('Proxy') || target['Proxy'] != 'only'

                            Podman.ensurePresent(linuxConnection, options)
                            Podman.createUser(USER, HOME_DIR, 'Vaultwarden', linuxConnection, options)
                            linuxConnection.withUserShell(USER) do |shell|
                                shell.createDirs(options, '~/data')
                            end

                            path = Podman.containersPath(HOME_DIR)
                            linuxConnection.fileWrite("#{path}/Vaultwarden.env", 'ROCKET_PORT=8000', options)
                            if target['Domain']
                                linuxConnection.fileAppend("#{path}/Vaultwarden.env", "DOMAIN=https://#{target['Domain']}", options)
                            end
                            target['Signups'] = false unless target['Signups']
                            linuxConnection.fileAppend("#{path}/Vaultwarden.env", "SIGNUPS_ALLOWED=#{target['Signups'].to_s}", options)
                            if target.key?('Invitations')
                                linuxConnection.fileAppend("#{path}/Vaultwarden.env", "INVITATIONS_ALLOWED=#{target['Invitations'].to_s}", options)
                            end
                            adminToken = context.secrets.load(target['SecretId'], 'VAULTWARDEN_ADMIN_TOKEN')
                            if !adminToken
                                adminToken = SecureRandom.alphanumeric(40)
                                context.secrets.store(target['SecretId'], 'VAULTWARDEN_ADMIN_TOKEN', adminToken)
                            end

                            adminTokenHash = Argon2::Password.new(profile: :rfc_9106_low_memory).create(adminToken)

                            linuxConnection.fileAppend("#{path}/Vaultwarden.env", "ADMIN_TOKEN=#{adminTokenHash}", { **options, hide: true })
                            linuxConnection.setUserGroup("#{path}/Vaultwarden.env", USER, USER, options)
                            linuxConnection.setPrivate("#{path}/Vaultwarden.env", options)
                            linuxConnection.upload(__dir__ + '/Vaultwarden.container', path, options)
                            linuxConnection.reloadUserServices(USER, options)
                            linuxConnection.restartUserService(USER, 'Vaultwarden', options)
                            if target['Proxy'] != 'only'
                                linuxConnection.firewallAddPort(SERVICE_PORT + '/tcp', options)
                            end
                        end
                        if !target.key?('Proxy') || !!target['Proxy']
                            Nginx.withConnection(linuxConnection) do |nginxConnection|
                                nginxConnection.writeConfig(__dir__, NAME, target, state, context, options)
                                nginxConnection.deployAllConfigs(target, activeState, context, options)
                            end
                        end
                    end
                end
            end

        end
    end
end
