# frozen_string_literal: true

# Based on https://github.com/mastodon/mastodon/blob/main/lib/tasks/mastodon.rake#L7

namespace :configlmm do
    desc 'Configure the instance for production use'
    task :setup do
        username = 'admin'
        username = ENV['ADMIN_USERNAME'] if ENV['ADMIN_USERNAME']
        emailLocal, emailDomain = ENV['ADMIN_EMAIL'].to_s.split('@')
        password = ENV['ADMIN_PASSWORD']

        if !emailLocal.to_s.empty? && !emailDomain.to_s.empty? && !password.to_s.empty?
            require_relative '../../config/environment'
            require 'addressable/idna'

            email = emailLocal + '@' + Addressable::IDNA.to_ascii(emailDomain)
            user = User.where('LOWER(email) = ?', email.downcase).first
            account = Account.where('LOWER(username) = ?', username.downcase).first
            if !user && !account
                owner_role = UserRole.find_by(name: 'Owner')
                user = User.new(email: email, password: password, confirmed_at: Time.now.utc, account_attributes: { username: username }, bypass_invite_request_check: true, role: owner_role)
                user.save(validate: false)
                user.approve!

                Setting.site_contact_username = username
            end
        end
    end
end
