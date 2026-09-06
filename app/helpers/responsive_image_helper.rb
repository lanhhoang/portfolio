# frozen_string_literal: true

module ResponsiveImageHelper
  DEFAULT_WIDTHS = [ 320, 640, 960, 1280 ].freeze

  def responsive_image_tag(attachment, alt:, sizes:, widths: DEFAULT_WIDTHS,
                           loading: "lazy", **options)
    metadata = attachment.blob.metadata
    intrinsic_width = metadata["width"].to_i
    intrinsic_height = metadata["height"].to_i

    if intrinsic_width.positive? && intrinsic_height.positive?
      candidate_widths = (widths.map(&:to_i).select { |width| width.positive? && width <= intrinsic_width } +
        [ intrinsic_width ]).uniq.sort
      variants = candidate_widths.to_h do |width|
        [ width, attachment.variant(resize_to_limit: [ width, nil ]) ]
      end

      image_tag(
        variants.fetch(candidate_widths.last),
        alt: alt,
        srcset: variants.map { |width, variant| [ url_for(variant), "#{width}w" ] },
        sizes: sizes,
        loading: loading,
        decoding: "async",
        width: intrinsic_width,
        height: intrinsic_height,
        **options
      )
    else
      image_tag(
        attachment, alt: alt, sizes: sizes, loading: loading,
        decoding: "async", **options
      )
    end
  end
end
