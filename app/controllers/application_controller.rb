class ApplicationController < ActionController::Base
  ALLOWED_ORIGINS = ENV.fetch('ALLOWED_ORIGINS').split(',').freeze
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  # protect_from_forgery with: :exception

  after_action :cors_set_access_control_headers

  def cors_set_access_control_headers
    headers['Access-Control-Allow-Origin'] = request.headers['HTTP_ORIGIN']
    headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, DELETE, OPTIONS'
    headers['Access-Control-Allow-Credentials'] = 'true'
  end

  def cors_preflight_check
    if request.method == 'OPTIONS'
      if ALLOWED_ORIGINS.include?(request.headers['HTTP_ORIGIN'])
        headers['Access-Control-Allow-Origin'] = request.headers['HTTP_ORIGIN']
        headers['Access-Control-Allow-Credentials'] = 'true'
        headers['Access-Control-Allow-Methods'] = 'POST, GET, PUT, DELETE, OPTIONS'
        headers['Access-Control-Allow-Headers'] = 'accept,content-type'
      end

      render :text => '', :content_type => 'text/plain'
    end
  end
end
