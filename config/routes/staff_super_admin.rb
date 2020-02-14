# authenticated :staff, lambda{|current_staff| current_staff.role == 'super_admin' } do

  # StaffSuperAdmin
  scope module: :staff_super_admin, path: "staff_super_admin" do
  
    resources :accounts,
      only: [ :index, :show ],
      concerns: :reportable do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Account }
        end
      end
  
    resources :agencies,
      only: [ :create, :update, :index, :show ],
      concerns: :reportable do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Agency }
        end
      end
  
    resources :application_modules,
      path: "application-modules",
      only: [ :create, :update, :index, :show ]

    resources :assignments, only: [ :index, :show ]
  
    resources :carriers,
      only: [ :create, :update, :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Carrier }
        end
      end
  
    resources :carrier_agencies,
      path: "carrier-agencies",
      only: [ :create, :update, :destroy ]
  
    resources :carrier_insurable_types,
      path: "carrier-insurable-types",
      only: [ :create, :update, :index, :show ]
  
    resources :carrier_policy_types,
      path: "carrier-policy-types",
      only: [ :create, :update, :index, :show ]
  
    resources :carrier_policy_type_availabilities,
      path: "carrier-policy-type-availabilities",
      only: [ :create, :update, :index, :show ]

    resources :claims, only: [:index, :show]

    resources :insurables, only: [:index, :show ], concerns: :reportable do
      member do
        get :coverage_report
      end
    end
  
    resources :lease_types,
      path: "lease-types",
      only: [ :create, :update, :index, :show ]
  
    resources :lease_type_insurable_types,
      path: "lease-type-insurable-types",
      only: [ :create, :update, :index, :show ]
  
    resources :lease_type_policy_types,
      path: "lease-type-policy-types",
      only: [ :create, :update, :index, :show ]
  
    resources :module_permissions,
      path: "module-permissions",
      only: [ :create, :update, :index, :show ]
  
    resources :payments,
      only: [ :index, :show ]
  
    resources :policies,
      only: [ :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Policy }
        end
        get "search", to: 'policies#search', on: :collection
      end
    
    resources :policy_coverages, only: [ :update ]
  
    resources :policy_applications,
      path: "policy-applications",
      only: [ :index, :show ]
  
    resources :policy_quotes,
      path: "policy-quotes",
      only: [ :index, :show ]
  
    resources :staffs,
      only: [ :create, :index, :show ] do
        member do
          put :re_invite
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Staff }
          get "authored-histories",
            to: "histories#index_authorable",
            via: "get",
            defaults: { authorable_type: Staff }
        end
        collection do
          get "search", to: 'staffs#search'
        end
      end
  
    resources :users,
      only: [ :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: User }
          get "authored-histories",
            to: "histories#index_authorable",
            via: "get",
            defaults: { authorable_type: User }
        end
      end
  end
# end
