class HealthController < ApplicationController
  def show
    ActiveRecord::Base.connection.select_value('SELECT 1')
    render json: { status: 'ok', database: 'available' }
  rescue ActiveRecord::ActiveRecordError
    render json: { status: 'unavailable', database: 'unavailable' }, status: :service_unavailable
  end
end
