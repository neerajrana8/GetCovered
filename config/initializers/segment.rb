require 'segment/analytics'

Analytics = Segment::Analytics.new({
    write_key: "#{ Rails.application.credentials.segment[ENV["RAILS_ENV"].to_sym][:write_key] }",
    on_error: Proc.new { |status, msg| print msg }
})
