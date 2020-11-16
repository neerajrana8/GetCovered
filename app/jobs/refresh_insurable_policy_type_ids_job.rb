class RefreshInsurablePolicyTypeIdsJob < ApplicationJob
  queue_as :default
  
  def perform(insurables)
    insurables.each do |insurable|
      insurable.refresh_policy_type_ids(and_save: true)
    end
  end

end
