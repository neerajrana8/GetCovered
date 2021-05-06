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
  end
  
end
