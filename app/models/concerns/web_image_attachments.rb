# Restricts attachments to formats every browser can render in an <img> tag.
# Active Storage identifies the content type from the file bytes, so a renamed
# .eps or .heic is rejected even when the browser reports image/jpeg.
#
# Only new uploads are checked, so a record holding an older unsupported file
# can still be saved. A rejected upload is discarded, so a re-rendered form
# shows the stored image instead of an unsaved blob it cannot link to.
#
# Uploads are also served as resized WebP variants (see ImagesHelper#web_image)
# instead of the multi-megabyte original.
module WebImageAttachments
  extend ActiveSupport::Concern

  CONTENT_TYPES = %w[image/jpeg image/png image/webp image/gif].freeze
  ACCEPT = CONTENT_TYPES.join(",").freeze
  MAX_BYTE_SIZE = 10.megabytes

  # Longest edge in pixels, roughly twice the largest rendered size for sharp
  # display on high-density screens.
  VARIANT_SIZES = { card: 800, large: 1600, wide: 2400 }.freeze

  class_methods do
    # Declares a validated image attachment with the given resized variants.
    # Variants are preprocessed in a job after upload; older uploads get theirs
    # on first view or via `bin/rails images:preprocess`.
    def has_one_web_image(name, variants:)
      has_one_attached name do |attachable|
        variants.each do |variant|
          attachable.variant variant,
            resize_to_limit: [ VARIANT_SIZES.fetch(variant), VARIANT_SIZES.fetch(variant) ],
            format: :webp,
            saver: { quality: 80, strip: true },
            preprocessed: true
        end
      end
      validates_web_image name
    end

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
