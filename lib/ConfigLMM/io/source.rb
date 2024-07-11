# frozen_string_literal: true

module ConfigLMM
    module IO
        class Source

            def initialize(parent = nil)
                unless parent.nil? || parent.is_a?(Source)
                    raise "Invalid parent! Must be instance of Source! Got #{parent.inspect}"
                end
                @ID = false
                @Parent = parent
                @Childs = {}
                @Parent.addChild(self) if @Parent.is_a?(Source)
            end

            def id
                return @ID unless @ID == false
                if @Parent.is_a?(Source)
                    @ID = self.name
                    @ID = @Parent.id + '/' + @ID if @Parent.id
                else
                    @ID = nil
                end
                @ID
            end

            def parent
                @Parent
            end

            def [](name)
                raise "Didn't find #{name} in #{self.inspect}" unless @Childs.key?(name)
                @Childs[name]
            end

            protected

            def addChild(child)
                raise "Invalid child! Must be instance of Source! Got #{child.inspect}" unless child.is_a?(Source)
                return if @Childs.key?(child.name)
                @Childs[child.name] = child
            end

        end
    end
end
