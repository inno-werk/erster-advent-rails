# frozen_string_literal: true

class Users::SessionsController < Devise::SessionsController
  layout "auth"
  prepend_before_action :clear_account_email_preview, only: :destroy
  # before_action :configure_sign_in_params, only: [:create]

  # GET /resource/sign_in
  # def new
  #   super
  # end

  # POST /resource/sign_in
  # def create
  #   super
  # end

  # DELETE /resource/sign_out
  # def destroy
  #   super
  # end

  # protected

  def after_sign_in_path_for(resource)
    stored_location_for(resource) || redirect_path_for(resource)
  end

  private

  def redirect_path_for(resource)
    return admin_root_path if resource.respond_to?(:adminish?) ? resource.adminish? : resource.respond_to?(:admin?) && resource.admin?

    return app_participation_path unless resource.participation_complete?

    app_mystore_path
  end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_in_params
  #   devise_parameter_sanitizer.permit(:sign_in, keys: [:attribute])
  # end
end
