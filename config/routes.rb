Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  root "public#root"

  scope "/:locale", locale: /en|fr|vi/ do
    get "/", to: "public#home", as: :localized_root
    get "projects", to: "public#projects", as: :localized_projects
    get "blog", to: "public#blog", as: :localized_blog
    get "about", to: "public#about", as: :localized_about
    get "resume", to: "public#resume", as: :localized_resume
    get "contact", to: "public#contact", as: :localized_contact
  end
end
