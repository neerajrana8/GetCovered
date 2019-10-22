authenticated :staff, lambda{|current_staff| current_staff.role == 'super_admin' } do

  # StaffSuperAdmin
  scope module: StaffSuperAdmin, path: staff do
  
    resources :accounts,
      only: [ :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            as: "accounts_histories_index_recordable",
            defaults: { recordable_type: Account }
        end
      end
  
    resources :agencies,
      only: [ :create, :update, :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            as: "agencies_histories_index_recordable",
            defaults: { recordable_type: Agency }
        end
      end
  
    resources :application_modules,
      path: "application-modules",
      only: [ :create, :update, :index, :show ]
  
    resources :carriers,
      only: [ :create, :update, :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            as: "carriers_histories_index_recordable",
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
            as: "policies_histories_index_recordable",
            defaults: { recordable_type: Policy }
        end
      end
  
    resources :policy_applications,
      path: "policy-applications",
      only: [ :index, :show ]
  
    resources :policy_quotes,
      path: "policy-quotes",
      only: [ :index, :show ]
  
    resources :staffs,
      only: [ :create, :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            as: "staffs_histories_index_recordable",
            defaults: { recordable_type: Staff }
        end
          get "authored-histories",
            to: "histories#index_authorable",
            via: "get",
            as: "staffs_histories_index_authorable",
            defaults: { authorable_type: Staff }
        end
      end
  
    resources :users,
      only: [ :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            as: "users_histories_index_recordable",
            defaults: { recordable_type: User }
        end
          get "authored-histories",
            to: "histories#index_authorable",
            via: "get",
            as: "users_histories_index_authorable",
            defaults: { authorable_type: User }
        end
      end
  
  end
end






