module Compliance
  module Audit
    class FinalContactJob < ApplicationJob
      include Compliance::Audit::Concerns::LeasesEmailsMethods

      queue_as :default

      before_perform do |job|
        puts "in before"
        date = Time.current.to_date
        created_at_search_range = (DateTime.new(1900,1,1)..(date - 4.days).at_beginning_of_day)
        start_date_search_range = (date..)

        find_leases(created_at_search_range, start_date_search_range)
      end

      before_perform :test_arg

      def perform(*)
        puts "in perform"
        unless @leases.nil?
          @leases.each do |lease|
            days = (Time.current.to_date - lease.created_at.to_date).to_i
            if days % 2 == 0
              begin
                Compliance::AuditMailer.with(organization: lease.account)
                .intro(user: lease.primary_user(),
                unit: lease.insurable,
                lease_start_date: lease.start_date,
                follow_up: 2).deliver_now()
              rescue Exception => e
                message = "Unable to generate final contact email for lease id: #{ lease.id }\n\n"
                message += "#{ e.to_json }\n\n"
                message += e.backtrace.join("\n")
                from = Rails.env == "production" ? "no-reply-#{ Rails.env.gsub('_','-') }@getcovered.io" : 'no-reply@getcovered.io'
                ActionMailer::Base.mail(from: from,
                                        to: 'dev@getcovered.io',
                                        subject: "[Get Covered] Final Audit Email Error",
                                        body: message).deliver_now()
              end
            end
          end
        end
      end

      def test_arg
        puts "heeereeeee"
      end

    end
  end
end
