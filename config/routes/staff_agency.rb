# authenticated :staff, lambda{|current_staff| current_staff.role == 'agent' } do

  # StaffAgency
  scope module: :staff_agency, path: "staff_agency" do
  
    get "stripe/button_link", to: "stripe#stripe_button_link", as: :agency_stripe_link
    get "stripe/connect", to: "stripe#connect", as: :agency_stripe_connect

    resources :accounts,
      only: [ :create, :update, :index, :show ],
      concerns: :reportable do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Account }

          get "account_policies",
            to: "accounts#account_policies",
            via: "get"

          get "account_communities",
            to: "accounts#account_communities",
            via: "get"

          get "account_units",
            to: "accounts#account_units",
            via: "get"

          get "account_buildings",
            to: "accounts#account_buildings",
            via: "get"
        end
      end

    resources :master_policies, path: 'master-policies',
      only: [ :create, :update, :index, :show ] do
        member do
          post :add_insurable
          get :communities
          get :covered_units
          post :cover_unit
          get :available_top_insurables
          get :available_units
          get :historically_coverage_units
          put :cancel
          put :cancel_unit
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
          get 'branding_profile'
        end

        collection do
          get :sub_agencies_index
        end
      end
  
    resources :fees,
      only: [ :create, :update, :index, :show ]

    resources :assignments,
      only: [ :create, :update, :destroy, :index, :show ]
  
    resources :billing_strategies,
      path: "billing-strategies",
      only: [ :create, :update, :index, :show ]
  
    resources :branding_profiles,
      path: "branding-profiles",
      only: [ :show, :create, :update ] do
        member do
          get :faqs
          post :faq_create
          put :faq_update, path: '/faq_update/faq_id'
          post :faq_question_create, path: '/faqs/:faq_id/faq_question_create'
          put :faq_question_update, path: '/faqs/:faq_id/faq_question_update/:faq_question_id'
          delete :faq_delete, path: '/faqs/:faq_id/faq_delete'
          delete :faq_question_delete, path: '/faqs/:faq_id/faq_question_delete/:faq_question_id'
        end
      end
    
    resources :branding_profile_attributes,
      path: "branding-profile-attributes",
      only: [ :destroy ]
      
    resources :pages

    resources :carrier_insurable_profiles,
      path: "carrier-insurable-profiles",
      only: [:update, :show, :create]
  
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
          get :policies
          get 'related-insurables', to: 'insurables#related_insurables'
          
          post :sync_residential_address,
          	path: "sync-residential-address"
          	
          post :get_residential_property_info,
          	path: "get-residential-property-info"

        end

        collection do
          post :bulk_create
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

        collection do
          post :bulk_create
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
  
    resources :policies, only: [ :create, :update, :index, :show ] do
      collection do
        post :add_coverage_proof
      end
      member do
        get "histories",
          to: "histories#index_recordable",
          via: "get",
          defaults: { recordable_type: Policy }
        get 'resend_policy_documents'
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
          put :toggle_enabled
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
        collection do
          get "search", to: 'users#search'
        end
      end
  end
# end






