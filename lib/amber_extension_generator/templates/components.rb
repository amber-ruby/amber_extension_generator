# frozen_string_literal: true

require_relative 'components/base_component'
::Dir[::File.expand_path('components/**/*.rb', __dir__)].sort.each { require_relative _1 }
