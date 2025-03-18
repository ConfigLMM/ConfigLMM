#!/usr/bin/env ruby

require 'rails/generators'
require 'rails/generators/rails/encryption_key_file/encryption_key_file_generator'
require 'rails/generators/rails/credentials/credentials_generator'

content_path = '/config/credentials.yml.enc'
key_path = '/config/master.key'

Rails::Generators::EncryptionKeyFileGenerator.new([], quiet: true).add_key_file(key_path)

Rails::Generators::CredentialsGenerator.new(
    [content_path, key_path],
    skip_secret_key_base: false,
    quiet: true
).invoke_all

# TODO
# should apply config/credentials.yml.enc.sample to config
