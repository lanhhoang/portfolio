class Admin::Resumes::PdfsController < Admin::BaseController
  def destroy
    resume = Resume.current || raise(ActiveRecord::RecordNotFound)
    translation = resume.translations.find(params[:id])
    translation.pdf.purge
    redirect_to edit_admin_resume_path, notice: "PDF removed.", status: :see_other
  end
end
