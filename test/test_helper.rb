# frozen_string_literal: true

$LOAD_PATH.unshift ::File.expand_path('../lib', __dir__)
require 'amber_extension_generator'

require 'byebug'
require 'minitest/autorun'
require 'shoulda-context'

class ::TestCase < ::Minitest::Test; end
