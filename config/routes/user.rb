
# User
scope module: :user, path: "user" do
  
  resources :claims,
    only: [ :index, :show, :create ] do
      member do
        post :attach_documents
        delete :delete_documents
      end
      collection do
        post :claim_creation
      end
    end

  resources :login_activities,
            path: "login-activities",
            only: [:index] do
    collection do
      get :close_all_sessions
    end
  end


  resources :invoices,
    only: [ :index, :show ]
  
  resources :leases,
    only: [ :index ]
  
  resources :notifications,
    only: [ :update, :index, :show ]
  resources :notification_settings, only: [:index] do
    collection do
      post :switch
    end
  end
  
  resources :payment_profiles, path: "payment-profiles", only: [:index, :create, :update] do
    member do
      put "set_default"
    end
  end
  
  resources :payments,
    only: [ :create, :index, :show ]
  
  resources :policies, only: [ :index, :show ] do
    collection do
      post :add_coverage_proof
      post :cancel_auto_renewal
      delete :delete_coverage_proof_documents
    end
    member do
      get 'bulk_decline'
      get 'render_eoi'
      get 'bulk_accept'
      get 'resend_policy_documents'
      get 'refund_policy'
      get 'cancel_policy'
    end
  end
  
  resources :policy_applications,
    path: "policy-applications",
    only: [ :create, :index, :show, :update ]
  
  resources :policy_quotes,
    path: "policy-quotes",
    only: [ :index, :show ]
  
  resources :users,
    only: [ :update, :show ] do
      member do
        put 'change_password'
    end
  end
end
