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

    resources :refunds,
      only: [ :index, :create, :update] do
        member do
          get :approve
          get :decline
        end
      end

    get :total_dashboard, controller: 'dashboard', path: 'dashboard/:super_admin_id/total_dashboard'
    get :buildings_communities, controller: 'dashboard', path: 'dashboard/:super_admin_id/buildings_communities'
    get :communities_list, controller: 'dashboard', path: 'dashboard/:super_admin_id/communities_list'
    get :uninsured_units, controller: 'dashboard', path: 'dashboard/:super_admin_id/uninsured_units'

    resources :agencies,
      only: [ :create, :update, :index, :show ],
      concerns: :reportable do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Agency }
          get 'branding_profile'

          put :enable
          put :disable
        end

        collection do
          get :sub_agencies_index
        end
      end

    resources :application_modules,
      path: "application-modules",
      only: [ :create, :update, :index, :show ]

    resources :assignments, only: [ :index, :show ]

    resources :billing_strategies, path: "billing-strategies", only: [ :create, :update, :index, :show ] do
      member do
        post :add_fee
        get :fees
        delete :destroy_fee
      end
    end

    resources :branding_profiles,
      path: "branding-profiles",
      only: [ :index, :create, :update, :show, :destroy ] do
        member do
          get :faqs
          get :export
          post :update_from_file
          post :faq_create
          put :faq_update, path: '/faq_update/:faq_id'
          post :faq_question_create, path: '/faqs/:faq_id/faq_question_create'
          put :faq_question_update, path: '/faqs/:faq_id/faq_question_update/:faq_question_id'
          delete :faq_delete, path: '/faqs/:faq_id/faq_delete'
          delete :faq_question_delete, path: '/faqs/:faq_id/faq_question_delete/:faq_question_id'
          post :attach_images, path: '/attach_images'
        end
        post :import, on: :collection
      end

    resources :branding_profile_attributes, path: "branding-profile-attributes", only: [ :destroy ] do
      collection do
        post :copy
        post :force_copy
      end
    end

    resources :pages

    resources :carriers,
      only: [ :create, :update, :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Carrier }
          get :carrier_agencies
          get :toggle_billing_strategy
          get :billing_strategies_list
          get :commission_list
          post :assign_agency_to_carrier
          post :unassign_agency_from_carrier
          post :add_billing_strategy
          post :add_commissions
          put :update_commission
          get :commission

          post :add_fee
          get :fees
          delete :destroy_fee
        end
        post :assign_agency_to_carrier, path: 'assign-agency-to-carrier'
      end
    resources :carrier_agencies, path: "carrier-agencies", only: [ :index, :show, :create, :update, :destroy ]
    resources :carrier_agency_authorizations, path: "carrier-agency-authorizations", only: [ :update, :index, :show ] do
      member do
        post :add_fee
        get :fees
        delete :destroy_fee
      end
    end

    resources :carrier_insurable_types,
      path: "carrier-insurable-types",
      only: [ :create, :update, :index, :show ]

    resources :carrier_policy_types,
      path: "carrier-policy-types",
      only: [ :create, :update, :index, :show ]

    resources :carrier_policy_type_availabilities,
              path: "carrier-policy-type-availabilities",
              only: [ :create, :update, :index, :show ] do
      member do
        post :add_fee
        get :fees
        delete :destroy_fee
      end
    end

    resources :claims, only: [:index, :show, :create, :update] do
      member do
        put :process_claim
      end
    end

    resources :commissions, only: [:index, :show, :update] do
      member do
        put :approve
      end
    end

    resources :fees, only: [:index, :show, :create, :update]

    resources :insurables, only: [:create, :update, :index, :show, :destroy], concerns: :reportable do
      member do
        get :coverage_report
        get :policies
        get 'related-insurables', to: 'insurables#related_insurables'
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
    get :agency_filters, controller: 'insurables', to: 'insurables#agency_filters', path: 'insurables/filters/agency_filters'

    resources :insurable_types, path: "insurable-types", only: [ :index ]

    resources :leads, only: [:index, :show, :update]
    resources :leads_dashboard, only: [:index]
    resources :leads_dashboard_tracking_url, only: [:index]

    get :get_filters, controller: 'leads_dashboard', path: 'leads_dashboard/get_filters'

    resources :lease_types,
      path: "lease-types",
      only: [ :create, :update, :index, :show ]

    resources :lease_type_insurable_types,
      path: "lease-type-insurable-types",
      only: [ :create, :update, :index, :show ]

    resources :lease_type_policy_types,
      path: "lease-type-policy-types",
      only: [ :create, :update, :index, :show ]

    resources :master_policies, path: 'master-policies', only: [ :index, :show ] do
      member do
        get :communities
        get :covered_units
        get :available_units
        get :historically_coverage_units
        get :master_policy_coverages
      end
    end

    resources :module_permissions,
      path: "module-permissions",
      only: [ :create, :update, :index, :show ]

    resources :payments,
      only: [ :index, :show ]

    resources :policies,
      only: [ :update, :index, :show ] do
        collection do
          post :add_coverage_proof
        end
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Policy }
          put :update_coverage_proof
          delete :delete_policy_document
          put :refund_policy
          put :cancel_policy
        end

        get "search", to: 'policies#search', on: :collection
    end

    resources :policy_cancellation_requests, only: [ :index, :show ] do
      member do
        put :approve
        put :cancel
        put :decline
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
      only: [ :create, :index, :show, :update ] do
        member do
          put :re_invite
          put :toggle_enabled
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

    get :agency_filters, controller: 'tracking_urls', path: 'tracking_urls/agency_filters', to: "tracking_urls#agency_filters"

    resources :tracking_urls,
              only: [ :create, :index, :show, :destroy ] do
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
