# frozen_string_literal: true

require 'fileutils'

require 'rainbow/refinement'
require 'cli/ui'
require 'tty-command'

using ::Rainbow

module ::AmberExtensionGenerator
  module CLI
    # Generates a new extension gem
    class GemGenerator
      class << self
        # @param args [::AmberExtensionGenerator::CLI::Args]
        # @return [void]
        def call(args)
          new(args).call
        end
      end

      # @param args [::AmberExtensionGenerator::CLI::Args]
      def initialize(args)
        @args = args
      end

      # @return [void]
      def call
        ::CLI::UI::StdoutRouter.enable
        ::CLI::UI::Frame.open('Generate gem') do
          syscall("bundle gem #{root_path}")
        end

        ::CLI::UI::Frame.open('Patch gem') do
          create('lib/components/base.rb', <<~RUBY)
            # frozen_string_literal: true

            require 'amber_component'

            module #{root_module_name}
              # Abstract class which should serve as a superclass
              # for all components.
              #
              # @abstract Subclass to create a new component.
              class BaseComponent < ::AmberComponent::Base; end
            end
          RUBY
        end
      end

      private

      # @param command [String]
      # @return [String] STDOUT
      def syscall(command)
        cmd = ::TTY::Command.new(color: true, printer: :quiet)
        cmd.run!(command, pty: true)
      end

      # @return [Pathname]
      def root_path
        @args.gem_path
      end

      # @param file_path [String, Pathname]
      # @param content [String]
      def create(file_path, content)
        print "      create  ".green
        puts file_path

        path = root_path / file_path
        ::FileUtils.mkdir_p(path.dirname) unless path.dirname.directory?

        path.write(content)
      end

      # @param file_path [String, Pathname]
      # @param regexp [Regexp]
      # @param replacement [String]
      def substitute(file_path, regexp, replacement)
        puts "      substitute  ".blue
        puts file_path

        path = root_path / file_path
        file_content = path.read
        raise "Cannot substitute #{path} because #{regexp.inspect} was not found" unless file_content.match?(regexp)

        path.write file_content.sub(regexp, replacement)
      end

      # @return [String]
      def root_module_name
        camelize(@args.gem_name)
      end

      # @param string [String]
      # @param uppercase_first_letter [Boolean]
      # @return [String]
      def camelize(string, uppercase_first_letter: true)
        string = if uppercase_first_letter
                   string.sub(/^[a-z\d]*/, &:capitalize)
                 else
                   string.sub(/^(?:(?=\b|[A-Z_])|\w)/, &:downcase)
                 end

        string = string.gsub(%r{(?:_|(/))([a-z\d]*)}) do
          "#{::Regexp.last_match(1)}#{::Regexp.last_match(2).capitalize}"
        end
        string.gsub('/', '::')
      end
    end
  end
end
