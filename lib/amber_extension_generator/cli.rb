# frozen_string_literal: true

require 'optparse'

module ::AmberExtensionGenerator
  # Contains all code which interacts with the terminal.
  module CLI
    class << self
      def run
        GemGenerator.call Args.parse
      end
    end
  end
end

require_relative 'cli/args'
require_relative 'cli/gem_generator'
