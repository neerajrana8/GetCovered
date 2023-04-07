scope module: :reports, path: 'reports' do
  get 'charge_push_reports/:id', controller: :charge_push_reports, action: :show
  post :charge_push_reports, controller: :charge_push_reports, action: :create
end
