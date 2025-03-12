
require 'octokit'

module ConfigLMM
    module LMM
        class GitHub < Framework::Plugin

            def actionGitHubRefresh(id, target, activeState, context, options)
                if !target['Organizations'].to_h.empty?
                    activeState['Organizations'] = {}
                    target['Organizations'].each do |name, organization|
                        organizationRefresh(name, target, activeState, context, options)
                    end
                end
            end

            def actionGitHubDiff(id, target, activeState, context, options)
                state = prepareState(target, activeState)
                shouldMatch(id, state, 'Organizations', target, 'Organizations')
            end

            def actionGitHubDeploy(id, target, activeState, context, options)
                actionGitHubDiff(id, target, activeState, context, options)
                diff.each do |name, states|
                    # TODO FIXME
                end
            end

            def prepareState(target, activeState)
                state = activeState.dup
                state['Organizations'] ||= {}
                state['Organizations'].each do |name, data|
                    #state['Organizations'][name]['Name'] = state['Organizations'][name].delete('Login')
                    state['Organizations'][name]['Description'] = state['Organizations'][name].delete('description')
                end
                state
            end

            def organizationRefresh(name, target, activeState, context, options)
                authToken = context.secrets.load(target['SecretId'], 'TOKEN')
                authToken = context.secrets.load('GITHUB', 'TOKEN') if authToken.nil?
                client = Octokit::Client.new(:access_token => authToken)

                allOrgs = client.organizations
                if allOrgs.empty?
                    # Fine-grained access token never returns any orgs
                    org = client.organization(name)
                else
                    orgs = allOrgs.select { |org| org[:login] == name }
                    if orgs.empty?
                        prompt.say("Didn\'t find organization with name #{name}")
                        prompt.say('You need to create it manually - https://github.com/organizations/plan')
                        raise Framework::PluginPrerequisite.new('Organization must exist!')
                    end
                    org = orgs.first
                end

                activeState['Organizations'][org.login] ||= {}

                org.each do |name, value|
                    data = value
                    data = value.to_h if value && value.respond_to?(:to_h)
                    data = value.to_s if value.is_a?(Time)
                    activeState['Organizations'][org.login][name.to_s] = data
                end
            end

            def authenticate(actionMethod, target, activeState, context, options)
                authToken = context.secrets.load(target['SecretId'], 'TOKEN')
                authToken = context.secrets.load('GITHUB', 'TOKEN') if authToken.nil?
                if authToken.to_s.empty?
                    prompt.say('Open https://github.com/settings/tokens and create a token!')
                    prompt.say("Then set it\'s value in #{target['SecretId']}_TOKEN")
                    raise Framework::PluginPrerequisite.new('Need GitHub token!')
                end
                true
            end

            def self.getReleases(repoId, logger, context, options)
                response = HTTP.get("https://api.github.com/repos/#{repoId}/releases")
                if response.status.success?
                    releases = response.parse
                    releases.reject! { |release| release['draft'] || release['prerelease'] }
                    return releases
                end
                logger.error("Failed to load GitHub release for #{repoId}")
                raise response
            end

            def self.getReleaseAsset(name, releases)
                pattern = name.gsub('.', '\\.').gsub('*', '.*')
                releases.each do |release|
                    release['assets'].each do |asset|
                        return asset if asset['name'].match?(pattern)
                    end
                end
                raise "Couldn't find GitHub asset #{name}!"
            end

        end
    end
end
