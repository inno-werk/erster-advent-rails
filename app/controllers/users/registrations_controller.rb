# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  layout :registration_layout
  before_action :configure_sign_up_params, only: :create
  prepend_before_action :authenticate_scope!, only: [
    :edit, :update, :destroy, :edit_personal, :update_personal, :edit_password, :update_password
  ]
  prepend_before_action :set_minimum_password_length, only: [ :new, :edit_password, :update_password ]

  def create
    super do |user|
      capture_account_email_preview(user, newly_registered: true)
      RegistrationMailer.new_registration(user).deliver_later if user.persisted? && RegistrationMailer.notifications_enabled?
    end
  end

  def edit_personal
  end

  def update_personal
    if resource.update(personal_params)
      notice = if resource.pending_reconfirmation?
        "Ihre Angaben wurden gespeichert. Bitte bestätigen Sie die neue E-Mail-Adresse."
      else
        "Ihre persönlichen Angaben wurden gespeichert."
      end
      redirect_to edit_user_registration_path, notice: notice, status: :see_other
    else
      render :edit_personal, status: :unprocessable_entity
    end
  end

  def edit_password
  end

  def update_password
    if resource.update_with_password(password_params)
      bypass_sign_in resource, scope: resource_name
      redirect_to edit_user_registration_path, notice: "Ihr Passwort wurde geändert.", status: :see_other
    else
      clean_up_passwords resource
      render :edit_password, status: :unprocessable_entity
    end
  end

  def update
    redirect_to edit_user_registration_path, status: :see_other
  end

  def destroy
    if resource.update(deleted: true)
      clear_account_email_preview
      Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)
      redirect_to root_path, notice: "Ihr Konto wurde deaktiviert. Ihre Daten bleiben erhalten.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  protected

  def build_resource(hash = {})
    super
    resource.build_registration_business
  end

  def registration_layout
    %w[new create].include?(action_name) ? "auth" : "app"
  end

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :business_name, :address, :name, :phone, :category ])
  end

  def after_inactive_sign_up_path_for(resource)
    flash.delete(:notice)
    confirmation_pending_path
  end

  def after_sign_up_path_for(resource)
    app_setup_participation_path
  end

  def after_update_path_for(resource)
    edit_user_registration_path
  end

  private

  def personal_params
    params.require(:user).permit(:name, :phone, :email)
  end

  def password_params
    params.require(:user).permit(:current_password, :password, :password_confirmation)
  end
end
