class PrintLabelLayout
  include ActiveModel::Model

  FIELDS = {
    columns: { label: "Spalten", default: 2, min: 1, max: 6, step: 1 },
    rows: { label: "Reihen", default: 8, min: 1, max: 20, step: 1 },
    margin_top: { label: "Seitenrand oben", default: 0, min: 0, max: 100, step: 0.1 },
    margin_bottom: { label: "Seitenrand unten", default: 0, min: 0, max: 100, step: 0.1 },
    margin_left: { label: "Seitenrand links", default: 0, min: 0, max: 100, step: 0.1 },
    margin_right: { label: "Seitenrand rechts", default: 0, min: 0, max: 100, step: 0.1 },
    gap_horizontal: { label: "Abstand zwischen Spalten", default: 0, min: 0, max: 30, step: 0.1 },
    gap_vertical: { label: "Abstand zwischen Reihen", default: 0, min: 0, max: 30, step: 0.1 },
    padding_horizontal: { label: "Textabstand links / rechts", default: 7, min: 0, max: 20, step: 0.1 },
    padding_vertical: { label: "Textabstand oben / unten", default: 6, min: 0, max: 20, step: 0.1 },
    font_size: { label: "Schriftgrösse", default: 11, min: 8, max: 18, step: 0.5 }
  }.freeze

  attr_accessor(*FIELDS.keys)

  FIELDS.each do |field, options|
    validates field, numericality: {
      only_integer: options[:step] == 1,
      greater_than_or_equal_to: options[:min], less_than_or_equal_to: options[:max]
    }
  end
  validate :printable_geometry

  def initialize(attributes = {})
    super(FIELDS.transform_values { |options| options[:default] }.merge(attributes.symbolize_keys))
  end

  def self.human_attribute_name(attribute, options = {})
    FIELDS.dig(attribute.to_sym, :label) || super
  end

  def per_page
    columns.to_i * rows.to_i
  end

  def label_width
    (210 - margin_left.to_f - margin_right.to_f - (columns.to_i - 1) * gap_horizontal.to_f) / columns.to_i
  end

  def label_height
    (297 - margin_top.to_f - margin_bottom.to_f - (rows.to_i - 1) * gap_vertical.to_f) / rows.to_i
  end

  private

  def printable_geometry
    return if errors.any?

    if label_width - 2 * padding_horizontal.to_f < 20
      errors.add(:base, "Die Etiketten sind zu schmal. Für den Text müssen mindestens 20 mm Breite bleiben. Bitte Spalten, Ränder oder Abstände reduzieren.")
    end
    if label_height - 2 * padding_vertical.to_f < 8
      errors.add(:base, "Die Etiketten sind zu niedrig. Für den Text müssen mindestens 8 mm Höhe bleiben. Bitte Reihen, Ränder oder Abstände reduzieren.")
    end
  end
end
