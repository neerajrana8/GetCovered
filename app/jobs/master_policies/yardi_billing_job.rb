module MasterPolicies
  class YardiBillingJob < ApplicationJob
    queue_as :default

    def perform(*)
      start_of_last_month = (Time.current.beginning_of_month - 1.day).beginning_of_month.to_date
      mps = Policy.where.not(status: 'CANCELLED').or(Policy.where("cancellation_date >= ?", start_of_last_month))
                  .where("expiration_date >= ?", start_of_last_month)
                  .where(policy_type_id: PolicyType::MASTER_ID)
      mps.each do |mp|
        mp.insurables.each do |ins|
          config = mp.find_closest_master_policy_configuration(ins)
          
        end
      end


                  
        mp.insurables.each do |i|
    config = mp.find_closest_master_policy_configuration(i)
    units = i.units.where("(expanded_covered->'3') is not null")
    if units.count > 0
      units.each do |u|
    end







  end
end
