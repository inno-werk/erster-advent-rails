require "test_helper"

class SwissQrBillTest < ActiveSupport::TestCase
  # Decoded from the QR code of docs/QR_Rechnung_A_haarglanz.pdf.
  REFERENCE_PAYLOAD = [
    "SPC", "0200", "1", "CH9600790016600494218", "S", "Erster Advent Untere Altstadt Bern", "Wasserwerkgasse", "29", "3011", "Bern", "CH",
    "", "", "", "", "", "", "", "200.00", "CHF", "", "", "", "", "", "", "", "NON", "",
    "Rechnung Erster Advent 2026, Kategorie A: CHF 200.00 (Leistmitglied)", "EPD"
  ].join("\r\n")

  setup do
    @creditor = InvoiceSetting.new(InvoiceSetting::DEFAULTS).tap(&:validate).snapshot
  end

  test "payload is identical to the reference invoice" do
    bill = SwissQrBill.new(creditor: @creditor, amount_cents: 20_000, message: "Rechnung Erster Advent 2026, Kategorie A: CHF 200.00 (Leistmitglied)")
    assert_equal REFERENCE_PAYLOAD, bill.payload
    assert_equal 31, bill.payload.split("\r\n", -1).size
  end

  test "amount keeps two decimals and the QR code uses error correction M" do
    bill = SwissQrBill.new(creditor: @creditor, amount_cents: 25_005, message: "x")
    assert_equal "250.05", bill.amount
    assert_equal :m, bill.qr_code.qrcode.error_correction_level
  end

  test "rejects invalid amounts, long messages, unsupported characters and missing account" do
    assert_raises(SwissQrBill::InvalidData) { SwissQrBill.new(creditor: @creditor, amount_cents: 0, message: "x") }
    assert_raises(SwissQrBill::InvalidData) { SwissQrBill.new(creditor: @creditor, amount_cents: 100.5, message: "x") }
    assert_raises(SwissQrBill::InvalidData) { SwissQrBill.new(creditor: @creditor, amount_cents: 100, message: "x" * 141) }
    assert_raises(SwissQrBill::InvalidData) { SwissQrBill.new(creditor: @creditor, amount_cents: 100, message: "Rechnung 🎄") }
    assert_raises(SwissQrBill::InvalidData) { SwissQrBill.new(creditor: @creditor.merge("iban" => ""), amount_cents: 100, message: "x") }
  end
end
