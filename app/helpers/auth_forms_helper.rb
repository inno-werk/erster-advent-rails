module AuthFormsHelper
  REGISTRATION_ERROR_FIELDS = {
    business_name: [ :business_name, :"business.business_name" ],
    email: [ :email, :"business.email" ],
    address: [ :address, :"business.address", :"business.billing_address" ],
    name: [ :name, :"business.contact_name" ],
    password: [ :password, :password_confirmation ],
    phone: [ :phone, :"business.phone" ]
  }.freeze

  def auth_field_errors(resource, field)
    attributes = REGISTRATION_ERROR_FIELDS.fetch(field, [ field ])
    attributes.flat_map { |attribute| resource.errors.messages_for(attribute) }.uniq
  end

  def auth_input_options(field, errors:, extra_class: nil, hint: nil)
    {
      class: class_names("input input-bordered w-full", extra_class, "input-error" => errors.present?),
      aria: {
        invalid: errors.present? ? "true" : nil,
        describedby: [ hint, ("user_#{field}_error" if errors.present?) ].compact.join(" ").presence
      }
    }
  end

  def login_credentials_invalid?
    %i[invalid not_found_in_database last_attempt].include?(request.env.dig("warden.options", :message)&.to_sym)
  end
end
