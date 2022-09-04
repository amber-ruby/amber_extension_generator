# frozen_string_literal: true

require_relative 'amber_extension_generator/version'

module ::AmberExtensionGenerator
  class Error < ::StandardError; end
end

require_relative 'amber_extension_generator/cli'
