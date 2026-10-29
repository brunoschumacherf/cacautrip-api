class MapPointsController < ApplicationController
  def index
    kinds = params[:kinds].to_s.split(',')
    return render_error('Tipo de ponto inválido') unless (kinds - %w[destination trail collection partner guide driver emergency]).empty?
    render json: MapDirectory.new(params[:q], kinds: kinds).call
  end
end
