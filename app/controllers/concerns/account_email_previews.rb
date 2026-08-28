module AccountEmailPreviews
  extend ActiveSupport::Concern

  included do
    helper_method :account_email_preview_available?, :account_email_preview_retryable?,
      :account_email_preview_opened?, :account_email_preview_notice_id
  end

  private

  def capture_account_email_preview(user, newly_registered: false)
    return unless AccountEmailPreview.enabled? && user.persisted? && user.user? && user.account_email_preview_message

    if newly_registered
      clear_account_email_preview
      session[:account_email_preview_owner] = {
        "id" => user.id, "email" => user.email,
        "expires_at" => AccountEmailPreview::LIFETIME.from_now.to_i
      }
    end

    owner = account_email_preview_owner
    return unless owner && owner["id"] == user.id && owner["email"] == user.email

    AccountEmailPreview.delete(session[:account_email_preview_key])
    session[:account_email_preview_key] = AccountEmailPreview.write(
      user.account_email_preview_message, expires_at: Time.at(owner["expires_at"])
    )
    session.delete(:account_email_preview_opened_key)
  end

  def account_email_preview_owner
    return unless AccountEmailPreview.enabled?

    owner = session[:account_email_preview_owner]
    return unless owner && owner["expires_at"].to_i > Time.current.to_i
    return if current_user && (current_user.id != owner["id"] || !current_user.user?)

    owner
  end

  def account_email_preview_available?
    account_email_preview_owner && AccountEmailPreview.read(session[:account_email_preview_key]).present?
  end

  def account_email_preview_retryable?
    account_email_preview_owner.present?
  end

  def account_email_preview_opened?
    account_email_preview_owner && session[:account_email_preview_key].present? &&
      session[:account_email_preview_opened_key] == session[:account_email_preview_key]
  end

  def account_email_preview_notice_id
    key = session[:account_email_preview_key]
    Digest::SHA256.hexdigest(key) if account_email_preview_owner && key.present?
  end

  def clear_account_email_preview
    AccountEmailPreview.delete(session.delete(:account_email_preview_key))
    session.delete(:account_email_preview_owner)
    session.delete(:account_email_preview_opened_key)
  end
end
