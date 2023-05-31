module Reporting
  class TheMikeJonesMailer < ApplicationMailer

    default to: -> { 'mike.jones@escalon.services' },
            cc: -> { %w(brandon@getcovered.io accounting@getcovered.io) },
            bcc: -> { 'dylan@getcovered.io' },
            from: -> { 'no-reply@getcoveredinsurance.com' }

    def monthly_visitor(files)
      unless files.blank? || files.nil?
        files.each do |file|
          attachments[file[:name]] = file[:data]
        end
      end

      mail(
        :subject => "Get Covered Commission Reporting",
        :body => "THE MIKE JONES REPORT"
      )
    end

  end
end
