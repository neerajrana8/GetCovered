module Qbe
  # EoiGenerator Service
  class EoiGenerator < ApplicationService
    require 'fileutils'

    attr_accessor :document_title
    attr_accessor :template_path
    attr_accessor :save_path
    attr_accessor :locales
    attr_accessor :options

    def initialize(document_title, template_path, save_path, locales, options)
      @document_title = document_title
      @template_path = template_path
      @save_dir = "#{ Rails.root }/#{ save_path }"
      @save_path = Rails.root.join(save_path, document_title)
      @locales = locales
      @options = { upload: false, save: false }.merge!(options)
    end

    def call
      pdf = generate_pdf
      save_file(pdf) if options[:save]
      upload_file() if options[:upload]
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
      File.open(@save_path, 'wb') do |file|
        file << pdf
      end
    end

    def create_dir_unless_exists
      unless File.directory?(@save_dir)
        FileUtils.mkdir_p(@save_dir)
      end
    end

    def upload_file
      credentials = ::Aws::Credentials.new(Rails.application.credentials.aws[Rails.env.to_sym][:access_key_id],
                                           Rails.application.credentials.aws[Rails.env.to_sym][:secret_access_key])
      s3 = ::Aws::S3::Client.new(region: Rails.application.credentials.aws[Rails.env.to_sym][:region],
                                 credentials: credentials)
      File.open(@save_path, 'rb') do |file|
        puts "starting to upload #{ @save_path} to S3"
        attempt = s3.put_object(bucket: Rails.application.credentials.aws[Rails.env.to_sym][:bucket],
                                acl: 'public-read', key: @document_title, body: file)
        pp attempt
      end
    end

  end
end