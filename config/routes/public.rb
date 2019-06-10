scope '/public' do
  resources :branding_profiles, only: :show, param: :url
end