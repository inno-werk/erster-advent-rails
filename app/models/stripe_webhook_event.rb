class StripeWebhookEvent < ApplicationRecord
  enum :status, { received: "received", processed: "processed", failed: "failed" }, validate: true

  validates :stripe_event_id, :event_type, presence: true
  validates :stripe_event_id, uniqueness: true
end
