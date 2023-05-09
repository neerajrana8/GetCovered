module Policies
  class ListMailer < ApplicationMailer
    def generate(csv_file, current_staff)
      @current_staff = current_staff
      attachments['policies_list.csv'] = {mime_type: 'text/csv', content: csv_file}

      mail(to: @current_staff.email,
           bcc: 'systememails@getcovered.io',
           subject: 'All Policies List')
    end
  end
end
