class Admin::ParticipationsController < Admin::BaseController
  def index
    @year = list_year
    @category = list_choice(:category, Participation::CATEGORIES.keys)
    @payment_status = list_choice(:payment_status, %w[pending paid upgrade_pending])
    scope = search_list(Participation.for_year(@year).left_joins(user: :business), "users.email", "users.name", "businesses.business_name")
    scope = scope.where(category: @category) if @category
    upgrade_ids = ParticipationUpgrade.pending.where(previous_category: "no_listing", category: Participation::LISTED_CATEGORIES).select(:participation_id)
    case @payment_status
    when "pending"
      scope = scope.where(payment_status: :pending).or(scope.where(payment_status: :paid, category: "no_listing", id: upgrade_ids))
    when "paid"
      scope = scope.paid.where.not(category: "no_listing", id: upgrade_ids)
    when "upgrade_pending"
      scope = scope.paid.where(category: "no_listing", id: upgrade_ids)
    end
    @participations = paginate_list(scope.includes(:upgrades, user: :business).order(created_at: :desc, id: :desc))
  end

  def update
    participation = Participation.find(params[:id])
    case params.require(:participation).permit(:payment_status)[:payment_status]
    when "paid"
      participation.mark_paid!
    when "pending"
      participation.mark_unpaid!
    else
      redirect_to admin_user_path(participation.user), alert: "Ungültiger Zahlungsstatus."
      return
    end
    redirect_to admin_user_path(participation.user), notice: "Zahlungsstatus wurde aktualisiert. Es wurde keine Online-Zahlung ausgelöst."
  rescue ActiveRecord::RecordInvalid => error
    render plain: error.record.errors.full_messages.to_sentence, status: :unprocessable_entity
  end
end
