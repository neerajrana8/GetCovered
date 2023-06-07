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

    def initialize(document_title, template_path, local_save_path, s3_save_path, locales)
      @document_title = document_title
      @template_path = template_path
      @local_save_path = "#{ Rails.root }/#{ local_save_path }"
      @s3_save_path = s3_save_path
      @locales = locales
      @bucket = Rails.env == 'production' ? 'gc-public-prod' : 'gc-public-dev'
    end

    def call
      pdf = Utilities::PdfGenerator.call(@template_path, @locales, @document_title, @local_save_path)
      upload = Utilities::S3Uploader.call(pdf, @document_title, @s3_save_path, nil)
      return upload
    end
  end
end