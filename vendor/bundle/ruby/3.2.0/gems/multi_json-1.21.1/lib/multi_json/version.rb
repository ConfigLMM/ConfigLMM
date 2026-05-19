# frozen_string_literal: true

module MultiJSON
  # Version information for MultiJSON
  #
  # @api private
  class Version
    # Major version number
    MAJOR = 1 unless defined? MultiJSON::Version::MAJOR
    # Minor version number
    MINOR = 21 unless defined? MultiJSON::Version::MINOR
    # Patch version number
    PATCH = 1 unless defined? MultiJSON::Version::PATCH
    # Pre-release version suffix
    PRE = nil unless defined? MultiJSON::Version::PRE

    class << self
      # Return the version string
      #
      # @api private
      # @return [String] version in semver format
      def to_s
        [MAJOR, MINOR, PATCH, PRE].compact.join(".")
      end
    end
  end

  # Current version string in semver format
  VERSION = Version.to_s.freeze
end
