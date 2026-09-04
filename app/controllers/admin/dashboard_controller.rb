class Admin::DashboardController < Admin::BaseController
  def show
    @project_count = Project.count
    @post_count = Post.count
    @tag_count = Tag.count
  end
end
