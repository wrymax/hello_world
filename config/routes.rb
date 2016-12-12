Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  match '/webhook', to: "webhook#process", as: :process_webhook
end
