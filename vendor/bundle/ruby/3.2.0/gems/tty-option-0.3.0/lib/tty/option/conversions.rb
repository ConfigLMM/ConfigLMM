# frozen_string_literal: true

require_relative "const"
require_relative "converter"

module TTY
  module Option
    module Conversions
      extend Converter

      TRUE_VALUES = /^(true|y(es)?|t|1)$/i.freeze
      FALSE_VALUES = /^(false|n(o)?|f|0)$/i.freeze

      convert :bool, :boolean do |val|
        case val.to_s
        when TRUE_VALUES
          true
        when FALSE_VALUES
          false
        else
          Const::Undefined
        end
      end

      convert :date do |val|
        require "date" unless defined?(::Date)
        next val if val.is_a?(::Date)

        begin
          ::Date.parse(val)
        rescue ArgumentError, TypeError
          Const::Undefined
        end
      end

      convert :float do |val|
        begin
          Float(val)
        rescue ArgumentError, TypeError
          Const::Undefined
        end
      end

      convert :int, :integer do |val|
        begin
          Float(val).to_i
        rescue ArgumentError, TypeError
          Const::Undefined
        end
      end

      convert :pathname, :path do |val|
        require "pathname" unless defined?(::Pathname)
        next val if val.is_a?(::Pathname)

        begin
          ::Pathname.new(val)
        rescue TypeError
          Const::Undefined
        end
      end

      convert :regexp do |val|
        begin
          Regexp.new(val)
        rescue TypeError, RegexpError
          Const::Undefined
        end
      end

      convert :sym, :symbol do |val|
        begin
          String(val).to_sym
        rescue ArgumentError, TypeError
          Const::Undefined
        end
      end

      convert :uri do |val|
        require "uri" unless defined?(::URI)
        next val if val.is_a?(::URI)

        begin
          ::URI.parse(val)
        rescue ::URI::InvalidURIError
          Const::Undefined
        end
      end

      convert :list, :array do |val|
        next Const::Undefined if val.nil?
        next Array(val) unless val.respond_to?(:split)

        val.split(/(?<!\\),/)
           .map { |v| v.strip.gsub(/\\,/, ",") }
           .reject(&:empty?)
      end

      convert :map, :hash do |val|
        next Const::Undefined if val.nil?
        next val if val.is_a?(Hash)

        values = val.respond_to?(:split) ? val.split(/[& ]/) : Array(val)
        values.each_with_object({}) do |pair, pairs|
          is_string = pair.respond_to?(:split)
          key, value = is_string ? pair.split(/[=:]/, 2) : pair
          new_key = is_string ? key.to_sym : key
          current = pairs[new_key]
          pairs[new_key] = current ? Array(current) << value : value
        end
      end

      conversions.keys.each do |type|
        next if type =~ /list|array|map|hash/

        [:"#{type}_list", :"#{type}_array", :"#{type}s"].each do |new_type|
          convert new_type do |val|
            list_conversion = conversions[:list].(val)
            next list_conversion if list_conversion == Const::Undefined

            list_conversion.map do |obj|
              converted = conversions[type].(obj)
              break converted if converted == Const::Undefined
              converted
            end
          end
        end

        [:"#{type}_map", :"#{type}_hash"].each do |new_type|
          convert new_type do |val|
            map_conversion = conversions[:map].(val)
            next map_conversion if map_conversion == Const::Undefined

            conversions[:map].(val).each_with_object({}) do |(k, v), h|
              converted = conversions[type].(v)
              break converted if converted == Const::Undefined
              h[k] = converted
            end
          end
        end
      end
    end # Conversions
  end # Option
end # TTY
