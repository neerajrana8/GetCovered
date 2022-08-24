# authenticated :staff, lambda{|current_staff| current_staff.role == 'staff' } do

  # StaffAccount
  scope module: :staff_account, path: "staff_account" do

    get "stripe/button_link", to: "stripe#stripe_button_link", as: :account_stripe_link
    get "stripe/connect", to: "stripe#connect", as: :account_stripe_connect
    post "plaid/connect", to: "plaid#connect", as: :account_plaid_connect

    resources :accounts,
      only: [ :update, :show ],
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

          get 'communities_list',
            to: 'dashboard#communities_list',
            via: 'get'
        end
      end

    resources :addresses, only: [:index]

    get :total_dashboard, controller: 'dashboard', path: 'dashboard/:account_id/total_dashboard'
    get :buildings_communities, controller: 'dashboard', path: 'dashboard/:account_id/buildings_communities'
    get :communities_list, controller: 'dashboard', path: 'dashboard/:account_id/communities_list'
    get :uninsured_units, controller: 'dashboard', path: 'dashboard/:account_id/uninsured_units'

    resources :master_policies, path: 'master-policies', only: [ :index, :show ] do
      member do
        get :communities
        get :covered_units
        get :available_units
        get :historically_coverage_units
        get :master_policy_coverages
        post :cover_unit
        put :cancel_coverage
      end
    end

    resources :assignments,
      only: [ :create, :update, :destroy, :index, :show ]

    resources :branding_profiles,
              path: "branding-profiles",
              only: [ :index, :show, :create, :update ] do
      member do
        get :faqs
        post :update_from_file
        post :faq_create
        put :faq_update, path: '/faq_update/faq_id'
        post :faq_question_create, path: '/faqs/:faq_id/faq_question_create'
        put :faq_question_update, path: '/faqs/:faq_id/faq_question_update/:faq_question_id'
        delete :faq_delete, path: '/faqs/:faq_id/faq_delete'
        delete :faq_question_delete, path: '/faqs/:faq_id/faq_question_delete/:faq_question_id'
        post :attach_images, path: '/attach_images'
        delete :second_logo_delete, path: '/images/second_logo_delete'
      end

      collection do
        post :list
      end
    end

    resources :branding_profile_attributes,
              path: "branding-profile-attributes",
              only: [ :destroy ]

    resources :carrier_insurable_profiles,
      path: "carrier-insurable-profiles",
      only: [:update, :show, :create]

    resources :claims,
      only: [ :create, :index, :show ] do
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

    resources :histories,
      only: [ :index ]

    get 'communities', to: 'insurables#communities'

    resources :insurables,
      only: [ :create, :update, :destroy, :index, :show], concerns: :reportable do
        member do
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
    post 'insurables/upload', controller: 'insurables', action: :upload

    resources :insurable_types, path: "insurable-types", only: [ :index ]

    get 'integrations/:provider', controller: 'integrations', action: :show
    post 'integrations/:provider', controller: 'integrations', action: :create
    put 'integrations/:provider', controller: 'integrations', action: :update

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

    resources :leads, only: [:index, :show, :update]
    post :leads_recent_index, action: :index, controller: :leads

    resources :leads_dashboard, only: [:index] do
      collection do
        get :get_filters
      end
    end
    post :leads_dashboard_index, action: :index, controller: :leads_dashboard

    get :get_products, controller: 'leads', path: 'leads/filters/get_products'

    resources :notes,
      only: [ :create, :update, :destroy, :index, :show ]

    resources :notifications,
      only: [ :update, :index, :show ]

    resources :payment_profiles, path: "payment-profiles", only: [:index, :create, :update] do
      member do
        put "set_default"
      end
    end

    resources :payments,
      only: [ :index, :show ]

    resources :policies,
      only: [ :create, :update, :index, :show ] do
        collection do
          post :add_coverage_proof
        end
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Policy }
          get 'resend_policy_documents'
          put :refund_policy
          put :cancel_policy
          put :add_policy_documents
          put :update_coverage_proof
          delete :delete_policy_document
        end
        get "search", to: 'policies#search', on: :collection
    end
    post :policies_index, action: :index, controller: :policies

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

    resources :notification_settings,
              only: [ :index, :show, :update ]
  end
# end
