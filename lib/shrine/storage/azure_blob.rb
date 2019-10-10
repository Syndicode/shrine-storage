# frozen_string_literal: true

require 'shrine'
require 'azure/storage/blob'
require 'content_disposition'

require 'uri'
require 'cgi'
require 'tempfile'

class Shrine
  module Storage
    class AzureBlob
      attr_reader :client, :account_name, :access_key, :container_name, :multipart_threshold

      def initialize(
        account_name: nil, access_key: nil,
        container_name: nil, multipart_threshold: {}
      )
        @access_key = access_key
        @account_name = account_name
        @container_name = container_name
        @multipart_threshold = multipart_threshold
      end

      def upload(io, id, shrine_metadata: {}, **_upload_options)
        content_type, filename = shrine_metadata.values_at('mime_type', 'filename')
        options = {}
        options[:content_type] = content_type if content_type
        options[:content_disposition] = ContentDisposition.inline(filename) if filename

        put(io, id, **options)
      end

      def extract_path(io)
        if io.respond_to?(:path)
          io.path
        elsif io.is_a?(UploadedFile) &&
              defined?(Storage::FileSystem) &&
              io.storage.is_a?(Storage::FileSystem)
          io.storage.path(io.id).to_s
        end
      end

      def open(id, _rewindable: false, **_options)
        GC.start

        client = Azure::Storage::Blob::BlobService.create(
          storage_account_name: account_name,
          storage_access_key: access_key
        )

        _blob, content = client.get_blob(container_name, id)
        StringIO.new(content)
      end

      def put(io, id, **_options)
        client = Azure::Storage::Blob::BlobService.create(
          storage_account_name: account_name,
          storage_access_key: access_key
        )
        if (path = extract_path(io))
          ::File.open(path, 'rb') do |file|
            client.create_block_blob(container_name, id, file.read, timeout: 30)
          end
        else
          client.create_block_blob(container_name, id, io.to_io)
        end
      end

      def delete(id)
        client = Azure::Storage::Blob::BlobService.create(
          storage_account_name: account_name,
          storage_access_key: access_key
        )
        client.delete_blob(container_name, id)
      end

      def url(id, **options)
        client = Azure::Storage::Blob::BlobService.create(
          storage_account_name: account_name,
          storage_access_key: access_key
        )
        uri = client.generate_uri("#{container_name}/#{id}")
        if options[:scheme] == 'http'
          uri.to_s.gsub('https:', 'http:')
        else
          uri.to_s
        end
      end

      class Tempfile < ::Tempfile
        attr_accessor :content_type
      end
    end
  end
end
