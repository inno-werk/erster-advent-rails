class Admin::ParticipationUpgradesController < Admin::BaseController
  def update
    upgrade = ParticipationUpgrade.find(params[:id])
    upgrade.mark_paid!
    redirect_to admin_user_path(upgrade.participation.user), status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    render plain: error.record.errors.full_messages.to_sentence, status: :unprocessable_entity
  end
end
