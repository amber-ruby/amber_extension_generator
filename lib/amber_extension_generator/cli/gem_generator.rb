# frozen_string_literal: true

require 'fileutils'

require 'rainbow/refinement'
require 'cli/ui'
require 'tty-command'
require 'erb'
require 'debug'

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
            make_executable root_path / 'bin/generate'

            ::FileUtils.mkdir root_path / 'templates'

            copy 'templates/component.rb.tt'
            copy 'templates/style.css.tt'
            copy 'templates/view.html.erb.tt'

            substitute "#{gem_name}.gemspec", /^end/, <<~RUBY.chomp
                # ignore the dummy Rails app when building the gem
                spec.files.reject! { _1.match(/^dummy_app/) }
                spec.add_dependency 'amber_component'
                spec.add_development_dependency 'thor'
              end
            RUBY

            substitute 'Rakefile', %r{test_\*\.rb}, '*_test.rb'
            inner_module_name = gem_name.split('-').last
            move gem_test_folder_path.parent / "test_#{inner_module_name}.rb", gem_test_folder_path.parent / "#{inner_module_name}_test.rb"
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
            append rails_dummy_path / 'Gemfile', template_content('rails_dummy/Gemfile.erb')
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

      # @param template_path [String, Pathname]
      # @param target_path [String, Pathname]
      # @return [void]
      def template(template_path, target_path)
        create target_path, template_content(template_path)
      end

      # @param source_path [String, Pathname]
      # @param target_path [String, Pathname]
      # @return [void]
      def copy(source_path, target_path = source_path, recursive: false)
        source = ROOT_GEM_PATH / 'lib' / 'amber_extension_generator' / 'templates' / source_path
        target = root_path / target_path
        return ::FileUtils.cp_r source, target if recursive

        ::FileUtils.cp source, target
      end

      # @param source_path [String, Pathname]
      # @param target_path [String, Pathname]
      # @return [void]
      def move(source_path, target_path)
        source = root_path / source_path
        target = root_path / target_path
        ::FileUtils.move source, target
      end

      # @param path [String, Pathname]
      # @return [String] Parsed content of the template
      def template_content(path)
        template_path = ROOT_GEM_PATH / 'lib' / 'amber_extension_generator' / 'templates' / path
        ::ERB.new(template_path.read).result(binding)
      end

      # @param path [String, Pathname]
      # @return [void]
      def make_executable(path)
        ::FileUtils.chmod 'ugo+x', path
      end

      # @return [Pathname]
      def gem_entry_file_path
        gem_entry_folder_path.sub_ext('.rb')
      end

      # @return [Pathname]
      def gem_entry_folder_path
        ::Pathname.new('lib') / gem_name.gsub('-', '/')
      end

      # @return [Pathname]
      def gem_test_folder_path
        (::Pathname.new('test') / gem_name.gsub('-', '/'))
      end

      # @return [String]
      def gem_name
        root_path.basename.to_s
      end

      # @return [Pathname]
      def bin_path
        ::Pathname.new 'bin'
      end

      # @return [Pathname]
      def template_path
        ::Pathname.new 'template'
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
