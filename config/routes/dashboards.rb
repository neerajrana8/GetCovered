#!/usr/bin/env ruby

scope module: :dashboards, path: 'dashboards' do

  namespace :community_insights do
    post :stats, action: :stats
  end

end
