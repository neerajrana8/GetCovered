module Utilities
  # PdfGenerator Service
  class PdfGenerator < ApplicationService
    require 'fileutils'

    attr_accessor :template_path
    attr_accessor :locales
    attr_accessor :save_path
    attr_accessor :file_name

    def initialize(template_path, locales, file_name, save_path)
      @template_path = template_path
      @locales = locales
      @file_name = file_name
      @save_dir_array = save_path.sub!(/\//, '').chomp('/').split('/')
      @save_path = Rails.root.join(save_path, @file_name)
    end

    def call
      pdf = generate_pdf()
      save_file(pdf)
      return File.open(@save_path)
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
      @save_dir_array.length.times do |i|
        dir = Rails.root.join(@save_dir_array.take(i + 1).join('/'))
        unless File.directory?(dir)
          FileUtils.mkdir(dir, mode: 0777)
        end
      end
    end
  end
end
