Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root path - homepage with shortlink creation form
  root "short_links#index"

  # API endpoints for JSON-based encode/decode
  namespace :api do
    namespace :v1 do
      post "encode", to: "shortlinks#encode"
      get "decode/:slug", to: "shortlinks#decode", as: :decode
    end
  end

  # Web interface routes
  resources :short_links, only: [ :create ], param: :slug

  # Shortlink redirects - this must be last to avoid conflicts
  # It matches any slug that isn't matched by the routes above
  get ":slug", to: "redirects#show", constraints: { slug: /[^\/]+/ }
end
