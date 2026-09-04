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
    get "contact", to: "public#contact", as: :localized_contact
  end

  namespace :admin do
    root "dashboard#show"
    resource :session, only: %i[new create destroy]
    resource :totp_challenge, only: %i[show create]
    resource :recovery_challenge, only: %i[show create]
    resource :password_reset, only: %i[new create edit update]
  end
end
