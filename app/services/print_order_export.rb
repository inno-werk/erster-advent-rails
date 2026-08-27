class PrintOrderExport
  include ActiveModel::Model

  DEFAULT_MESSAGE = "Vielen Dank für Ihre Teilnahme am Ersten Advent in der unteren Altstadt! Hier finden Sie eine Übersicht Ihrer bestellten Printmaterialien. Wir freuen uns auf einen stimmungsvollen Anlass mit Ihnen.".freeze
  MAX_MESSAGE_LENGTH = 1000

  attr_reader :year, :message

  validates :message, length: { maximum: MAX_MESSAGE_LENGTH, message: "darf höchstens %{count} Zeichen enthalten." }
  validate :orders_present

  def initialize(year:, message: DEFAULT_MESSAGE)
    @year = year
    @message = message.to_s.gsub("\r\n", "\n").gsub(/[\u0000-\u0008\u000B-\u001F\u007F]/, "").strip
  end

  def orders
    @orders ||= PrintOrder.for_year(year)
      .where(id: PrintOrderItem.select(:print_order_id))
      .includes(items: :print_product, user: :business).to_a
      .sort_by { |order| [ store_name(order).downcase, order.id ] }
  end

  def store_name(order)
    order.user.business&.business_name.presence || order.user.business_name.presence || order.user.name.presence || order.user.email
  end

  def address(order)
    # Print deliveries use the business address, never the separate billing address.
    order.user.business&.address.presence || order.user.address.presence
  end

  def recipient(order)
    [ store_name(order), order.user.business&.contact_name.presence, address(order)&.gsub(/,\s*/, "\n") ].compact.join("\n")
  end

  def contact(order)
    business = order.user.business
    [ business&.email.presence || order.user.email, business&.phone.presence || order.user.phone.presence ].compact.join("\n")
  end

  def missing_addresses
    orders.select { |order| address(order).blank? }
  end

  def distribution_on
    @distribution_on ||= PrintDistribution.find_by(year: year)&.distribution_on
  end

  private

  def orders_present
    errors.add(:base, "Für #{year} gibt es noch keine Bestellungen mit Printmaterial.") if orders.empty?
  end
end
