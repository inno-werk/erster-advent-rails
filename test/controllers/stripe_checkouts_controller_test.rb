require "test_helper"
require "minitest/mock"

class StripeCheckoutsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @participation = participation_for
    sign_in users(:member)
  end

  test "configured Stripe checkout is offered in setup and dashboard payment pages" do
    EventConfiguration.stub(:dummy_payments_enabled?, false) do
      StripeConfiguration.stub(:ready?, true) do
        get app_setup_payment_path
        assert_response :success
        assert_select "form[action^=?][method=post][data-turbo=false]", app_stripe_checkout_path do
          assert_select "input[name=continue_setup][value=true]"
          assert_select "button[type=submit]", text: "Jetzt mit Stripe bezahlen"
        end

        get payment_app_participation_path
        assert_response :success
        assert_select "form[action^=?][method=post][data-turbo=false]", app_stripe_checkout_path do
          assert_select "button[type=submit]", text: "Mit Stripe bezahlen"
        end
      end
    end
  end

  test "checkout derives the obligation from the signed-in user and redirects to Stripe" do
    captured = nil
    creator = Object.new
    creator.define_singleton_method(:call) do
      StripeCheckoutSessionCreator::Result.new(payment: nil, url: "https://checkout.stripe.test/session")
    end
    factory = lambda do |**arguments|
      captured = arguments
      creator
    end

    StripeConfiguration.stub(:ready?, true) do
      StripeCheckoutSessionCreator.stub(:new, factory) do
        post app_stripe_checkout_path, params: { continue_setup: true, amount_cents: 1, participation_id: users(:other).id }
      end
    end

    assert_response :see_other
    assert_redirected_to "https://checkout.stripe.test/session"
    assert_equal @participation, captured[:participation]
    assert_includes captured[:success_url], "session_id={CHECKOUT_SESSION_ID}"
    assert_equal app_setup_payment_url, captured[:cancel_url]
    assert @participation.reload.pending?
  end

  test "Checkout return reports processing without trusting the browser redirect" do
    payment = StripePayment.create!(
      participation: @participation, payment_kind: :initial, obligation_key: "participation:#{@participation.id}",
      attempt: 1, amount_cents: @participation.amount_cents, idempotency_key: "return-test",
      status: :checkout_created, checkout_session_id: "cs_return_test"
    )

    get payment_app_participation_path, params: { status: "success", session_id: payment.checkout_session_id }

    assert_response :success
    assert_select ".alert-info", text: /Stripe verarbeitet Ihre Zahlung noch/
    assert @participation.reload.pending?

    get payment_app_participation_path, params: { status: "success", session_id: "cs_foreign" }
    assert_select ".alert-info", text: /Stripe verarbeitet Ihre Zahlung noch/, count: 0
  end
end
