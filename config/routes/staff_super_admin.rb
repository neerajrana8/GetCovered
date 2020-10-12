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
        end

        collection do
          get :sub_agencies_index
        end
      end

    resources :application_modules,
      path: "application-modules",
      only: [ :create, :update, :index, :show ]

    resources :assignments, only: [ :index, :show ]

    resources :branding_profiles,
      path: "branding-profiles",
      only: [ :index, :create, :update, :show, :destroy ] do
        member do
          get :faqs
          post :faq_create
          put :faq_update, path: '/faq_update/:faq_id'
          post :faq_question_create, path: '/faqs/:faq_id/faq_question_create'
          put :faq_question_update, path: '/faqs/:faq_id/faq_question_update/:faq_question_id'
          delete :faq_delete, path: '/faqs/:faq_id/faq_delete'
          delete :faq_question_delete, path: '/faqs/:faq_id/faq_question_delete/:faq_question_id'
          post :attach_images, path: '/attach_images'
        end
      end

    resources :branding_profile_attributes,
      path: "branding-profile-attributes",
      only: [ :destroy ]

    resources :pages

    resources :carriers,
      only: [ :create, :update, :index, :show ] do
        member do
          get "histories",
            to: "histories#index_recordable",
            via: "get",
            defaults: { recordable_type: Carrier }
        end
      end


    resources :carrier_agencies, path: "carrier-agencies", only: [ :index, :show, :create, :update, :destroy ]
    resources :carrier_agency_authorizations, path: "carrier-agency-authorizations", only: [ :update, :index, :show ]

    resources :carrier_insurable_types,
      path: "carrier-insurable-types",
      only: [ :create, :update, :index, :show ]

    resources :carrier_policy_types,
      path: "carrier-policy-types",
      only: [ :create, :update, :index, :show ]

    resources :carrier_policy_type_availabilities,
      path: "carrier-policy-type-availabilities",
      only: [ :create, :update, :index, :show ]

    resources :claims, only: [:index, :show, :create] do
      member do
        put :process_claim
      end
    end

    resources :commissions, only: [:index, :show, :update] do
      member do
        put :approve
      end
    end

    resources :insurables, only: [:index, :show ], concerns: :reportable do
      member do
        get :coverage_report
        get :policies
        get 'related-insurables', to: 'insurables#related_insurables'
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
