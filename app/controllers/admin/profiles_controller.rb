class Admin::ProfilesController < Admin::BaseController
  before_action :set_profile, only: %i[edit update]

  def edit
    prepare_translations(@profile)
  end

  def update
    attributes = protect_translation_locales(profile_params)
    attributes[:social_links] = attributes[:social_links].to_h.compact_blank if attributes[:social_links]
    if @profile.update(attributes)
      redirect_to edit_admin_profile_path, notice: "Profile saved.", status: :see_other
    else
      prepare_translations(@profile)
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_profile = @profile = Profile.current || Profile.new(singleton_guard: 1)

  def profile_params
    params.expect(profile: [
      :public_contact_email, :accent, :portrait,
      {
        social_links: %i[github linkedin website],
        translations_attributes: [ %i[id locale display_name headline introduction biography_markdown availability_label _destroy] ]
      }
    ])
  end
end
