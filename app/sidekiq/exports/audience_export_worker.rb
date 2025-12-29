# frozen_string_literal: true

EXPORT_TIMEOUT = 600.seconds

class Exports::AudienceExportWorker
  include Sidekiq::Job
  sidekiq_options retry: 5, queue: :low, lock: :until_executed

  def perform(seller_id, recipient_id, audience_options = {})
    seller, recipient = User.find(seller_id, recipient_id)
    recipient ||= seller

    WithMaxExecutionTime.timeout_queries(seconds: EXPORT_TIMEOUT) do
      @result = Exports::AudienceExportService.new(seller, audience_options).perform
    end

    ContactingCreatorMailer.subscribers_data(
      recipient:,
      tempfile: @result.tempfile,
      filename: @result.filename,
      ).deliver_now
  end
end
