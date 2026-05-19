# frozen_string_literal: true

module XDG
  # A generic key-value pair (KVP).
  Pair = Data.define :key, :value do
    def initialize key: nil, value: nil
      super
    end

    def to_env = {key => value}

    def key? = key.to_s.size.positive?

    def value? = value.to_s.size.positive?

    def empty? = !(key? && value?)

    def inspect = key? || value? ? "#{key}#{DELIMITER}#{value}" : ""
  end
end
