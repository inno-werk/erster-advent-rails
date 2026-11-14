# frozen_string_literal: true

class Users::UnlocksController < Devise::UnlocksController
  include AuthSpamProtection

  layout "auth"
  protect_auth_form limit: 5, within: 15.minutes

  # GET /resource/unlock/new
  # def new
  #   super
  # end

  # POST /resource/unlock
  # def create
  #   super
  # end

  # GET /resource/unlock?unlock_token=abcdef
  # def show
  #   super
  # end

  # protected

  # The path used after sending unlock password instructions
  # def after_sending_unlock_instructions_path_for(resource)
  #   super(resource)
  # end

  # The path used after unlocking the resource
  # def after_unlock_path_for(resource)
  #   super(resource)
  # end

  private

  def respond_to_spam_as_success
    set_flash_message!(:notice, :send_instructions)
    respond_with({}, location: after_sending_unlock_instructions_path_for(resource_name))
  end

  def build_auth_form_resource
    self.resource = resource_class.new(email: submitted_auth_email)
  end
end
