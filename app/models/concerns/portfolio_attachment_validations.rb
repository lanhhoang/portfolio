# frozen_string_literal: true

module PortfolioAttachmentValidations
  extend ActiveSupport::Concern

  IMAGE_TYPES = %w[image/jpeg image/png image/webp].freeze

  class_methods do
    def validates_portfolio_attachment(name, content_types:, extensions:, max_size:, type_message:)
      validate do
        attachment = public_send(name)
        blobs = attachment.respond_to?(:blobs) ? attachment.blobs : [ attachment.blob ].compact

        blobs.each do |blob|
          errors.add(name, type_message) unless blob.content_type.in?(content_types)
          errors.add(name, type_message) unless File.extname(blob.filename.to_s).downcase.delete_prefix(".").in?(extensions)
          errors.add(name, "must be #{max_size / 1.megabyte} MB or smaller") if blob.byte_size > max_size
        end
      end
    end
  end
end
