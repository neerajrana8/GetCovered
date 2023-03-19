scope module: :staff_policy_support, path: "policy-support" do
  resources :carriers, only: [:index]

  resources :policies,
            only: [ :index, :show, :update ] do

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
  post :policies_dashboard_index, action: :index, controller: :policies

  resources :accounts, only: [ :index]
  resources :communities, only: [ :index]
  post :accounts_index, action: :index, controller: :accounts

  resources :insurables, only: [:create, :update, :index, :show, :destroy], concerns: :reportable do
    member do
      get :coverage_report
      get :policies
      get 'related-insurables', to: 'insurables#related_insurables'

      get 'coverage-options',
          to: 'insurable_rate_configurations#get_parent_options',
          defaults: { type: 'Insurable', carrier_id: 5, insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS.first }
      post 'coverage-options',
           to: 'insurable_rate_configurations#set_options',
           defaults: { type: 'Insurable', carrier_id: 5, insurable_type_id: ::InsurableType::RESIDENTIAL_UNITS_IDS.first }
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

  post 'insurables/:insurable_id/policies_index', controller: 'policies', action: :index
  get :agency_filters, controller: 'insurables', to: 'insurables#agency_filters', path: 'insurables/filters/agency_filters'
  post :insurables_index, action: :index, controller: :insurables
  post 'insurables/upload', controller: 'insurables', action: :upload

  resources :insurable_types, path: "insurable-types", only: [ :index ]
end
