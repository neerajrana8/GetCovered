
require 'csv'

class UnmatchedUserEmailJob < ApplicationJob
  queue_as :default

  def perform(force_test = false)
    to_ignore = [38949,144027,46064,46963,38015,60618,129427,124098,53188,147449,124107,144608,145851,137354] # PU ids to ignore; hard-coded for now, will upgrade to use DB

    account = Account.find(33) #lcor
    integration = account.integrations.where(provider: 'yardi').take
    filename = "unmatched-#{account.slug}-#{Time.current.to_date.to_s}.csv"
    were_there_any = false

    pipnil = []

    polids = Policy.where(
      id: PolicyInsurable.where(primary: true, insurable: account.insurables).select(:policy_id),
      policy_type_id: 1,
      status: Policy.active_statuses
    ).pluck(:id)
    CSV.open(Rails.root.join("tmp", filename), "w") do |csv|
      csv << [
        "Resident Codes",
        "Property",
        "Unit",
        "Policy",
        "Effective",
        "Expiration",
        #"User Type",
        "Email",
        "First Name",
        "Last Name",
        "(GC Policy ID)",
        "(GC Unit ID)",
        "(GC PolicyUser ID)"
      ]
      polids.each do |polid|
      
        # gather important info
        policy = Policy.find(polid)
        next if policy.primary_insurable.nil? || policy.primary_user.nil?
        pip = policy.integration_profiles.where(integration: integration).take
        if pip.nil?
          if policy.created_at >= Time.current.to_date.beginning_of_day
            next
          end
        elsif !pip.configuration['policy_id'].blank?
          next # leave if we haven't tried to export yet or if we have succeeded in exporting
        end
        leases = policy.primary_insurable.leases.where(account: account)
        next if leases.blank?
        lus = LeaseUser.where(lease: leases).to_a.sort_by{|lu| lu.lease.status == 'current' ? 0 : 1 }
        uip = policy.primary_insurable&.integration_profiles&.where(integration: integration)&.take
        next if uip.nil?
        
        # create entries where relevant
        #  commented out to only show primaries for now: policy.policy_users.uniq{|pu| pu.user_id }.each do |pu|
        [policy.policy_users.where(primary: true).take].each do |pu|
          next if to_ignore.include?(pu.id)
          if lus.find{|lu| lu.user_id == pu.user_id }.blank?
            user = pu.user
            next if user.nil?
            were_there_any = true
            csv << [
              policy.primary_user.integration_profiles.where(integration: integration).pluck(:external_id).join(", "),
              uip.external_context[18..],                     # yardi property id
              uip.external_id,                                # yardi unit id
              policy.number,
              policy.effective_date.to_s,
              policy.expiration_date.to_s,
              #pu.primary ? "Policyholder" : "Addtl Insured",
              (user.email || user.profile.contact_email || "").index("getcovered.io") ? "" : (user.email || user.profile.contact_email || ""),
              user.profile.first_name,
              user.profile.last_name,
              policy.id,
              policy.primary_insurable.id,
              pu.id
            ]
          end
        end
        
      end
    end
      

    mailer = ActionMailer::Base.new
    to = (force_test ? "josh@getcovered.io" : "getcovered@lcor.com")
    cc = (force_test ? [] : ["brandon@getcovered.io", "jared@getcovered.io", "josh@getcovered.io", "eylon@getcovered.io"])
    if were_there_any
      mailer.attachments[filename] = File.read("tmp/#{filename}")
      mailer.mail(
        from: "reporting@getcovered.io",
        to: to, 
        cc: cc,
        subject: "Unmatched User Report #{Time.current.to_date.to_s}",
        body: "Attached please find today's unmatched user report. This report consists of information on all users who have purchased or provided proof of a policy for a unit, but whose information could not be matched with that of a resident of that unit. If matching residents were found in other units, their resident codes are provided."
      ).deliver
    else
      mailer.mail(
        from: "reporting@getcovered.io",
        to: to,
        cc: cc,
        subject: "Unmatched User Report #{Time.current.to_date.to_s} (None)",
        body: "There were no unmatched users that haven't already been addressed, so the unmatched user report has been omitted."
      ).deliver
    end
  
  end
  
end
