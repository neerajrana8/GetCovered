scope module: :insurables, path: 'insurables' do

  namespace :insurables do
    post :upload, action: :upload
  end

  post :top_available, controller: :insurables, action: :top_available
  post :list, controller: :insurables, action: :list
end
