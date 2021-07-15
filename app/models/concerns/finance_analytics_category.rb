module FinanceAnalyticsCategory
  extend ActiveSupport::Concern

  included do
    enum analytics_category: {
      other: 0,
      policy_premium: 1,
      policy_fee: 2,
      policy_tax: 3,
      master_policy_premium: 4
    }
    
    # hack that can hide fees/taxes as if part of premium needs to dynamically
    # determine which line item to add the hidden amounts to; the system will pick
    # the one with the smallest hidden_substitute_suitability_rating (and not pick one with rating nil)
    def hidden_substitute_suitability_rating
      {
        'policy_premium' => 1,
        'master_policy_premium' => 2
      }[self.analytics_category]
    end
  end
  
end
