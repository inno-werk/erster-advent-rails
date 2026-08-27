module Admin::StoresHelper
  def store_external_url(value)
    uri = URI.parse(value.to_s.strip)
    uri.to_s if %w[http https].include?(uri.scheme) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end

  def store_payment_entries(participation)
    upgrades = participation.upgrades.sort_by { |upgrade| [ upgrade.created_at, upgrade.id ] }
    original = upgrades.first
    [ {
      record: participation,
      title: "Mitgliedschaft · #{Participation::CATEGORIES.dig(original&.previous_category || participation.category, :title)}",
      amount_cents: original&.previous_amount_cents || participation.amount_cents,
      changeable: upgrades.empty?
    } ] + upgrades.map do |upgrade|
      { record: upgrade, title: "Erhöhung · #{upgrade.category_title}", amount_cents: upgrade.difference_cents, changeable: upgrade.payable? }
    end
  end
end
