
require 'octokit'

module ConfigLMM
    module LMM
        class GitHub < Framework::Plugin

            def actionGitHubOrganizationRefresh(id, target, activeState, context, options)

                client = Octokit::Client.new(:access_token => ENV['GITHUB_TOKEN'])
                orgs = client.organizations.select { |org| org[:login] == target['Name'] }
                if orgs.empty?
                    prompt.say("Didn\'t find organization with name #{target['Name']}")
                    prompt.say('You need to create it manually - https://github.com/organizations/plan')
                    raise Framework::PluginPrerequisite.new('Organization must exist!')
                end

                raise "This shouldn't happen!" if orgs.length != 1

                activeState.clear

                orgs.first.each do |name, value|
                    activeState[name.to_s] = value
                end
            end

            def actionGitHubOrganizationDiff(id, target, activeState, context, options)
                shouldMatch(id, activeState['Config'], 'login', target, 'Name')
                shouldMatch(id, activeState['Config'], 'description', target, 'Description')
            end

            def actionGitHubOrganizationDeploy(id, target, activeState, context, options)
                actionGitHubOrganizationDiff(id, target, activeState, context, options)
                diff.each do |name, states|
                    if name == 'Name'
                        # TODO
                    elsif name == 'Description'
                        # TODO
                    end
                end
                # TODO FIXME
                raise 'Not implemented!'
            end

            def authenticate(actionMethod, target, activeState, context, options)
                authToken = ENV['GITHUB_TOKEN']
                if authToken.to_s.empty?
                    prompt.say('Open https://github.com/settings/tokens and create a token!')
                    prompt.say('Then set it\'s value to GITHUB_TOKEN as Environment Variable')
                    raise Framework::PluginPrerequisite.new('Need GITHUB_TOKEN!')
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
