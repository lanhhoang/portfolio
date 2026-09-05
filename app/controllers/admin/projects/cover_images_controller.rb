class Admin::Projects::CoverImagesController < Admin::BaseController
  def destroy
    project = Project.find(params[:project_id])
    project.cover_image.purge
    redirect_to edit_admin_project_path(project), notice: "Cover image removed.", status: :see_other
  end
end
