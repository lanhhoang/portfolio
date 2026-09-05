class Admin::TagsController < Admin::BaseController
  before_action :set_tag, only: %i[edit update destroy]

  def index
    @tags = Tag.includes(:translations).order(created_at: :desc)
  end

  def new
    @tag = Tag.new
    prepare_translations(@tag)
  end

  def create
    @tag = Tag.new(protect_translation_locales(tag_params))
    if @tag.save
      redirect_to admin_tags_path, notice: "Tag created.", status: :see_other
    else
      prepare_translations(@tag)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    prepare_translations(@tag)
  end

  def update
    if @tag.update(protect_translation_locales(tag_params))
      redirect_to admin_tags_path, notice: "Tag saved.", status: :see_other
    else
      prepare_translations(@tag)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tag.destroy!
    redirect_to admin_tags_path, notice: "Tag deleted.", status: :see_other
  end

  private

  def set_tag = @tag = Tag.find(params[:id])

  def tag_params
    params.expect(tag: [
      { translations_attributes: [ %i[id locale name slug _destroy] ] }
    ])
  end
end
