
# SDK

scope module: :sdk, path: "sdk" do

  resources :addresses,
            only: [:index]

  resources :billing_strategies,
            path: "billing-strategies",
            only: [ :index ]

  resources :insurables,
            only: [ :index, :show ] do
    member do
      resources :insurable_rates,
                path: 'rates',
                only: [:index]
    end
    collection do
      post '/get-or-create',
           to: 'insurables#get_or_create',
           as: :sdk_get_or_create
    end
  end

end
