class Admin::Posts::CoverImagesController < Admin::BaseController
  def destroy
    post = Post.find(params[:post_id])
    post.cover_image.purge
    redirect_to edit_admin_post_path(post), notice: "Cover image removed.", status: :see_other
  end
end
