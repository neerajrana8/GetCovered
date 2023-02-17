scope module: :coverage_requirements, path: 'coverage_requirements' do
  scope :configuration do
    post :show, controller: :configuration, action: :show
    post :create, controller: :configuration, action: :create
    post :update, controller: :configuration, action: :update
    post :delete, controller: :configuration, action: :delete
    post :community, controller: :configuration, action: :community
  end
end
