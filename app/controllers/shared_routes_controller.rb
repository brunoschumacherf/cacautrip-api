class SharedRoutesController < ApplicationController
  def show
    return render_error('Roteiro não encontrado', :not_found) if params[:token].blank?
    route = Route.find_by!(shared_token: params[:token])
    render json: { title: route.title, destination: route.destination, total_estimated_cost: route.total_estimated_cost,
      itinerary: route.preferences.to_h.fetch('itinerary', []), costs: route.preferences.to_h.fetch('costs', {}), warnings: route.preferences.to_h.fetch('warnings', []) }
  end
end
