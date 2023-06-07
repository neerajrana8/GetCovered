module CarrierQBE
  class DuplicatePoliciesMailer < ApplicationMailer

    def notify(report_url, report_name)
      attachments[report_name] = {
        mime_type: "text/csv",
        content: URI.open(report_url)
      }
      mail(subject: 'Failed records from QBE',
           to: "dylan@getcovered.io",
           subject: report_name.gsub('-', ' ').gsub('.', ' ').titlecase,
           body: "Duplicate Policy Report for #{ DateTime.current.strftime('%A, %B %e, %Y') }")
    end

  end
end
