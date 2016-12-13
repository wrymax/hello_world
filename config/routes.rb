Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  match 'webhook', to: "webhook#index", via: [:get, :post]
  match 'send_message', to: "webhook#send_message", via: [:get, :post]
  match 'reset', to: "webhook#reset", via: [:get, :post]
  get 'bot', to: "webhook#bot"
  post 'bot', to: "webhook#bot"
end
