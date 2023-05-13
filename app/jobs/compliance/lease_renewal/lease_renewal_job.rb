module Compliance
  class LeaseRenewalJob < ApplicationJob
    queue_as :default
    
    def perform(lease_ids: nil)
      next if Rails.env != "production" && lease_ids.nil?
      today = Time.current.to_date
      renewal_dates = [today + 30.days, today + 15.days, today + 5.days]
      lease_ids ||= ::Lease.where(renewal_date: renewal_dates)
        .or(::Lease.where(renewal_date: nil, end_date: renewal_dates.map{|x| x - 1.day }))
        .or(::Lease.where("renewal_date < ?", today).where(end_date: renewal_dates.map{|x| x - 1.day }))
        .where(
          account_id: 45,
          status: 'current'
        )
        .where.not(
          external_status: 'Notice'
        )
        .pluck(:id) # if there are jillions, doing it this way saves RAM at the expense of extra DB queries
      lease_ids.each do |lease_id|
        lease = ::Lease.where(id: lease_id).take
        next if lease.nil?
        next if lease.primary_user.nil? || lease.primary_user.contact_email.blank? || lease.primary_user.contact_email.index("@").nil?
        begin
          Compliance::LeaseRenewalMailer.with(lease: lease)
                                        .reminder
                                        .deliver_now
        rescue Exception => e
          message = "Unable to generate lease renewal email for lease id: #{ lease_id }\n\n"
          message += "#{ e.to_json }\n\n"
          message += e.backtrace.join("\n")
          from = Rails.env == "production" ? "no-reply-#{ Rails.env.gsub('_','-') }@getcovered.io" : 'no-reply@getcovered.io'
          ActionMailer::Base.mail(from: from,
                                  to: 'dev@getcovered.io',
                                  subject: "[Get Covered] Lease Renewal Email Error",
                                  body: message).deliver_now
        end
      end
    end

  end
end
