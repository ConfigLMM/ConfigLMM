# encoding: UTF-8
# frozen_string_literal: true

require 'yaml'

module ConfigLMM
    class State

        def initialize(logger, prompt)
            @Logger = logger
            @Prompt = prompt
            @State = nil
            @StateFile = nil
        end

        def load!(configList, options)
            if options['state']
                @StateFile = options['state']
            else
                @StateFile = self.findStateFile(configList)
            end
            begin
                @State = YAML.safe_load_file(@StateFile, permitted_classes: [Symbol])
            rescue Errno::EISDIR => error
                 # TODO
                 raise error
            rescue Errno::ENOENT => error
                @Logger.debug(error)
                # Couldn't find state file
                # Maybe this is first run
                # and we might need to create it
            end
        end

        def create!
            if @State.nil?
                result = @Prompt.yes?('Couldn\'t find state file, create it?') do |q|
                    q.default false
                end
                if result
                    @State = {}
                else
                    raise 'Aborting!'
                end
            end
        end

        def item(id)
            @State[id] ||= {}
            @State[id]
        end

        def selectType(type)
            items = {}
            @State.each do |id, item|
                items[id] = item if item[:Type] == type.to_s
            end
        end

        def save
            File.open(@StateFile, 'w') do |file|
                file.write(YAML.dump(@State))
            end
        end

        private

        def findStateFile(configList)
            parent = configList.to_a.first.parent
            sameParent = configList.to_a.all? { |item| item.parent == parent }
            if sameParent
                parent.to_s + '/.lmm.state.yaml'
            else
                # FIXME TODO
                # Find common ancestor and use that as a path to the state file
                raise 'Unimplemented!'
            end
        end
    end
end
