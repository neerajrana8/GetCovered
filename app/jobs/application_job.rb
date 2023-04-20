class ApplicationJob < ActiveJob::Base

  def log(name, str)
    timestamp = DateTime.now.strftime("%F")
    path = Rails.root.join('public', 'reports', name)
    log_file_path = Rails.root.join('public', 'reports', name, "#{timestamp}.txt")

    FileUtils.mkdir_p(path) unless File.directory?(path)
    File.write(log_file_path, "#{str}\n", mode: "a")
  end
end
