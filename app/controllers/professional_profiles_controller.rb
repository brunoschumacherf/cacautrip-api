class ProfessionalProfilesController < ApplicationController
  def create_guide
    user = User.find_by(id: params[:user_id])
    return render json: { error: "Usuário não encontrado" }, status: :not_found unless user

    user.update(gov_verified: true)

    guide_profile = user.guide_profile || user.build_guide_profile
    guide_profile.assign_attributes(
      specialization: params[:specialization],
      languages: params[:languages],
      subscription_plan: params[:subscription_plan] || "free",
      verified_documents: true
    )

    if guide_profile.save
      render json: { 
        message: "Perfil de Guia ativado com sucesso via Gov.br (Mock)", 
        user: { id: user.id, name: user.name, gov_verified: user.gov_verified },
        guide_profile: guide_profile 
      }, status: :created
    else
      render json: { errors: guide_profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def create_driver
    user = User.find_by(id: params[:user_id])
    return render json: { error: "Usuário não encontrado" }, status: :not_found unless user

    user.update(gov_verified: true)

    driver_profile = user.driver_profile || user.build_driver_profile
    driver_profile.assign_attributes(
      vehicle_model: params[:vehicle_model],
      license_plate: params[:license_plate],
      capacity: params[:capacity],
      subscription_plan: params[:subscription_plan] || "free",
      verified_cnh: true
    )

    if driver_profile.save
      render json: { 
        message: "Perfil de Motorista ativado com sucesso via Gov.br (Mock)", 
        user: { id: user.id, name: user.name, gov_verified: user.gov_verified },
        driver_profile: driver_profile 
      }, status: :created
    else
      render json: { errors: driver_profile.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /professional_profiles/guides
  def index_guides
    guides = GuideProfile.includes(:user).all
    render json: guides.map { |g| {
      id: g.id,
      user_id: g.user.id,
      name: g.user.name,
      specialization: g.specialization,
      languages: g.languages,
      subscription_plan: g.subscription_plan,
      verified: g.verified_documents
    }}, status: :ok
  end

  # GET /professional_profiles/drivers
  def index_drivers
    drivers = DriverProfile.includes(:user).all
    render json: drivers.map { |d| {
      id: d.id,
      user_id: d.user.id,
      name: d.user.name,
      vehicle_model: d.vehicle_model,
      license_plate: d.license_plate,
      capacity: d.capacity,
      subscription_plan: d.subscription_plan,
      verified: d.verified_cnh
    }}, status: :ok
  end
end