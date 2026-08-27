module ParticipationsHelper
  def participation_amount(amount_cents)
    "CHF #{number_with_precision(amount_cents / 100.0, precision: 2, separator: '.', delimiter: "'")}"
  end

  def participation_payment_label(participation)
    if participation.pending_upgrade
      "Bisherige Mitgliedschaft bezahlt · Differenzzahlung offen"
    else
      participation.paid? ? "Bezahlt · Teilnahme abgeschlossen" : "Zahlung offen · Teilnahme nicht abgeschlossen"
    end
  end
end
