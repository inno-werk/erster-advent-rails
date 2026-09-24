# Restricts attachments to formats every browser can render in an <img> tag.
# Active Storage identifies the content type from the file bytes, so a renamed
# .eps or .heic is rejected even when the browser reports image/jpeg.
#
# Only new uploads are checked, so a record holding an older unsupported file
# can still be saved. A rejected upload is discarded, so a re-rendered form
# shows the stored image instead of an unsaved blob it cannot link to.
module WebImageAttachments
  extend ActiveSupport::Concern

  CONTENT_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  ACCEPT = CONTENT_TYPES.join(",").freeze
  MAX_BYTE_SIZE = 10.megabytes

  class_methods do
    def validates_web_image(*names)
      names.each do |name|
        validate { validate_web_image(name) }
      end
    end
  end

  private

  def validate_web_image(name)
    change = attachment_changes[name.to_s]
    return unless change.is_a?(ActiveStorage::Attached::Changes::CreateOne)

    blob = change.blob
    return if CONTENT_TYPES.include?(blob.content_type) && blob.byte_size <= MAX_BYTE_SIZE

    attachment_changes.delete(name.to_s)
    errors.add(name, "muss ein Bild (JPEG, PNG, WebP oder GIF) mit höchstens 10 MB sein.")
  end
end
