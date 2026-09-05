class Admin::ResumesController < Admin::BaseController
  before_action :set_resume, only: %i[edit update]

  def edit
    prepare_translations(@resume)
  end

  def update
    if @resume.update(protect_translation_locales(resume_params))
      redirect_to edit_admin_resume_path, notice: "Résumé saved.", status: :see_other
    else
      prepare_translations(@resume)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_resume = @resume = Resume.current || Resume.new(singleton_guard: 1)

  def resume_params
    params.expect(resume: [
      :updated_on,
      { translations_attributes: [ %i[id locale title description pdf _destroy] ] }
    ])
  end
end
