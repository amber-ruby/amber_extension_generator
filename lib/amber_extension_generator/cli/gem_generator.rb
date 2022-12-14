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
    class GemGenerator # rubocop:disable Metrics/ClassLength
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
            syscall "bundle gem #{root_path} --linter=rubocop --ci=github --test=minitest", input: "y\n"
          end

          ::CLI::UI::Frame.open 'Patch gem' do
            template 'components/base_component.rb.erb', gem_entry_folder_path / 'components' / 'base_component.rb'

            copy 'lib/components.rb', gem_entry_folder_path / 'components.rb'
            template 'lib/railtie.rb.erb', gem_entry_folder_path / 'railtie.rb'

            substitute gem_entry_file_path, /^end/, <<~RUBY.chomp
              end

              require 'pathname'
              require_relative '#{gem_entry_folder_path.basename}/railtie' if defined?(::Rails::Railtie)
              require_relative '#{gem_entry_folder_path.basename}/components'

              # Override this if you want to have a different name for the
              # base component of your gem
              #{root_module_name}::ABSTRACT_COMPONENT = #{root_module_name}::BaseComponent
              #{root_module_name}::ROOT_PATH = ::Pathname.new ::File.expand_path('#{relative_path_to_root}', __dir__)
            RUBY

            template 'lib/generators/install_generator.rb.erb',
                     ::Pathname.new('lib') / 'generators' / gem_name_path / 'install_generator.rb'

            template '.rubocop.yml.erb', '.rubocop.yml'
            template 'README.md.erb', 'README.md'
            copy 'amber_banner.png'

            generate_scripts
            generate_assets
            copy_templates
            patch_gemspec
            configure_tests
          end
        end
      end

      # @return [void]
      def generate_scripts
        template 'bin/generate.erb', 'bin/generate'
        template 'bin/dev.erb', 'bin/dev'
        template 'bin/setup.erb', 'bin/setup'
        make_executable 'bin/generate'
        make_executable 'bin/dev'
        make_executable 'bin/setup'
      end

      # @return [void]
      def generate_assets
        make_dir 'assets/stylesheets'
        template 'assets/stylesheets/main.scss.erb', main_stylesheet_path
        copy 'assets/stylesheets/components.scss', stylesheet_dir_path / 'components.scss'
      end

      # @return [void]
      def copy_templates
        make_dir 'templates'
        copy 'templates/component.rb.tt'
        copy 'templates/style.scss.tt'
        copy 'templates/view.html.erb.tt'
        copy 'templates/component_test.rb.tt'
      end

      # @return [void]
      def patch_gemspec
        substitute "#{gem_name}.gemspec", /^end/, <<~RUBY.chomp
            # ignore the dummy Rails app when building the gem
            spec.files.reject! { _1.match(/^#{rails_dummy_path}/) }
            spec.add_dependency 'amber_component', '#{amber_component_version}'
            spec.add_development_dependency 'thor'
            spec.add_development_dependency 'sassc'
            spec.add_development_dependency 'capybara'
          end
        RUBY
      end

      # @return [void]
      def configure_tests
        copy 'test/component_test_case.rb'
        substitute 'Rakefile', /test_\*\.rb/, '*_test.rb'
        inner_module_name = gem_name.split('-').last
        move gem_test_folder_path.parent / "test_#{inner_module_name}.rb",
             gem_test_folder_path.parent / "#{inner_module_name}_test.rb"

        append 'test/test_helper.rb',
               "require_relative 'component_test_case'\n"
      end

      # @return [void]
      def generate_rails_dummy_app # rubocop:disable Metrics/MethodLength
        ::CLI::UI::Frame.open 'Rails dummy app', color: :magenta do # rubocop:disable Metrics/BlockLength
          unless syscall? 'gem list -i rails'
            ::CLI::UI::Frame.open 'Install Rails' do
              syscall 'gem install rails'
              syscall 'gem install sqlite3'
            end
          end

          ::CLI::UI::Frame.open 'Generate app' do
            syscall "rails new #{root_path / rails_dummy_path} -m #{rails_template_path}",
                    env: { GEM_NAME: gem_name },
                    input: "y\n"
          end

          ::CLI::UI::Frame.open 'Patch app' do
            append rails_dummy_path / 'Gemfile', template_content('rails_dummy/Gemfile.erb')

            if exist?(rails_dummy_path / 'app' / 'assets' / 'stylesheets' / 'application.css')
              move rails_dummy_path / 'app' / 'assets' / 'stylesheets' / 'application.css',
                   rails_dummy_path / 'app' / 'assets' / 'stylesheets' / 'application.scss'

              append rails_dummy_path / 'app' / 'assets' / 'stylesheets' / 'application.scss', <<~SCSS
                @import "#{gem_name_path}";
              SCSS
            elsif exist?(rails_dummy_path / 'app' / 'assets' / 'stylesheets' / 'application.scss')
              append rails_dummy_path / 'app' / 'assets' / 'stylesheets' / 'application.scss', <<~SCSS
                @import "#{gem_name_path}";
              SCSS
            else
              append rails_dummy_path / 'app' / 'assets' / 'stylesheets' / 'application.sass.scss', <<~SCSS
                @import "#{gem_name_path}";
              SCSS
            end
          end
        end
      end

      # @return [String]
      def relative_path_to_root
        (['..'] * root_module_name.split('::').length).join('/')
      end

      # @return [String]
      def amber_component_version
        version_ary = VERSION.split '.'
        version_ary.pop

        "~> #{version_ary.join('.')}"
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
        ::Pathname.new('lib') / gem_name_path
      end

      # Relative path to the test folder of the generated gem.
      #
      # @return [Pathname]
      def gem_test_folder_path
        ::Pathname.new('test') / gem_name_path
      end

      # @return [Pathname]
      def gem_name_path
        @gem_name_path ||= ::Pathname.new gem_name.gsub('-', '/')
      end

      # @return [String]
      def gem_name_rake
        gem_name.gsub('-', ':')
      end

      # Name of the generated gem.
      #
      # @return [String]
      def gem_name
        @gem_name ||= root_path.basename.to_s
      end

      # Name of the root module of the generated gem.
      #
      # @return [String]
      def root_module_name
        @root_module_name ||= camelize(gem_name_path)
      end

      # Relative path to the stylesheet directory of the generated gem.
      #
      # @return [Pathname]
      def stylesheet_dir_path
        ::Pathname.new('assets') / 'stylesheets' / gem_name_path
      end

      # Relative path to the main stylesheet file of the generated gem.
      #
      # @return [Pathname]
      def main_stylesheet_path
        stylesheet_dir_path.sub_ext '.scss'
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

      # Path to the Rails template used to generate
      # the dummy development app in the generated gem.
      #
      # @return [Pathname]
      def rails_template_path
        ROOT_GEM_PATH / 'lib' / 'dummy_rails_app_template.rb'
      end

      # Check whether the given file/directory exists
      # in the generated gem.
      #
      # @param path [String, Pathname]
      # @return [Boolean]
      def exist?(path)
        (root_path / path).exist?
      end

      # Create a directory in the generated gem
      # if it doesn't exist already.
      #
      # @param path [String, Pathname]
      # @return [void]
      def make_dir(path)
        dir_path = root_path / path
        ::FileUtils.mkdir_p dir_path unless dir_path.exist?
      end
      alias mkdir make_dir

      # @param string [String, Symbol]
      # @return [String]
      def action_message(string)
        "#{string.to_s.rjust(12, ' ')}  "
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
        print action_message(__method__).green
        puts target_path

        source = TEMPLATES_FOLDER_PATH / source_path
        target = root_path / target_path
        ::FileUtils.mkdir_p(target.dirname) unless target.dirname.directory?
        return ::FileUtils.cp_r source, target if recursive

        ::FileUtils.cp source, target
      end

      # Move a file inside the generated gem.
      #
      # @param source_path [String, Pathname]
      # @param target_path [String, Pathname]
      # @return [void]
      def move(source_path, target_path)
        print action_message(__method__).yellow
        puts "#{source_path} -> #{target_path}"

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

      # Create a new file with the specified content
      # in the newly generated gem.
      #
      # @param file_path [String, Pathname]
      # @param content [String]
      def create(file_path, content)
        print action_message(__method__).green
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
        print action_message(:gsub).yellow
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
        print action_message(__method__).yellow
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
        print action_message(__method__).yellow
        puts file_path

        # @type [Pathname]
        path = root_path / file_path
        ::File.open(path, 'a') { _1.write(content) }
      end

      # @param string [String]
      # @param uppercase_first_letter [Boolean]
      # @return [String]
      def camelize(string, uppercase_first_letter: true)
        string = string.to_s
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
