class Admin::Profiles::PortraitsController < Admin::BaseController
  def destroy
    profile = Profile.current || raise(ActiveRecord::RecordNotFound)
    profile.portrait.purge
    redirect_to edit_admin_profile_path, notice: "Portrait removed.", status: :see_other
  end
end
