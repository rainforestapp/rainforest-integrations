class IntegrationsController < ApplicationController
  def show
    begin
      render json: Integration.find(params[:id])
    rescue Integration::NotFound => e
      render json: { error: e.message }, status: :not_found
    end
  end

  def index
    render json: Integration.public_integrations
  end
end
