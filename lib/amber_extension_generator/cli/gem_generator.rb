# frozen_string_literal: true

require 'fileutils'

require 'rainbow/refinement'
require 'cli/ui'
require 'tty-command'
require 'erb'

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
        generate_amber_gem
        puts
        generate_rails_dummy_app
      end

      private

      # @return [void]
      def generate_amber_gem
        ::CLI::UI::Frame.open 'Create gem', color: :green do
          ::CLI::UI::Frame.open 'Generate gem with bundler' do
            syscall "bundle gem #{root_path} --linter=rubocop --ci=github --test=test-unit", input: "y\n"
          end

          ::CLI::UI::Frame.open 'Patch gem' do
            template 'components/base_component.rb.erb', gem_entry_folder_path / 'components' / 'base_component.rb'

            copy 'components.rb', gem_entry_folder_path / 'components.rb'

            substitute gem_entry_file_path, /^end/, <<~RUBY.chomp
              end

              require_relative '#{gem_entry_folder_path.basename}/components'
              # Override this if you want to have a different name for the
              # base component of your gem
              #{root_module_name}::ABSTRACT_COMPONENT = #{root_module_name}::BaseComponent
            RUBY

            create '.rubocop.yml', ::File.read(ROOT_GEM_PATH / '.rubocop.yml')

            template 'bin/generate.erb', 'bin/generate'
            make_executable 'bin/generate'

            make_dir 'templates'

            copy 'templates/component.rb.tt'
            copy 'templates/style.css.tt'
            copy 'templates/view.html.erb.tt'
            copy 'templates/component_test.rb.tt'

            substitute "#{gem_name}.gemspec", /^end/, <<~RUBY.chomp
                # ignore the dummy Rails app when building the gem
                spec.files.reject! { _1.match(/^dummy_app/) }
                spec.add_dependency 'amber_component'
                spec.add_development_dependency 'thor'
              end
            RUBY
          end
        end
      end

      # @return [void]
      def generate_rails_dummy_app
        ::CLI::UI::Frame.open 'Rails dummy app', color: :magenta do
          unless syscall? 'gem list -i rails'
            ::CLI::UI::Frame.open 'Install Rails' do
              syscall('gem install rails')
            end
          end

          ::CLI::UI::Frame.open 'Generate app' do
            syscall "rails new #{root_path / rails_dummy_path} -m #{rails_template_path}",
                    env: { GEM_NAME: gem_name },
                    input: "y\n"
          end

          ::CLI::UI::Frame.open 'Patch app' do
            append rails_dummy_path / 'Gemfile', template_content('rails_dummy/Gemfile.erb')
          end
        end
      end

      # Performs a shell command with a PTY,
      # captures its output and logs it to this process's STDOUT.
      #
      # @param command [String]
      # @param env [Hash{Symbol => String}] Environment variables
      # @param input [String, nil] Input to the process
      # @return [String] STDOUT
      def syscall(command, env: {}, input: nil)
        cmd = ::TTY::Command.new(color: true, printer: :quiet)
        cmd.run!(command, pty: true, input: input, env: env)
      end

      # Performs a quiet shell command (without logging to STDOUT)
      # and returns the process's exit status as a `Boolean`.
      #
      # @param command [String]
      # @param env [Hash{Symbol => String}] Environment variables
      # @param input [String, nil] Input to the process
      # @return [Boolean] whether the command was successful
      def syscall?(command, env: {}, input: nil)
        cmd = ::TTY::Command.new(printer: :null)
        !cmd.run!(command, input: input, env: env).failure?
      end

      # Parse a template file from this gem using ERB and
      # and copy it to the newly generated gem.
      #
      # @param template_path [String, Pathname]
      # @param target_path [String, Pathname]
      # @return [void]
      def template(template_path, target_path)
        create target_path, template_content(template_path)
      end

      # Copy a file from this gem's template folder to
      # the newly generated gem.
      #
      # @param source_path [String, Pathname]
      # @param target_path [String, Pathname]
      # @return [void]
      def copy(source_path, target_path = source_path, recursive: false)
        source = TEMPLATES_FOLDER_PATH / source_path
        target = root_path / target_path
        return ::FileUtils.cp_r source, target if recursive

        ::FileUtils.cp source, target
      end

      # Move a file inside the generated gem.
      #
      # @param source_path [String, Pathname]
      # @param target_path [String, Pathname]
      # @return [void]
      def move(source_path, target_path)
        source = root_path / source_path
        target = root_path / target_path
        ::FileUtils.move source, target
      end

      # Read and parse a template with ERB and
      # return the result as a `String`.
      #
      # @param path [String, Pathname]
      # @return [String] Parsed content of the template
      def template_content(path)
        template_path = TEMPLATES_FOLDER_PATH / path
        ::ERB.new(template_path.read).result(binding)
      end

      # Make a file in the newly generated gem executable.
      #
      # @param path [String, Pathname]
      # @return [void]
      def make_executable(path)
        ::FileUtils.chmod 'ugo+x', root_path / path
      end

      # Relative path to the main entry file of the generated gem.
      #
      # @return [Pathname]
      def gem_entry_file_path
        gem_entry_folder_path.sub_ext('.rb')
      end

      # Relative path to the main folder of the generated gem.
      #
      # @return [Pathname]
      def gem_entry_folder_path
        ::Pathname.new('lib') / gem_name.gsub('-', '/')
      end

      # Relative path to the test folder of the generated gem.
      #
      # @return [Pathname]
      def gem_test_folder_path
        ::Pathname.new('test') / gem_name.gsub('-', '/')
      end

      # Name of the generated gem.
      #
      # @return [String]
      def gem_name
        root_path.basename.to_s
      end

      # @return [Pathname]
      def rails_dummy_path
        ::Pathname.new 'dummy_app'
      end

      # Path to the root folder of the generated gem.
      #
      # @return [Pathname]
      def root_path
        @args.gem_path
      end

      # @return [Pathname]
      def rails_template_path
        ROOT_GEM_PATH / 'lib' / 'dummy_rails_app_template.rb'
      end

      # Create a directory in the generated gem
      # if it doesn't exist already.
      #
      # @param path [String, Pathname]
      # @return [void]
      def make_dir(path)
        dir_path = root_path / path
        ::FileUtils.mkdir dir_path unless ::Dir.exist? dir_path
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

      # Substitute a part of a certain file in the generated gem.
      #
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

      # Prepend some content to a file in the generated gem.
      #
      # @param file_path [String, Pathname]
      # @param content [String]
      # @return [void]
      def prepend(file_path, content)
        print "  prepend     ".yellow
        puts file_path

        # @type [Pathname]
        path = root_path / file_path
        current_content = ::File.read path
        ::File.open(path, 'w') do |f|
          f.write(content)
          f.write(current_content)
        end
      end

      # Append some content to a file in the generated gem.
      #
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

      # Name of the root module of the generated gem.
      #
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
