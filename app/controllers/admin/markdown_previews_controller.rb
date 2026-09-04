class Admin::MarkdownPreviewsController < Admin::BaseController
  FRAME_ID = /\A(?:project|post|profile)_(?:en|fr|vi)_markdown_preview\z/

  def create
    values = params.expect(preview: %i[markdown frame_id])
    frame_id = values[:frame_id].to_s
    return head :unprocessable_entity unless FRAME_ID.match?(frame_id)

    @frame_id = frame_id
    @html = MarkdownRenderer.call(values[:markdown].to_s)
    response.set_header("X-Robots-Tag", "noindex, nofollow")
  end
end
