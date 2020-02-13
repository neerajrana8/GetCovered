# authenticated :staff, lambda{|current_staff| current_staff.role == 'agent' } do

  # StaffAgency
  scope module: :staff_agency, path: "staff_agency" do
  
    resources :accounts,
      only: [ :create, :update, :index, :show ],
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
  
    resources :assignments,
      only: [ :create, :update, :destroy, :index, :show ]
  
    resources :billing_strategies,
      path: "billing-strategies",
      only: [ :create, :update, :index, :show ]
  
    resources :branding_profiles,
      path: "branding-profiles",
      only: [ :update, :show ]
      
    resources :carrier_insurable_profiles,
      path: "carrier-insurable-profiles",
      only: [:update, :show]
  
    resources :carriers,
      only: [ :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
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
            defaults: { recordable_type: Claim }

          post :attach_documents
          delete :delete_documents
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
      only: [ :create, :update, :destroy, :index, :show ],
      concerns: :reportable do
        member do
          get 'refresh-rates', to: 'insurable_rates#refresh_rates'
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Insurable }
          get :coverage_report
          
          post :sync_residential_address,
          	path: "sync-residential-address"
          	
          post :get_residential_property_info,
          	path: "get-residential-property-info"

        end
        resources :insurable_rates,
          path: "insurable-rates",
          defaults: {
            access_pathway: [::Insurable],
            access_ids:     [:insurable_id]
          },
          only: [ :update, :index ] do
            get 'refresh-rates', to: 'insurable_rates#refresh_rates', on: :collection
          end
      end
  
    resources :invoices, only: [ :update, :index, :show ]
    
    resources :insurable_types, path: "insurable-types", only: [ :index ]
  
    resources :leases,
      only: [ :create, :update, :destroy, :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
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
            defaults: { recordable_type: Policy }
        end
        get "search", to: 'policies#search', on: :collection
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
      only: [ :create, :update, :index, :show ] do
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






