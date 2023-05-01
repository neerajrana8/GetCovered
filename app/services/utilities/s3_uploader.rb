module Utilities
  # S3Uploader Service
  class S3Uploader < ApplicationService

    attr_accessor :document
    attr_accessor :document_title
    attr_accessor :save_path
    attr_accessor :bucket

    def initialize(document, document_title, save_path, bucket)
      @document = document
      @document_title = document_title
      @save_path = save_path.sub!(/\//, '').chomp('/')
      @bucket = bucket.nil? ? Rails.env == 'production' ? 'gc-public-prod' : 'gc-public-dev' : bucket
    end

    def call
      upload()
      return build_public_url()
    end

    private

    def s3_credentials
      ::Aws::Credentials.new(Rails.application.credentials.aws[Rails.env.to_sym][:access_key_id],
                             Rails.application.credentials.aws[Rails.env.to_sym][:secret_access_key])
    end

    def s3
      ::Aws::S3::Client.new(region: Rails.application.credentials.aws[Rails.env.to_sym][:region],
                            credentials: s3_credentials())
    end

    def upload
      File.open(@document.path, 'rb') do |file|
        s3().put_object(bucket: @bucket, acl: 'public-read', key: "#{ @save_path }/#{ @document_title }", body: file)
      end
    end

    def build_public_url
      url_array = ['https://', @bucket, '.s3.', Rails.application.credentials.aws[Rails.env.to_sym][:region],
                   '.amazonaws.com/', @save_path, '/', @document_title]
      @public_url = url_array.join('')
    end
  end
end