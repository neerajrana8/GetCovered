module Compliance
  module Audit
    class FirstContactJob < ApplicationJob
      include Compliance::Audit::Concerns::LeasesEmailsMethods

      queue_as :default
      
      def perform(*)
        date = Time.current.to_date - 1.days
        created_at_search_range = (date.at_beginning_of_day..date.at_end_of_day)
        start_date_search_range = ((date + 2.days)..)

        find_leases(created_at_search_range, start_date_search_range)

        unless @leases.nil?
          @leases.each do |lease|
            begin
              Compliance::AuditMailer.with(organization: lease.account)
                                     .intro(user: lease.primary_user(),
                                            unit: lease.insurable,
                                            lease_start_date: lease.start_date,
                                            follow_up: 0,
                                            lease_sign_date: lease.sign_date).deliver_now()
            rescue Exception => e
              message = "Unable to generate first contact email for lease id: #{ lease.id }\n\n"
              message += "#{ e.to_json }\n\n"
              message += e.backtrace.join("\n")
              from = Rails.env == "production" ? "no-reply-#{ Rails.env.gsub('_','-') }@getcovered.io" : 'no-reply@getcovered.io'
              ActionMailer::Base.mail(from: from,
                                      to: 'dev@getcovered.io',
                                      subject: "[Get Covered] First Audit Email Error",
                                      body: message).deliver_now()
            end
          end
        end
      end

    end
  end
end
