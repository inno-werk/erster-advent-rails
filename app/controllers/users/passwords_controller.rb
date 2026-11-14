# frozen_string_literal: true

class Users::PasswordsController < Devise::PasswordsController
  include AuthSpamProtection

  layout "auth"
  protect_auth_form limit: 5, within: 15.minutes

  def create
    super { |user| capture_account_email_preview(user) }
  end
   # GET /resource/password/new
   def new
     super
   end

  # POST /resource/password
  # def create
  #   super
  # end

  # GET /resource/password/edit?reset_password_token=abcdef
  # def edit
  #   super
  # end

  # PUT /resource/password
  # def update
  #   super
  # end

  # protected

  # def after_resetting_password_path_for(resource)
  #   super(resource)
  # end

  # The path used after sending reset password instructions
  # def after_sending_reset_password_instructions_path_for(resource_name)
  #   super(resource_name)
  # end

  private

  def respond_to_spam_as_success
    set_flash_message!(:notice, :send_instructions)
    respond_with({}, location: after_sending_reset_password_instructions_path_for(resource_name))
  end

  def build_auth_form_resource
    self.resource = resource_class.new(email: submitted_auth_email)
  end
end
