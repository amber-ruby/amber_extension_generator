# frozen_string_literal: true

require_relative 'amber_extension_generator/version'

require 'pathname'

module ::AmberExtensionGenerator
  class Error < ::StandardError; end
  # @return [Pathname]
  ROOT_GEM_PATH = ::Pathname.new ::File.expand_path('..', __dir__)
end

require_relative 'amber_extension_generator/cli'
