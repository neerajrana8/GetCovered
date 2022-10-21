scope module: :staff_policy_support, path: "policy-support" do
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
  post :insurables_index, action: :index, controller: :insurables
end
