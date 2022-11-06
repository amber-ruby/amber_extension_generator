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

    # define a file watcher for the extension gem
    extension_gem_reloader = config.file_watcher.new([], reload_paths) do
      puts '    Reloading the extension gem'

      # delete all constants defined by the extension gem
      ::AMBER_EXTENSION_GEM.constants.each do |const|
        # Normalize ::Foo, ::Object::Foo, Object::Foo, Object::Object::Foo, etc. as Foo.
        normalized = const.to_s.delete_prefix('::')
        normalized.sub!(/\A(Object::)+/, '')

        constants = normalized.split('::')
        to_remove = constants.pop
        parent = constants.empty? ? ::Object : ::Object.const_get(constants.join('::'))

        parent.__send__(:remove_const, to_remove)
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
