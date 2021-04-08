
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

  resources :policy_applications,
            path: "policy-applications",
            only: [ :create, :update ] do
    member do
      post :rent_guarantee_complete
    end
    collection do
      get '/:token', # define manually on collection to get :token instead of :id
          to: 'policy_applications#show',
          as: :sdk_show
      post '/new',
           to: 'policy_applications#new',
           as: :sdk_new
      post '/get-coverage-options',
           to: 'policy_applications#get_coverage_options',
           as: :sdk_get_coverage_options
    end
  end

end
