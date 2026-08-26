module ApplicationHelper
  include Pagy::Frontend

  # `Business#address` is a free-text field holding the full postal address,
  # e.g. "Kramgasse 3\n3011 Bern". The store teasers show only street and
  # house number (see the XD artboard "EA_Geschaefte_Uebersicht"), so keep
  # the first line and drop the PLZ/city that follows it.
  def street_address(address)
    address.to_s.split(/[\r\n,]/).map(&:strip).find(&:present?)
  end
end
