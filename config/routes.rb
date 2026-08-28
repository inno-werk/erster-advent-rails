Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check


  scope "(:locale)", locale: /en|de|it|fr/ do
    devise_for :users, controllers: {
        sessions: "users/sessions",
        registrations: "users/registrations",
        confirmations: "users/confirmations",
        passwords: "users/passwords"
     }

    devise_scope :user do
      get "users/confirmation_pending" => "users/confirmations#pending", as: :confirmation_pending
      get "admin/login" => "admin/sessions#new", as: :admin_login
      post "admin/login" => "admin/sessions#create", as: :admin_session
    end

    root "marketing/pages#home"

    get "about" => "marketing/pages#about", as: :marketing_about

    get "products" => "marketing/products#index", as: :marketing_products
    get "product/:id" => "marketing/products#show", as: :marketing_product

    get "stores" => "marketing/stores#index", as: :marketing_stores
    get "store/:id" => "marketing/stores#show", as: :marketing_store
    get "singlestore/:id" => "marketing/stores#show"

    get "cart" => "marketing/cart#show", as: :marketing_cart

    namespace :admin do
      root "dashboard#index"

      resources :stores, only: [ :index, :show, :edit, :update ] do
        member do
          get :preview
          patch :confirm
        end
      end
      resources :products, only: [ :index ]
      resources :orders, only: [ :index ]
      resources :participations, only: [ :index, :update ]
      resources :participation_upgrades, only: :update
      resources :print_products, except: [ :show, :destroy ]
      resource :print_distribution, only: :update
      resources :print_orders, only: [ :index, :show, :edit, :update ]
      resource :print_order_export, only: [], controller: "print_order_exports" do
        get :addresses
        match :address_preview, via: [ :get, :post ]
        post :download_addresses
        get :letters
        match :preview, via: [ :get, :post ]
        post :download
      end
      resources :emails, only: [ :index ]
      resources :requests, only: [ :index ]
      resources :transactions, only: [ :index ]
      resources :transaction_requests, path: "transactionrequests", only: [ :index ]

      resource :invoice, only: [ :show ]

      resources :users, only: [ :index, :new, :create, :show, :update, :destroy ] do
        post :impersonate, on: :member
      end
      resource :cms, only: [ :edit, :update ]
      resources :cms_blocks, path: "cms/blocks", except: [ :index, :show ] do
        member do
          patch :move
        end
      end
    end

    namespace :app do
      root "base#index"
      namespace :setup do
        root "participations#show"
        resource :participation, only: [ :show, :update ]
        resource :payment, only: :show
        resource :test_payment, only: [ :show, :create ]
        resource :print_order, only: [ :show, :update ]
        resource :business, only: :show
      end
      resource :participation, only: [ :show, :edit, :update ] do
        get :payment
      end
      resource :test_payment, only: [ :show, :create ]
      resource :print_order, only: [ :show, :edit, :update ]
      resource :mystore, only: [ :show, :edit, :create, :update ], controller: "mystore" do
          delete :purge_image
      end
      get "transactions" => "transactions#index", as: :transactions
      get "myorders" => "myorders#index", as: :myorders
      get "products" => "products#index", as: :products
   end
 end

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
