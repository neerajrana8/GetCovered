scope '/public' do
  resources :branding_profiles, only: :show, param: :url
  resources :policy_applications, only: [:show, :create, :update]
end