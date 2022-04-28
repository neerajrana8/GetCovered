module Compliance
  module Policies
    class MasterCoverageSweepJob < ApplicationJob
      queue_as :default
      before_perform :set_master_policies

      def perform(lease_start_date = Time.current)
        @master_policies.each do |master|
          master.insurables.each do |community|
            config = master.find_closest_master_policy_configuration(community)
            unless config.nil?
              leases = Lease.includes(:insurable, :users)
                            .where(status: 'current',
                                   start_date: lease_start_date + config.grace_period.days,
                                   insurable_id: community.units.pluck(:id),
                                   covered: false)
              process_leases(master: master, leases: leases)
            else
              notify_of_issue(master: master, account: master.account, issue: :no_config)
            end
          end
        end
      end

      private
      def set_master_policies
        @master_policies = Policy.includes(:insurables)
                                 .where(carrier_id: 2,
                                        policy_type_id: 2,
                                        status: "BOUND")
      end

      def process_leases(master: , leases: )
        unless leases.blank?
          leases.each do |lease|
            begin
              master.qbe_specialty_issue_coverage(lease.insurable, lease.users, lease.start_date, true, primary_user: lease.primary_user)
            rescue Exception => e
              notify_of_issue(master: master, account: master.account, issue: :coverage_failure, error: e)
            end
          end
        else
          notify_of_issue(master: master, account: master.account, issue: :no_leases)
        end
      end

      def notify_of_issue(master: , account: , issue: , error: nil)
        if issue == :no_units
          message = "This is a friendly warning to inform you that something might be horribly wrong with "
          message += "master policy ##{ master.number } for #{ account.title }.  A cursory glance has revealed "
          message += "that this policy has no units covered under it.  If this is an error, cower and pray to "
          message += "whatever gods you believe will save you."

          subject = "[Get Covered] Master Policy ##{ master.number } missing units"
        elsif issue == :no_config
          message = "This is a friendly warning to inform you that something might be horribly wrong with "
          message += "master policy ##{ master.number } for #{ account.title }.  A cursory glance has revealed "
          message += "that this policy has no identifiable configuration.  If this is an error, cower and pray to "
          message += "whatever gods you believe will save you."

          subject = "[Get Covered] Master Policy ##{ master.number } missing configuration"
        elsif issue == :no_leases
          message = "This is a less scary warning.  This is just to make sure we know that master policy ##{ master.number } "
          message += "Maybe this is an for #{ account.title } had no leases that met the conditions laid out in the background "
          message += "task today.  issue, maybe it isn't.  That is up to you.  I'm just making sure you know."

          subject = "[Get Covered] Master Policy ##{ master.number } had no matching leases"
        elsif issue == :coverage_failure
          message = "FOR THE LOVE OF ALL THAT IS HOLY, THE END IS HERE!\n"
          message += "There was a fatal flaw issuing coverage from ##{ master.number } for account #{ account.title }.\n\n"
          message += "#{ error.to_json }\n"
          message += e.backtrace.join("\n")

          subject = "[Get Covered] Master Policy ##{ master.number } failed to issue coverage"
        end

        from = Rails.env == "production" ? "no-reply-#{ Rails.env.gsub('_','-') }@getcovered.io" : 'no-reply@getcovered.io'

        if [:no_units, :no_config, :no_leases, :coverage_failure].include?(issue)
          ActionMailer::Base.mail(from: from,
                                  to: 'dev@getcovered.io',
                                  subject: subject,
                                  body: message).deliver_now()
        end
      end
    end
  end
end