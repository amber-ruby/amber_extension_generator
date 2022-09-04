# frozen_string_literal: true

require_relative 'lib/amber_extension_generator/version'

::Gem::Specification.new do |spec|
  spec.name = 'amber_extension_generator'
  spec.version = ::AmberExtensionGenerator::VERSION
  spec.authors = ['Ruby-Amber', 'Mateusz Drewniak', 'Garbus Beach']
  spec.email = ['matmg24@gmail.com', 'piotr.garbus.garbicz@gmail.com']

  spec.summary = 'A utility for generating new extensions or component libraries which hook into `amber_component`'
  spec.description = <<~DESC
    A utility for generating new extensions or component libraries which hook into `amber_component`.
    Create your own themes!
  DESC
  spec.homepage = 'https://github.com/amber-ruby/amber_extension_generator'
  spec.license = 'MIT'
  spec.required_ruby_version = ">= 2.7.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = ::Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = 'exe'
  spec.executables = %w[amber_extension_generator]
  spec.require_paths = %w[lib]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency 'cli-ui', '~> 1'
  spec.add_dependency 'rainbow', '>= 3.0'
  spec.add_dependency 'tty-command', '~> 0'

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
