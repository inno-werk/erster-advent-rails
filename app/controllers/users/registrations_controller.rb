# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  layout :registration_layout
  before_action :configure_sign_up_params, only: :create
  before_action :configure_account_update_params, only: :update

  def create
    super do |user|
      capture_account_email_preview(user, newly_registered: true)
      RegistrationMailer.new_registration(user).deliver_later if user.persisted? && RegistrationMailer.notifications_enabled?
    end
  end

  protected

  def build_resource(hash = {})
    super
    resource.build_registration_business
  end

  def registration_layout
    %w[edit update].include?(action_name) ? "app" : "auth"
  end

  def configure_sign_up_params
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :business_name, :address, :name, :phone, :category ])
  end

  def configure_account_update_params
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :phone ])
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
end
