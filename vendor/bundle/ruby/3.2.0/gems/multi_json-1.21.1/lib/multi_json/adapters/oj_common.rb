# frozen_string_literal: true

module MultiJSON
  module Adapters
    # Shared functionality for the Oj adapter
    #
    # Provides option preparation for Oj.dump. Targets Oj 3.x; Oj 2.x is
    # no longer supported.
    #
    # @api private
    module OjCommon
      PRETTY_STATE_PROTOTYPE = {
        indent: "  ",
        space: " ",
        space_before: "",
        object_nl: "\n",
        array_nl: "\n",
        ascii_only: false
      }.freeze
      private_constant :PRETTY_STATE_PROTOTYPE

      private

      # Prepare options for Oj.dump
      #
      # Returns a fresh hash; never mutates the input. The input is the
      # cached options hash returned from Adapter.merged_dump_options, so
      # in-place mutation would pollute the cache and corrupt subsequent
      # dump calls.
      #
      # @api private
      # @param options [Hash] serialization options
      # @return [Hash] processed options for Oj.dump
      #
      # @example Prepare dump options
      #   prepare_dump_options(pretty: true)
      def prepare_dump_options(options)
        return options unless options.key?(:pretty)

        options.except(:pretty).merge(PRETTY_STATE_PROTOTYPE)
      end
    end
  end
end
