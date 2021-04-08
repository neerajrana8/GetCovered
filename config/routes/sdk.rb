
# SDK

scope module: :sdk, path: "sdk" do

  resources :billing_strategies,
            path: "billing-strategies",
            only: [ :index ]

end
