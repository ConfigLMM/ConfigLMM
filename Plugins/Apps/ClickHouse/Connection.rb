
module ConfigLMM
    module LMM
        class ClickHouseConnection

            attr_reader :connection
            attr_reader :settings

            def initialize(connection, settings)
                @connection = connection
                @settings = settings
            end

            def exec(query, allowFailure = false, options = {})
                cmd = "clickhouse-client --query '#{LinuxShell.escapeSingleQuotes(query)}'"
                begin
                    connection.exec(cmd, allowFailure, options)
                rescue IO::ExecError => error
                    # Retry
                    # Code: 210. DB::NetException: Connection refused (localhost:9000). (NETWORK_ERROR)
                    if error.stderr.include?('NETWORK_ERROR')
                        sleep(5)
                        connection.exec(cmd, allowFailure, options)
                    else
                        raise
                    end
                end
            end

            def createUser(user, password, cluster, options)
                clusterSQL = ''
                if cluster
                    clusterSQL = " ON CLUSTER #{cluster}"
                end
                exec("CREATE USER IF NOT EXISTS #{user}#{clusterSQL}", false, options)
                if password
                    sql = "ALTER USER #{user} IDENTIFIED WITH bcrypt_password by '#{password}'"
                    exec(sql, false, { **options, hide: true })
                end
            end

            def dropUser(user, cluster, options = {})
                clusterSQL = ''
                if cluster
                    clusterSQL = " ON CLUSTER #{cluster}"
                end
                exec("DROP USER IF EXISTS #{user}#{clusterSQL}", false, options)
            end

            def createDB(database, cluster, options = {})
                clusterSQL = ''
                if cluster
                    clusterSQL = " ON CLUSTER #{cluster}"
                end
                exec("CREATE DATABASE IF NOT EXISTS #{database}#{clusterSQL}", false, options)
            end

            def dropDB(database, cluster, options = {})
                clusterSQL = ''
                if cluster
                    clusterSQL = " ON CLUSTER #{cluster}"
                end
                exec("DROP DATABASE IF EXISTS #{database}#{clusterSQL}", false, options)
            end

            def grant(privilege, user, target, cluster, options = {})
                clusterSQL = ''
                if cluster
                    clusterSQL = "ON CLUSTER #{cluster}"
                end
                exec("GRANT #{clusterSQL} #{privilege} ON #{target} TO #{user}", false, options)
            end

            def grantDB(privilege, user, database, cluster, options = {})
                grant(privilege, user, database + '.*', cluster, options)
            end

            def grantCluster(user, cluster, options = {})
                clusterSQL = ''
                if cluster
                    clusterSQL = "ON CLUSTER #{cluster}"
                end
                exec("GRANT #{clusterSQL} CLUSTER ON *.* TO #{user}", false, options)
            end

            def grantRemote(user, cluster, options = {})
                clusterSQL = ''
                if cluster
                    clusterSQL = "ON CLUSTER #{cluster}"
                end
                exec("GRANT #{clusterSQL} REMOTE ON *.* TO #{user}", false, options)
            end

        end
    end
end
