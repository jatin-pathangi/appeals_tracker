ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "google/genai"  # Must load before Zeitwerk starts (non-standard namespace).
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
