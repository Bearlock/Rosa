Rails.application.routes.draw do
  
  root 'service_request#index'
  get 'service_request/new'
  post 'service_request/create'
  patch 'service_request/update'
  patch 'service_request/userupdate'
  get 'service_request/index'
  get 'service_request/list'
  get 'service_request/show'
  get 'service_request/edit'
  get 'service_request/move'
  get 'service_request/delete'
  get 'service_request/update'
  get 'service_request/show_usernames'
  get 'service_request/refresh'
  get 'team', :to => 'team#oncall'
  get 'team/oncall'
  get 'team/siebelmatic'
  get 'team/sla'
  get 'team/wallboard'

end
