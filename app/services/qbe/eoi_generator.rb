module Qbe
  # EoiGenerator Service
  class EoiGenerator < ApplicationService
    require 'fileutils'

    attr_accessor :document_title
    attr_accessor :template_path
    attr_accessor :local_save_path
    attr_accessor :s3_save_path
    attr_accessor :locales
    attr_accessor :options

    def initialize(document_title, template_path, local_save_path, s3_save_path, locales, options)
      @document_title = document_title
      @template_path = template_path
      @local_save_dir = "#{ Rails.root }/#{ local_save_path }"
      @local_save_path = Rails.root.join(local_save_path, document_title)
      @s3_save_path = s3_save_path.sub!(/\//, '').chomp('/')
      @locales = locales
      @options = { upload: false, save: false }.merge!(options)
      @bucket = Rails.env == 'production' ? 'gc-public-prod' : 'gc-public-dev'
    end

    def call
      pdf = generate_pdf
      save_file(pdf) if options[:save]
      upload_file() if options[:save] && options[:upload]
      build_public_url() if options[:save] && options[:upload]
      return options[:save] && options[:upload] ? @public_url : pdf
    end

    private

    def generate_pdf
      WickedPdf.new.pdf_from_string(
        ActionController::Base.new.render_to_string(
          @template_path,
          locals: @locales
        ),
        page_size: 'A4',
        encoding: 'UTF-8',
        disable_smart_shrinking: true
      )
    end

    def save_file(pdf)
      create_dir_unless_exists
      File.open(@local_save_path, 'wb') do |file|
        file << pdf
      end
    end

    def create_dir_unless_exists
      unless File.directory?(@local_save_dir)
        FileUtils.mkdir_p(@local_save_dir)
      end
    end

    def upload_file
      credentials = ::Aws::Credentials.new(Rails.application.credentials.aws[Rails.env.to_sym][:access_key_id],
                                           Rails.application.credentials.aws[Rails.env.to_sym][:secret_access_key])
      s3 = ::Aws::S3::Client.new(region: Rails.application.credentials.aws[Rails.env.to_sym][:region],
                                 credentials: credentials)

      File.open(@local_save_path, 'rb') do |file|
        s3.put_object(bucket: @bucket, acl: 'public-read', key: "#{ @s3_save_path }/#{ @document_title }", body: file)
      end
    end

    def build_public_url
      url_array = ['https://', @bucket, '.s3.', Rails.application.credentials.aws[Rails.env.to_sym][:region],
                   '.amazonaws.com/', @s3_save_path, '/', @document_title]
      @public_url = url_array.join('')
    end

  end
end