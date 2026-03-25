
module ConfigLMM
    module LMM
        class SELinux < Framework::Plugin

            def actionSELinuxDeploy(id, target, activeState, context, options)
                # TODO
            end

            def self.addPort(linuxConnection, type, proto, port, context, options)
                if linuxConnection.selinux?
                    linuxConnection.exec("semanage port --add --type #{type}_port_t --proto #{proto} #{port}", false, options)
                end
            end

            def self.restoreContext(path, linuxConnection, options)
                if linuxConnection.selinux?
                    linuxConnection.exec("restorecon -R #{linuxConnection.escapePath(path)}", false, options)
                end
            end

        end
    end
end
