require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module AppealsTracker
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # The google-genai gem registers its own Zeitwerk loader (tag: "genai") with
    # root at lib/google. During Rails production eager loading, Zeitwerk::Loader
    # .eager_load_all fires and that loader tries to resolve Google::Genai from
    # the directory — which fails. We do NOT want Zeitwerk to eager-load the gem's
    # internals at all (we already require it in boot.rb), so we tell the loader
    # to skip all its dirs during eager loading. This runs at class-load time,
    # before any initializer or eager_load! fires.
    ObjectSpace.each_object(Zeitwerk::Loader) do |loader|
      next unless loader.tag == "genai"
      loader.dirs.each { |dir| loader.do_not_eager_load(dir) }
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
