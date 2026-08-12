class Admin::DashboardController < Admin::BaseController
  def index
    @metrics = [
      { label: "Benutzer", value: User.count, icon: "users" },
      { label: "Geschäfte", value: Business.count, icon: "building-storefront" },
      { label: "Bestätigte Geschäfte", value: Business.confirmed.count, icon: "check-circle" },
      { label: "Wartende Geschäfte", value: Business.pending.count, icon: "clock" }
    ]

    @recent_businesses = Business.includes(:user).pending.order(created_at: :desc).limit(5)
  end
end
