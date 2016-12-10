# frozen_string_literal: true
require 'integrations'
require 'payload_validator'

class EventsController < ApplicationController
  SIGNING_KEY = ENV.fetch('INTEGRATIONS_SIGNING_KEY').freeze
  EVENTS = YAML.load(File.read(Rails.root.join('data', 'events.yml'))).freeze

  before_action :verify_signature, only: [:create]

  def index
    render json: EVENTS
  end

  def create
    begin
      body = MultiJson.load(body_string, symbolize_keys: true)
      unless %i(event_type integrations payload oauth_consumer).all? { |key| body.key? key }
        return invalid_request
      end
      Integrations.send_event(body)
      render json: { status: 'ok' }, status: :created
    rescue MultiJson::ParseError
      invalid_request('unable to parse request', type: 'parse_error')
    rescue Integrations::Error => e
      format_integration_error(e)
    rescue PayloadValidator::InvalidPayloadError => e
      invalid_request e.message, type: 'invalid payload'
    end
  end

  private

  def invalid_request(message = 'invalid request', type: 'invalid_request')
    render json: { error: message, type: type }, status: 400
  end

  def format_integration_error(exception)
    exception_info = {
      error: exception.message,
      type: exception.type,
      failed_response_body: exception.response_body,
      failed_response_code: exception.response_code,
    }
    render json: exception_info, status: 400
  end

  def verify_signature
    return true if Rails.env.development?

    digest = OpenSSL::Digest.new('sha256')
    hmac = OpenSSL::HMAC.hexdigest(digest, SIGNING_KEY, body_string)

    unless request.headers['X-SIGNATURE'] == hmac
      render json: { status: 'unauthorized' }, status: :unauthorized
    end
  end

  # Returns the body POST data as a string
  def body_string
    body = request.body
    body.rewind # Since this is a StringIO and we access it twice, rewind it
    body.read
  rescue RuntimeError => exception
    # Rails 4.2 with Ruby 2.3 raises "RuntimeError: can't modify frozen String"
    # when trying to access request.body with invalid JSON. Fallback to header.
    request.headers["RAW_POST_DATA"]
  end
end
