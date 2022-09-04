# frozen_string_literal: true

require 'pathname'

module ::AmberExtensionGenerator
  module CLI
    # Parses and wraps all provided CLI arguments.
    class Args
      BANNER = <<~DOC
        Usage:
          amber_extension_generator GEM_PATH
          amber_extension_generator [options]

      DOC

      class << self
        # @param argv [Array<String>]
        # @return [self]
        def parse(argv = ::ARGV)
          args = new

          opt_parser = ::OptionParser.new do |opts|
            opts.banner = BANNER

            opts.on('-v', '--version', 'Show the version of the gem') do |_val|
              puts VERSION
              exit
            end

            opts.on('-h', '--help', 'Show this help') do |_val|
              puts opts
              exit
            end
          end

          args.gem_path = ::Pathname.new(::File.expand_path(argv.first))
          opt_parser.parse(argv)

          args
        end
      end

      # @return [Pathname] Path of the newly generated gem
      attr_accessor :gem_path
    end
  end
end
