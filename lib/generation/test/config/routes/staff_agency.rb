authenticated :staff, lambda{|current_staff| current_staff.role == 'agent' } do

  # StaffAgency
  scope module: StaffAgency, path: staff do
  
    resources :accounts,
      only: [ :create, :update, :index, :show ] do
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
  
    resources :assignments,
      only: [ :create, :update, :destroy, :index, :show ]
  
    resources :billing_strategies,
      path: "billing-strategies",
      only: [ :create, :update, :index, :show ]
  
    resources :branding_profiles,
      path: "branding-profiles",
      only: [ :update, :show ]
  
    resources :carriers,
      only: [ :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            as: "carriers_histories_index_recordable",
            defaults: { recordable_type: Carrier }
        end
      end
  
    resources :carrier_agency_authorizations,
      path: "carrier-agency-authorizations",
      only: [ :update, :index, :show ]
  
    resources :claims,
      only: [ :create, :update, :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            as: "claims_histories_index_recordable",
            defaults: { recordable_type: Claim }
        end
      end
  
    resources :commissions,
      only: [ :index, :show ]
  
    resources :commission_strategies,
      path: "commission-strategies",
      only: [ :create, :update, :index, :show ]
  
    resources :histories,
      only: [ :index ]
  
    resources :insurables,
      only: [ :create, :update, :destroy, :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            as: "insurables_histories_index_recordable",
            defaults: { recordable_type: Insurable }
        end
        resources :insurable_rates,
          path: "insurable-rates",
          defaults: {
            access_pathway: [::Insurable],
            access_ids:     [:insurable_id]
          }
          only: [ :update, :index ]
        resources :insurable_types,
          path: "insurable-types",
          defaults: {
            access_pathway: [::Insurable],
            access_ids:     [:insurable_id]
          }
          only: [ :index ]
      end
  
    resources :invoices,
      only: [ :update, :index, :show ]
  
    resources :leases,
      only: [ :create, :update, :destroy, :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            as: "leases_histories_index_recordable",
            defaults: { recordable_type: Lease }
        end
      end
  
    resources :lease_types,
      path: "lease-types",
      only: [ :index ]
  
    resources :notes,
      only: [ :create, :update, :destroy, :index, :show ]
  
    resources :notifications,
      only: [ :update, :index, :show ]
  
    resources :payments,
      only: [ :index, :show ]
  
    resources :policies,
      only: [ :create, :update, :index, :show ] do
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
      only: [ :create, :update, :index, :show ] do
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
      only: [ :create, :update, :index, :show ] do
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






