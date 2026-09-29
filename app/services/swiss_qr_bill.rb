require "rqrcode"

# Payload of a Swiss QR bill (Swiss Payment Standards, IG QR-bill v2).
#
# The layout matches docs/QR_Rechnung_A_haarglanz.pdf: structured creditor
# address, no ultimate creditor, no debtor, reference type NON and an
# unstructured message. Fields are separated by CR LF, as in the example.
class SwissQrBill
  class InvalidData < StandardError; end

  # Permitted characters since IG QR-bill v2.3: Basic Latin, Latin-1
  # Supplement, Latin Extended-A, Ș ș Ț ț and €.
  CHARACTER_SET = /\A[ -~ -ſȘ-ț€]*\z/
  MAX_MESSAGE_LENGTH = 140
  MAX_AMOUNT_CENTS = 99_999_999_999

  attr_reader :creditor, :amount_cents, :message

  def self.valid_text?(value)
    value.to_s.match?(CHARACTER_SET)
  end

  # creditor: the InvoiceSetting#snapshot hash (string keys).
  def initialize(creditor:, amount_cents:, message:)
    @creditor = creditor.to_h.transform_keys(&:to_s)
    @amount_cents = amount_cents
    @message = message.to_s
    validate!
  end

  def payload
    [
      "SPC", "0200", "1",
      creditor.fetch("iban"),
      "S",
      creditor.fetch("creditor_name"),
      creditor.fetch("street"),
      creditor.fetch("building_number"),
      creditor.fetch("postal_code"),
      creditor.fetch("town"),
      creditor.fetch("country"),
      *Array.new(7, ""), # ultimate creditor (reserved)
      amount,
      "CHF",
      *Array.new(7, ""), # debtor («Zahlbar durch» is left blank)
      "NON",
      "",
      message,
      "EPD"
    ].join("\r\n")
  end

  def amount
    format("%d.%02d", amount_cents / 100, amount_cents % 100)
  end

  # Error correction level M is mandatory for the Swiss QR code.
  def qr_code
    RQRCode::QRCode.new(payload, level: :m)
  end

  private

  def validate!
    unless amount_cents.is_a?(Integer) && amount_cents.positive? && amount_cents <= MAX_AMOUNT_CENTS
      raise InvalidData, "Ungültiger Rechnungsbetrag."
    end
    raise InvalidData, "Die Mitteilung ist länger als #{MAX_MESSAGE_LENGTH} Zeichen." if message.length > MAX_MESSAGE_LENGTH

    fields = creditor.slice("creditor_name", "street", "building_number", "postal_code", "town", "country", "iban").values + [ message ]
    raise InvalidData, "Unvollständige Bankverbindung." if %w[iban creditor_name postal_code town country].any? { |key| creditor[key].blank? }
    raise InvalidData, "Die QR-Rechnung enthält unzulässige Zeichen." unless fields.all? { |value| self.class.valid_text?(value) }
  end
end
