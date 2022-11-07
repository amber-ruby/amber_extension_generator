[![license](https://img.shields.io/badge/License-MIT-purple.svg)](LICENSE)
[![CI badge](https://github.com/amber-ruby/amber_extension_generator/actions/workflows/ci_ruby.yml/badge.svg)](https://github.com/amber-ruby/amber_extension_generator/actions/workflows/ci_ruby.yml)
[![Coverage Badge](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/Verseth/82fd98743c74c8c36a9b04c9e325755e/raw/197794be336cde2bdaa3bccec99ebfc4660a3186/amber_extension_generator__heads_main.json)](https://github.com/amber-ruby/amber_extension_generator/actions/workflows/ci_ruby.yml)

<img src="banner.png" width="500px" style="margin-bottom: 2rem;"/>

# AmberExtensionGenerator

This library serves as a generator of [amber_component](https://github.com/amber-ruby/amber_component) component packs or extensions.

## Installation

```sh
$ gem install amber_extension_generator
```

## Usage

You can generate a new component pack like so

```sh
$ amber_extension_generator my_library_name
```

This will create a new gem in `my_library_name` named `my_library_name`.
It has all the information on how to use it and develop it in its `README.md`.

It is generated with a dummy Rails app configured to hot-reload the gem.
This makes it possible to incredibly easy test your components in practice.

There is a custom test suite which makes it extremely easy to unit test components
by querying the generated HTML with special assertions.

More details can be found at [amber_component](https://github.com/amber-ruby/amber_component).

## Development

### Setup

To setup this gem for development you should run the setup script.
This should install all dependencies and make the gem ready.

```sh
$ bin/setup
```

### Console

To make development and experimenting easier there is a script
that lets you access an IRB with this entire gem preloaded.

```sh
$ bin/console
```

### Tests

You can run all tests like this.

```sh
$ bundle exec rake test
```

### Release

To release a new version, update the version number in `version.rb`, and then run

```sh
$ bundle exec rake release
```

This will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

### Local installation

To install this gem onto your local machine, run

```sh
$ bundle exec rake install
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/amber-ruby/amber_extension_generator.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Acknowledgement

This component pack generator is powered by [amber_component](https://github.com/amber-ruby/amber_component).

[<img src="banner.png" width="200px" style="margin-bottom: 2rem;"/>](https://github.com/amber-ruby/amber_component)
