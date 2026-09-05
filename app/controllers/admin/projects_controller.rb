class Admin::ProjectsController < Admin::BaseController
  before_action :set_project, only: %i[edit update destroy]

  def index
    @projects = Project.includes(:translations, :tags).order(created_at: :desc)
  end

  def new
    @project = Project.new
    prepare_translations(@project)
  end

  def create
    @project = Project.new(protect_translation_locales(project_params))
    if @project.save
      redirect_to edit_admin_project_path(@project), notice: "Project created.", status: :see_other
    else
      prepare_translations(@project)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    prepare_translations(@project)
  end

  def update
    attributes = protect_translation_locales(project_params)
    gallery_images = attributes.delete(:gallery_images)
    @project.assign_attributes(attributes)
    @project.gallery_images.attach(gallery_images) if gallery_images.present?

    if @project.save
      redirect_to edit_admin_project_path(@project), notice: "Project saved.", status: :see_other
    else
      prepare_translations(@project)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy!
    redirect_to admin_projects_path, notice: "Project deleted.", status: :see_other
  end

  private

  def set_project
    @project = Project.find(params[:id])
  end

  def project_params
    params.expect(project: [
      :role, :started_on, :ended_on, :live_url, :source_url, :featured_position, :cover_image,
      {
        gallery_images: [], tag_ids: [],
        translations_attributes: [ %i[id locale title slug summary body_markdown _destroy] ]
      }
    ])
  end
end
