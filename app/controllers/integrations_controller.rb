class IntegrationsController < ApplicationController
  before_action :cors_preflight_check, only: :index

  def show
    begin
      render json: Integration.find(params[:id])
    rescue Integration::NotFound => e
      render json: { error: e.message }, status: :not_found
    end
  end

  def index
    integrations = Integration.public_integrations
    event_types = Integration.supported_event_types
    render json: { event_types: event_types, integrations: integrations }
  end
end
