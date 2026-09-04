class Admin::PostsController < Admin::BaseController
  before_action :set_post, only: %i[edit update destroy]

  def index
    @posts = Post.includes(:translations).order(created_at: :desc)
  end

  def new
    @post = Post.new
    prepare_translations(@post)
  end

  def create
    @post = Post.new(protect_translation_locales(post_params))
    if @post.save
      redirect_to edit_admin_post_path(@post), notice: "Post created.", status: :see_other
    else
      prepare_translations(@post)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    prepare_translations(@post)
  end

  def update
    if @post.update(protect_translation_locales(post_params))
      redirect_to edit_admin_post_path(@post), notice: "Post saved.", status: :see_other
    else
      prepare_translations(@post)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @post.destroy!
    redirect_to admin_posts_path, notice: "Post deleted.", status: :see_other
  end

  private

  def set_post = @post = Post.find(params[:id])

  def post_params
    params.expect(post: [
      :cover_image,
      { tag_ids: [], translations_attributes: [ %i[id locale title slug excerpt body_markdown _destroy] ] }
    ])
  end
end
