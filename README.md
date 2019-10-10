# Shrine::Storage::AzureBlob
_Provided memory leakless interface for AzureBlob images/files processing within SHRINE_

![Mem leak](https://user-images.githubusercontent.com/1485240/66502907-dc32f380-eace-11e9-89f5-872b0d44b0ee.png)

## Installation

Add this lines to your application's Gemfile:
```ruby
...
gem 'shrine', '~> 2.11'
gem 'azure-storage-blob'
gem 'shrine-redis'
gem 'image_processing', '~> 1.7.1'
gem 'shrine-storage'
gem 'sidekiq'
...
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install shrine-storage

## Usage

- **Create file _config/initilizers/shine.rb_**
```ruby
require 'shrine'
require 'shrine/storage/redis'
require 'shrine/storage/file_system'

if Rails.env.production?
  azure_options = {
    account_name: ENV.fetch('AZURE_ACCOUNT_NAME'),
    access_key: ENV.fetch('AZURE_ACCESS_KEY'),
    container_name: ENV.fetch('AZURE_CONTAINER')
  }

  Shrine.storages = {
    cache: Shrine::Storage::Redis.new(client: Redis.current, expire: 120),
    store: Shrine::Storage::AzureBlob.new(**azure_options)
  }
else
  Shrine.storages = {
    cache: Shrine::Storage::FileSystem.new('public', prefix: 'storage/cache'), # INFO: temporary
    store: Shrine::Storage::FileSystem.new('public', prefix: 'storage') # INFO: permanent
  }
end

# INFO: Best practice default plugins
Shrine.plugin :activerecord
Shrine.plugin :cached_attachment_data # INFO: for forms
Shrine.plugin :restore_cached_data # INFO: re-extract metadata when attaching a cached file
Shrine.plugin :backgrounding
Shrine.plugin :logging, logger: Rails.logger unless Rails.env.test?

# INFO: Using for provide uploading process through Sidekiq async BG jobs
Shrine::Attacher.promote { |data| AttachmentUploadJob.perform_async(data) }
Shrine::Attacher.delete { |data| AttachmentDeleteJob.perform_async(data) }
```

- **Add to _config/application.rb_ uploaders dir**
```ruby
...
config.autoload_paths += %w[
  app/uploaders
  ...
].map { |path| Rails.root.join(path).to_s }
...
```

- **Example of uploader _app/uploaders/image_uploader.rb_**
```ruby
class ImageUploader < Shrine
  MAX_SIZE = 20
  plugin :remote_url, max_size: MAX_SIZE * 1024 * 1024
  plugin :processing # INFO: allows hooking into promoting
  plugin :validation_helpers
  plugin :versions   # INFO: enable Shrine to handle a hash of files
  plugin :remove_invalid # INFO: immediately delete the file if it failed validations

  unless Rails.env.test? # INFO: delete processed && promoted files after uploading
    plugin :delete_raw
    plugin :delete_promoted
  end

  plugin :determine_mime_type, analyzer: lambda { |io, analyzers|
    mime_type = analyzers[:file].call(io)
    mime_type = analyzers[:mime_types].call(io) if mime_type == 'text/plain'
    mime_type
  }

  opts[:type] = 'image'

  Attacher.validate do
    validate_max_size MAX_SIZE * 1024 * 1024, message: "is too large (max is #{MAX_SIZE} MB)"
    validate_mime_type_inclusion %w[image/jpeg image/png image/gif image/bmp]
  end

  process(:store) do |io, _context|
    # INFO: versions = {} # { original: io } - retain original
    versions = { original: io }
    io.download do |original|
      pipeline = ImageProcessing::MiniMagick.source(original)
      versions[:large]  = pipeline.resize_to_limit!(1280, 1280)
      versions[:medium] = pipeline.resize_to_limit!(640, 640)
      versions[:small]  = pipeline.resize_to_limit!(200, 200)
    end
    versions # INFO: return the hash of processed files
  end
end
```

- **Create DB migration (for polymorphic association use)**
```ruby
create_table :attachments, id: :serial, force: :cascade do |t|
  t.json :file_data
  t.string :type
  t.string :file_remote_url
  t.string :attachable_type
  t.bigint :attachable_id
  t.index %i[attachable_type attachable_id]
end
```

- **Create AR models**
```ruby
# INFO: app/models/attachemnt.rb
class Attachment < ApplicationRecord
  include AttachmentUploader::Attachment.new(:file)
  belongs_to :attachable, polymorphic: true, optional: true
end

# INFO: app/models/image.rb
class Image < Attachment
  include ImageUploader::Attachment.new(:file)
end
```

- **Create Sidekiq Jobs**
```ruby
# INFO: app/jobs/attachemnt_upload.rb
class AttachmentUploadJob
  include Sidekiq::Worker
  sidekiq_options queue: :"attachment:upload", retry: 3

  def perform(data)
    ActiveRecord::Base.uncached do
      klass, id = data['record']
      Shrine::Attacher.promote(data)
    end
  end
end

# INFO: app/jobs/attachemnt_delete.rb
class AttachmentDeleteJob
  include Sidekiq::Worker
  sidekiq_options queue: :"attachment:delete", retry: false

  def perform(data)
    klass, id = data['record']
    Shrine::Attacher.delete(data)
  end
end
```

- **Configure Sidekiq**
```ruby
# INFO:config/sidekiq.yml
---
production:
  :concurrency: 1
development:
  :concurrency: 1
:queues:
  - 'catalog:attachment:upload'
  - 'catalog:attachment:delete'

# INFO: config/initializers/redis.rb
  Redis.current = Redis.new(host: 'redis', db: '1', port: 6379)

# INFO: config/initializers/sidekiq.rb
  Sidekiq.configure_server { |config| config.redis =  Redis.current }
  Sidekiq.configure_client { |config| config.redis =  Redis.current }
```

- **Examples of using**
```ruby
  # INFO: app/models/product.rb
  class Product < ApplicationRecord
    has_many :images, as: :attachable, dependent: :destroy
  end
```

- **Additional info:**
```ruby
  [Shrine Docs](https://github.com/shrinerb/shrine/blob/master/README.md)
  [AzureStorageBlob Docs](https://github.com/Azure/azure-storage-ruby/blob/master/blob/README.md)
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/anerhan/shrine-storage. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Shrine::Storage project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/anerhan/shrine-storage/blob/master/CODE_OF_CONDUCT.md).
