module CmsHelper
  # Tags a CMS author may produce in a body text.
  BODY_TAGS = %w[div p br strong b em i u a ul ol li].freeze
  BODY_ATTRIBUTES = %w[href target rel].freeze

  # Tags that survive in a heading: everything else is flattened away.
  HEADING_TAGS = %w[strong b em i br].freeze

  # Block-level wrappers Trix emits; each becomes one visual line in a heading.
  HEADING_BLOCK_TAGS = %w[div p h1 h2 h3 h4 h5 h6 li blockquote pre].freeze

  # Renders a rich-text heading as *inline* markup so it can live inside the
  # design's <h3> without Trix's block <div>s breaking the type scale.
  # Each Trix block becomes a <br>, bold stays <strong>, italic stays <em>.
  def cms_heading(rich_text)
    html = rich_text&.body&.to_html
    return "".html_safe if html.blank?

    fragment = Nokogiri::HTML::DocumentFragment.parse(html)
    lines = fragment.children.filter_map do |node|
      inline = if node.element? && HEADING_BLOCK_TAGS.include?(node.name)
        node.inner_html
      else
        node.to_html
      end
      inline.strip.presence
    end

    sanitize(lines.join("<br>"), tags: HEADING_TAGS, attributes: [])
  end

  # Renders a rich-text body without Action Text's `.trix-content` wrapper,
  # whose own line-height would override the storefront's .text-body scale.
  def cms_body(rich_text)
    html = rich_text&.body&.to_html
    return "".html_safe if html.blank?

    sanitize(html, tags: BODY_TAGS, attributes: BODY_ATTRIBUTES)
  end

  # Confirmation shown before a brand colour change goes live site-wide.
  def cms_brand_color_confirm(color)
    "Die Farbe #{color} wird auf der ganzen Website übernommen — " \
      "Startseite, Mitgliederbereich und Verwaltung. Jetzt anwenden?"
  end

  def cms_block_type_label(block_type)
    {
      "text_image_block" => "Text mit Bild und Button",
      "full_image_block" => "Vollbild",
      "plain_text_block" => "Text",
      "faq_item" => "FAQ-Eintrag"
    }.fetch(block_type.to_s, block_type.to_s)
  end
end
