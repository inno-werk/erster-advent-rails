require "test_helper"

class InvoiceSettingTest < ActiveSupport::TestCase
  test "defaults from the example invoice are valid and normalized" do
    setting = InvoiceSetting.current
    assert setting.new_record?
    assert setting.valid?, setting.errors.full_messages.to_sentence
    assert_equal "CH9600790016600494218", setting.iban
    assert_equal "CH96 0079 0016 6004 9421 8", InvoiceSetting.formatted_iban(setting.iban)
  end

  test "current returns the saved row" do
    saved = InvoiceSetting.create!(InvoiceSetting::DEFAULTS.merge(bank_name: "Andere Bank"))
    assert_equal saved, InvoiceSetting.current
  end

  test "rejects a wrong checksum, foreign IBAN and QR-IBAN" do
    { "CH96 0079 0016 6004 9421 9" => "Prüfziffer", "DE89 3704 0044 0532 0130 00" => "Schweizer", "CH44 3199 9123 0008 8901 2" => "QR-IBAN" }.each do |iban, message|
      setting = InvoiceSetting.new(InvoiceSetting::DEFAULTS.merge(iban: iban))
      assert_not setting.valid?, iban
      assert_match message, setting.errors[:iban].join
    end
  end

  test "enforces QR-bill limits and character set" do
    setting = InvoiceSetting.new(InvoiceSetting::DEFAULTS.merge(town: "x" * 36, street: "Gasse 🎄", country: "DE"))
    assert_not setting.valid?
    assert setting.errors[:town].any?
    assert setting.errors[:street].any?
    assert setting.errors[:country].any?
  end

  test "letterhead is limited to eight lines" do
    setting = InvoiceSetting.new(InvoiceSetting::DEFAULTS.merge(letterhead: (1..9).map(&:to_s).join("\n")))
    assert_not setting.valid?
    assert setting.errors[:letterhead].any?
  end
end
