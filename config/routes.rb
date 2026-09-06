Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "public#root"

  scope "/:locale", locale: /en|fr|vi/, format: false do
    get "/", to: "public/home#show", as: :localized_root
    get "projects", to: "public/projects#index", as: :localized_projects
    get "projects/:slug", to: "public/projects#show", as: :localized_project
    get "blog", to: "public/posts#index", as: :localized_blog
    get "blog/:slug", to: "public/posts#show", as: :localized_post
    get "about", to: "public/profiles#show", as: :localized_about
    get "resume", to: "public/resumes#show", as: :localized_resume
    get "resume/download", to: "public/resume_downloads#show", as: :localized_resume_download
    get "contact", to: "public/contact_messages#new", as: :localized_contact
    post "contact", to: "public/contact_messages#create"
  end

  namespace :admin do
    root "dashboard#show"
    resources :messages, only: [ :index, :show ] do
      resource :state, only: :update, module: :messages
      resource :delivery_retry, only: :create, module: :messages
    end
    resources :projects, except: :show do
      resource :cover_image, only: :destroy, module: :projects
      resources :gallery_images, only: :destroy, module: :projects
    end
    resources :posts, except: :show do
      resource :cover_image, only: :destroy, module: :posts
    end
    resources :tags, except: :show
    resource :profile, only: %i[edit update] do
      resource :portrait, only: :destroy, module: :profiles
    end
    resource :resume, only: %i[edit update] do
      resources :pdfs, only: :destroy, module: :resumes
    end
    resource :markdown_preview, only: :create
    resource :session, only: %i[new create destroy]
    resource :totp_challenge, only: %i[show create]
    resource :recovery_challenge, only: %i[show create]
    resource :password_reset, only: %i[new create edit update]

    resources :project_translations, only: [] do
      resource :publication, only: %i[create update destroy], module: :project_translations
    end

    resources :post_translations, only: [] do
      resource :publication, only: %i[create update destroy], module: :post_translations
    end
  end
end
