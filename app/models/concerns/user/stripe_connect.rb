# frozen_string_literal: true

module User::StripeConnect
  extend ActiveSupport::Concern

  class_methods do
    def get_user_by_stripe_connect_account_uid(uid)
      MerchantAccount.where(charge_processor_merchant_id: uid).alive
          .find { |ma| ma.is_a_stripe_connect_account? }&.user
    end

    def find_or_create_for_stripe_connect_account(data, stripe_disable_signup: false)
      return nil if data.blank?

      user = get_user_by_stripe_connect_account_uid(data["uid"])

      if user.nil?
        return :stripe_signup_disabled if stripe_disable_signup

        ActiveRecord::Base.transaction do
          user = User.new
          user.provider = :stripe_connect
          email = data["info"]["email"]
          user.email = email if EmailFormatValidator.valid?(email)
          user.name = data["info"]["name"]
          user.password = Devise.friendly_token[0, 20]
          user.skip_confirmation!
          user.save!
          user.user_compliance_infos.build.tap do |new_user_compliance_info|
            new_user_compliance_info.country = Compliance::Countries.mapping[data["extra"]["extra_info"]["country"]]
            new_user_compliance_info.json_data = {}
            new_user_compliance_info.save!
          end
          if user.email.present?
            Purchase.where(email: user.email, purchaser_id: nil).each do |past_purchase|
              past_purchase.attach_to_user_and_card(user, nil, nil)
            end
          end
        end
      end

      user

    rescue ActiveRecord::RecordInvalid => e
      logger.error("Error creating user via Stripe Connect: #{e.message}") unless e.message.include?("An account already exists with this email.")
      nil
    end
  end

  def has_brazilian_stripe_connect_account?
    !!merchant_account(StripeChargeProcessor.charge_processor_id)&.is_a_brazilian_stripe_connect_account?
  end
end
