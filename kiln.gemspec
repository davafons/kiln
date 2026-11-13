require_relative "lib/kiln/version"

Gem::Specification.new do |spec|
  spec.name        = "kiln"
  spec.version     = Kiln::VERSION
  spec.authors     = [ "David Afonso" ]
  spec.email       = [ "dav@davafons.com" ]
  spec.homepage    = "https://github.com/davafons/kiln"
  spec.summary     = "Fire a Rails app into a static site."
  spec.description = "Kiln renders every GET route of a Rails app through Rack and writes plain files that any static host can serve. Every GET route is accounted for, and a build reports every error at once."
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 4.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*", "LICENSE", "README.md", "CHANGELOG.md"]
  end

  spec.add_dependency "railties", ">= 8.1"
  spec.add_dependency "actionpack", ">= 8.1"
  spec.add_dependency "nokogiri", ">= 1.16"
  spec.add_dependency "zeitwerk", ">= 2.6"
end
