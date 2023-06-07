module Utilities
  class CsvGenerator < ApplicationService
    require 'fileutils'
    require 'csv'

    attr_accessor :file_name
    attr_accessor :save_path
    attr_accessor :data

    def initialize(file_name, save_path, data)
      @file_name = file_name
      @save_dir_array = save_path.sub!(/\//, '').chomp('/').split('/')
      @save_path = Rails.root.join(save_path, @file_name)
      @data = data
    end

    def call
      raise "File Name null" if file_name.nil?
      raise "Data empty" if data.nil?
      raise "Data must be an array" unless data.is_a?(Array)

      create_dir_unless_exists()

      begin
        CSV.open(@save_path, "w") do |csv|
          @data.each do |row|
            csv << row
          end
        end
      rescue Exception => e
        pp e
      end

      return File.read(@save_path)
    end

    private

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