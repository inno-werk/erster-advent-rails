# frozen_string_literal: true

class Users::ConfirmationsController < Devise::ConfirmationsController
  include AuthSpamProtection

  layout "auth"
  protect_auth_form limit: 5, within: 15.minutes

   # GET /resource/confirmation/new
   def new
     super
   end

   # POST /resource/confirmation
   def create
     super { |user| capture_account_email_preview(user) }
   end

  # GET /resource/confirmation?confirmation_token=abcdef
  def show
    super do |resource|
      sign_in(resource_name, resource) if resource.errors.empty?
    end
  end

  def pending
  end

   # protected

   # The path used after resending confirmation instructions.
   def after_resending_confirmation_instructions_path_for(resource_name)
     confirmation_pending_path
   end

  # The path used after confirmation.
  def after_confirmation_path_for(resource_name, resource)
    app_setup_participation_path
  end

  private

  def respond_to_spam_as_success
    set_flash_message!(:notice, :send_instructions)
    respond_with({}, location: after_resending_confirmation_instructions_path_for(resource_name))
  end

  def build_auth_form_resource
    self.resource = resource_class.new(email: submitted_auth_email)
  end
end
