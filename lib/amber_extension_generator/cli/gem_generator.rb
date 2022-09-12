# frozen_string_literal: true

require 'fileutils'

require 'rainbow/refinement'
require 'cli/ui'
require 'tty-command'
# require 'byebug'

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
        ::CLI::UI::Frame.open 'Create gem', color: :green do
          ::CLI::UI::Frame.open 'Generate gem with bundler' do
            syscall "bundle gem #{root_path}"
          end

          ::CLI::UI::Frame.open 'Patch gem' do
            create gem_entry_folder_path / 'components' / 'base_component.rb', <<~RUBY
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

            create gem_entry_folder_path / 'components.rb', <<~RUBY
              # frozen_string_literal: true

              require_relative 'components/base_component'
              ::Dir['components/**/*'].sort.each { require_relative _1 }
            RUBY

            substitute gem_entry_file_path, /^end/, <<~RUBY.chomp
              end

              require_relative '#{gem_entry_folder_path.basename}/components.rb'
            RUBY

            create '.rubocop.yml', ::File.read(ROOT_GEM_PATH / '.rubocop.yml')

            substitute "#{gem_name}.gemspec", /^end/, <<~RUBY.chomp
                # ignore the dummy Rails app when building the gem
                spec.files.reject! { _1.match(/^dummy_app/) }
                spec.add_dependency 'amber_component', '~> #{VERSION}'
              end
            RUBY
          end
        end
        puts

        ::CLI::UI::Frame.open 'Rails dummy app', color: :magenta do
          unless syscall? 'gem list -i rails'
            ::CLI::UI::Frame.open 'Install Rails' do
              syscall('gem install rails')
            end
          end

          ::CLI::UI::Frame.open 'Generate app' do
            syscall "rails new #{root_path / rails_dummy_path} -m #{rails_template_path}", env: { GEM_NAME: gem_name }
          end

          ::CLI::UI::Frame.open 'Patch app' do
            append rails_dummy_path / 'Gemfile', <<~RUBY

              # === GEM AUTO-RELOADING ===

              class ::ExtensionGem
                # @return [String] Name of the gem.
                attr_reader :name
                # @return [Pathname] Path to the gem.
                attr_reader :path
                # @return [Array<Symbol>] Top-level constants defined by the gem.
                attr_reader :constants
                # @return [String]
                attr_reader :require_path

                # @param name [String]
                # @param path [String, Pathname]
                # @param constants [Array<Symbol>]
                # @param require_path [String, nil]
                def initialize(name:, path:, constants:, require_path: nil)
                  @name = name
                  @path = ::File.expand_path(path, __dir__)
                  @constants = constants
                  @require_path = require_path || @name.gsub('-', '/')
                end
              end

              # @return [ExtensionGem]
              ::AMBER_EXTENSION_GEM = ::ExtensionGem.new(
                name: #{gem_name.inspect},
                path: '..',
                constants: %i[#{root_module_name}].freeze
              )
              gem ::AMBER_EXTENSION_GEM.name, path: ::AMBER_EXTENSION_GEM.path

              # === END GEM AUTO-RELOADING ===
            RUBY
          end
        end
      end

      private

      # Performs a shell command with a PTY,
      # captures its output and logs it to this process's STDOUT.
      #
      # @param command [String]
      # @param env [Hash] Environment variables
      # @return [String] STDOUT
      def syscall(command, env: {})
        cmd = ::TTY::Command.new(color: true, printer: :quiet)
        cmd.run!(command, pty: true, input: "y\n", env: env)
      end

      # Performs a quiet shell command (without logging to STDOUT)
      # and returns the process's exit status.
      #
      # @param command [String]
      # @return [Boolean] whether the command was successful
      def syscall?(command)
        cmd = ::TTY::Command.new(printer: :null)
        !cmd.run!(command).failure?
      end

      # @return [Pathname]
      def gem_entry_file_path
        gem_entry_folder_path.sub_ext('.rb')
      end

      def gem_entry_folder_path
        ::Pathname.new('lib') / gem_name.gsub('-', '/')
      end

      # @return [String]
      def gem_name
        root_path.basename.to_s
      end

      # @return [Pathname]
      def rails_dummy_path
        ::Pathname.new 'dummy_app'
      end

      # @return [Pathname]
      def root_path
        @args.gem_path
      end

      # @return [Pathname]
      def rails_template_path
        ROOT_GEM_PATH / 'lib' / 'dummy_rails_app_template.rb'
      end

      # @param file_path [String, Pathname]
      # @param content [String]
      def create(file_path, content)
        print "  create      ".green
        puts file_path

        path = root_path / file_path
        ::FileUtils.mkdir_p(path.dirname) unless path.dirname.directory?

        path.write(content)
      end

      # @param file_path [String, Pathname]
      # @param regexp [Regexp]
      # @param replacement [String]
      # @return [void]
      def substitute(file_path, regexp, replacement)
        print "  substitute  ".blue
        puts file_path

        path = root_path / file_path
        file_content = path.read
        raise "Cannot substitute #{path} because #{regexp.inspect} was not found" unless file_content.match?(regexp)

        path.write file_content.sub(regexp, replacement)
      end

      # @param file_path [String, Pathname]
      # @param content[String]
      # @return [void]
      def append(file_path, content)
        print "  append      ".yellow
        puts file_path

        # @type [Pathname]
        path = root_path / file_path
        ::File.open(path, 'a') { _1.write(content) }
      end

      # @return [String]
      def root_module_name
        camelize(gem_name.gsub('-', '/'))
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

        string.gsub!(%r{(?:_|(/))([a-z\d]*)}) do
          "#{::Regexp.last_match(1)}#{::Regexp.last_match(2).capitalize}"
        end
        string.gsub('/', '::')
      end
    end
  end
end
