module Leads
  class RecentLeadsReportJob < ApplicationJob
    queue_as :default

    def perform(leads_ids, filters, user_email)
      leads = Lead.where(id: leads_ids)
      csv = leads.to_csv(filters.deep_symbolize_keys)
      return if csv.nil?

      RecentLeadsReportMailer.with(csv: csv, user_email: user_email, file_name: file_name).recent_leads.deliver
    end

    private

    def file_name
      "recent-leads-#{Date.today}.csv"
    end

    def file_upload
      #s3 = Aws::S3::Resource.new(region: 'us-west-2')
      #obj = s3.bucket('bucket-name').object(file_name)
      # string data
      #obj.put(body: 'Test File')
      # IO object
      #File.open('source', 'rb') do |file|
      #  obj.put(body: file)
      #end
    end

  end
end
