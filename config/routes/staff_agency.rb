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

          put :enable
          put :disable
        end
      end

    post :accounts_index, action: :index, controller: :accounts

    resources :addresses, only: [:index]

    resources :master_policies, path: 'master-policies',
      only: [ :create, :update, :index, :show ] do
        member do
          get :communities
          get :covered_units
          get :available_top_insurables
          get :available_units
          get :historically_coverage_units
          get :master_policy_coverages
          post :cover_unit
          post :add_insurable
          put :cancel
          put :cancel_coverage
          put :cancel_insurable
          put :auto_assign_all
          put :auto_assign_insurable
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
          
          get "policy-types",
            to: "agencies#get_policy_types",
            via: "get"
        end

        collection do
          get :sub_agencies
        end
      end
    post :agencies_index, action: :index, controller: :agencies

    get :total_dashboard, controller: 'dashboard', path: 'dashboard/:agency_id/total_dashboard'
    get :buildings_communities, controller: 'dashboard', path: 'dashboard/:agency_id/buildings_communities'
    get :communities_list, controller: 'dashboard', path: 'dashboard/:agency_id/communities_list'
    get :uninsured_units, controller: 'dashboard', path: 'dashboard/:agency_id/uninsured_units'

    resources :dashboard, only: [] do
      collection do
        get 'communities_data'
        post 'communities_data_index', action: :communities_data
      end
    end

    resources :assignments,
      only: [ :create, :update, :destroy, :index, :show ]

    resources :billing_strategies, path: "billing-strategies", only: [ :create, :update, :index, :show ] do
      member do
        post :add_fee
        get :fees
        delete :destroy_fee
      end
    end

    resources :branding_profiles,
      path: "branding-profiles",
      only: [ :index, :show, :create, :update ] do
        member do
          get :faqs
          get :export
          post :update_from_file
          post :faq_create
          put :faq_update, path: '/faq_update/faq_id'
          post :faq_question_create, path: '/faqs/:faq_id/faq_question_create'
          put :faq_question_update, path: '/faqs/:faq_id/faq_question_update/:faq_question_id'
          delete :faq_delete, path: '/faqs/:faq_id/faq_delete'
          delete :faq_question_delete, path: '/faqs/:faq_id/faq_question_delete/:faq_question_id'
          post :attach_images, path: '/attach_images'
        end
        post :import, on: :collection

        collection do
          post :list
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
          get :billing_strategies_list
          get :toggle_billing_strategy
          get :fees_list
          post :add_fees
        end
    end

    resources :carrier_agency_authorizations, path: "carrier-agency-authorizations", only: [ :update, :index, :show ] do
      member do
        post :add_fee
        get :fees
        delete :destroy_fee
      end
    end

    resources :claims,
      only: [ :create, :update, :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Claim }

          delete :delete_documents
          put :process_claim
        end
      end

    resources :commissions,
      only: [ :index, :show ]

    resources :commission_strategies,
      path: "commission-strategies",
      only: [ :create, :update, :index, :show ]

    resources :fees, only: [:index, :show, :create, :update]

    resources :histories,
      only: [ :index ]

    get 'communities', to: 'insurables#communities'

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
    post :insurables_index, action: :index, controller: :insurables
    post 'insurables/:insurable_id/policies_index', controller: 'policies', action: :index

    resources :invoices, only: [ :update, :index, :show ]

    resources :insurable_types, path: "insurable-types", only: [ :index ]

    resources :leads, only: [:index, :show, :update]
    post :leads_recent_index, action: :index, controller: :leads

    resources :leads_dashboard, only: [:index] do
      collection do
        get :get_filters
      end
    end
    post :leads_dashboard_index, action: :index, controller: :leads_dashboard

    get :get_products, controller: 'leads', path: 'leads/filters/get_products'

    resources :leads_dashboard_tracking_url, only: [:index]

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
        get "get_leads",
            to: "policies#get_leads",
            via: "get"
        get 'resend_policy_documents'
        put :refund_policy
        put :cancel_policy
        put :update_coverage_proof
        put :add_policy_documents
        delete :delete_policy_document
      end
      get "search", to: 'policies#search', on: :collection
    end
    post :policies_index, action: :index, controller: :policies

    resources :policies_dashboard, only: [] do
      collection do
        get 'total'
        get 'graphs'
      end
    end

    resources :policy_cancellation_requests, only: [ :index, :show ] do
      member do
        put :approve
        put :cancel
        put :decline
      end
    end

    resources :refunds,
      only: [ :index, :create, :update] do
        member do
          get :approve
          get :decline
        end
      end

    resources :policy_coverages, only: [ :update ]

    resources :policy_applications,
      path: "policy-applications",
      only: [ :index, :show ]

    resources :policy_application_groups, path: "policy-application-groups" do
      member do
        put :accept
      end
    end

    resources :policy_quotes,
      path: "policy-quotes",
      only: [ :index, :show ]

    resources :staffs,
      only: [ :create, :update, :index, :show ] do
        member do
          put :re_invite
          put :update_self
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

    get :agency_filters, controller: 'tracking_urls', path: 'tracking_urls/agency_filters', to: "tracking_urls#agency_filters"

    resources :tracking_urls,
      only: [ :create, :index, :show, :destroy] do
        member do
          get "get_leads",
            to: "tracking_urls#get_leads",
            via: "get"
          get "get_policies",
              to: "tracking_urls#get_policies",
              via: "get"
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

    resources :notification_settings,
              only: [ :index, :show, :update ]
  end
# end
