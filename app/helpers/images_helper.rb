module ImagesHelper
  # Returns the named resized variant of an uploaded image, or the original
  # when it cannot be resized (e.g. an EPS uploaded before format validation).
  # Returns nil when nothing is attached.
  def web_image(attachment, variant)
    return unless attachment.attached?

    attachment.variable? ? attachment.variant(variant) : attachment
  end
end
