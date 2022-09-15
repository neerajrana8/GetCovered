module Compliance
  module Audit
    class FollowUpContactJob < ApplicationJob
      queue_as :default
      before_perform :find_leases

      def perform(*)
        unless @leases.nil?
          @leases.each do |lease|
            begin
              Compliance::AuditMailer.with(organization: lease.account)
                                     .intro(user: lease.primary_user(),
                                            unit: lease.insurable,
                                            lease_start_date: lease.start_date,
                                            follow_up: 1).deliver_now()
            rescue Exception => e
              message = "Unable to generate follow up contact email for lease id: #{ lease.id }\n\n"
              message += "#{ e.to_json }\n\n"
              message += e.backtrace.join("\n")
              from = Rails.env == "production" ? "no-reply-#{ Rails.env.gsub('_','-') }@getcovered.io" : 'no-reply@getcovered.io'
              ActionMailer::Base.mail(from: from,
                                      to: 'dev@getcovered.io',
                                      subject: "[Get Covered] Follow Up Audit Email Error",
                                      body: message).deliver_now()
            end
          end
        end
      end

      private
        def find_leases
          @lease_ids = []
          date = Time.current.to_date
          master_policies = Policy.where(policy_type_id: 2, carrier_id: 2)
          master_policies.each do |master|
            master.insurables.communities.each do |community|
              community_lease_ids = Lease.where(insurable_id: community.units.pluck(:id),
                                                created_at: (date - 2.days).at_beginning_of_day..(date - 2.days).at_end_of_day,
                                                start_date: date..(date + 2.weeks),
                                                covered: false).pluck(:id)
              @lease_ids = @lease_ids + community_lease_ids
            end
          end

          @leases = @lease_ids.blank? ? nil : Lease.find(@lease_ids)
        end
    end
  end
end