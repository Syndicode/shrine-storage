# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'shrine/storage/version'

Gem::Specification.new do |spec|
  spec.name          = 'shrine-storage'
  spec.version       = Shrine::Storage::VERSION
  spec.authors       = ['Dmitriy Bielorusov', 'Syndicode LLC']
  spec.email         = ['d.belorusov@gmail.com', 'info@syndicode.com']

  spec.summary       = 'Extend existing shrine gem with using official azure-storage-blob SDK'
  spec.description   = 'Extend existing shrine gem with using official azure-storage-blob SDK'
  spec.homepage      = 'https://github.com/anerhan/shrine-storage.git'
  spec.license       = 'MIT'

  if spec.respond_to?(:metadata)
    # spec.metadata['allowed_push_host'] = ''

    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/anerhan/azure-storage.git'
    spec.metadata['changelog_uri'] = 'https://github.com/anerhan/azure-storage.git'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
  #   `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  # end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.0.2'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rubocop'

  spec.add_dependency 'azure-storage-blob', '~> 1.1.0'
end
