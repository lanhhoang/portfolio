class Admin::Projects::GalleryImagesController < Admin::BaseController
  def destroy
    project = Project.find(params[:project_id])
    project.gallery_images.attachments.find(params[:id]).purge
    redirect_to edit_admin_project_path(project), notice: "Gallery image removed.", status: :see_other
  end
end
