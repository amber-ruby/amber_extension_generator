# frozen_string_literal: true

generate :controller, 'test', 'index'
route "root to: 'test#index'"

environment <<~RUBY, env: :development
  # === GEM AUTO-RELOADING ===

  if defined?(::AMBER_EXTENSION_GEM)
    # create the file watcher paths hash for the extension gem
    reload_paths = {}
    dir = ::AMBER_EXTENSION_GEM.path.to_s
    reload_paths[dir] = ['rb']
    ::ActiveSupport::Dependencies.explicitly_unloadable_constants.concat ::AMBER_EXTENSION_GEM.constants

    # define a file watcher for the extension gem
    extension_gem_reloader = config.file_watcher.new([], reload_paths) do
      puts '    Reloading the extension gem'

      # delete all constants defined by the extension gem
      ::ActiveSupport::Dependencies.explicitly_unloadable_constants.each do |const|
        ::ActiveSupport::Dependencies.remove_constant const
      end

      # remove extension gems' files from the global
      # list of already required files
      $LOADED_FEATURES.reject! { _1.start_with?(::AMBER_EXTENSION_GEM.path) }

      # require this gem once again
      require ::AMBER_EXTENSION_GEM.require_path
    end

    ::Rails.application.reloaders << extension_gem_reloader

    first_reload = true
    config.to_prepare do
      puts '    Reloading app code'

      if first_reload
        first_reload = false
        next extension_gem_reloader.execute
      end

      extension_gem_reloader.execute_if_updated
    end
  end

  # === END GEM AUTO-RELOADING ===

RUBY
