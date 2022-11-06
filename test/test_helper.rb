# frozen_string_literal: true

require 'simplecov'
require 'simplecov-cobertura'

::SimpleCov.start do
  add_filter '/test/'
  add_group 'Amber Component', 'lib/'
end

::SimpleCov.formatter = ::SimpleCov::Formatter::MultiFormatter.new([
  ::SimpleCov::Formatter::HTMLFormatter,
  ::SimpleCov::Formatter::CoberturaFormatter
])

$LOAD_PATH.unshift ::File.expand_path('../lib', __dir__)
require 'amber_extension_generator'

require 'debug'
require 'minitest/autorun'
require 'shoulda-context'

class ::TestCase < ::Minitest::Test; end
