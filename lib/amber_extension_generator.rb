# frozen_string_literal: true

require_relative 'amber_extension_generator/version'
require_relative 'amber_extension_generator/gem_name'

require 'pathname'

module ::AmberExtensionGenerator
  class Error < ::StandardError; end
  # @return [Pathname]
  ROOT_GEM_PATH = ::Pathname.new ::File.expand_path('..', __dir__)
  # @return [Pathname]
  TEMPLATES_FOLDER_PATH = ROOT_GEM_PATH / 'lib' / 'amber_extension_generator' / 'templates'
end

require_relative 'amber_extension_generator/cli'
