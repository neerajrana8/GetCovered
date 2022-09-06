scope module: :insurables, path: 'insurables' do

  namespace :insurables do
    post :upload, action: :upload
  end

end
