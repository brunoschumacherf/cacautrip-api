require 'marcel'

class ProfilePhotosController < ApplicationController
  before_action :authenticate_user!, only: %i[update destroy]

  def update
    upload = params[:photo]
    return render_error('Escolha uma foto JPG, PNG ou WebP.') unless upload.is_a?(ActionDispatch::Http::UploadedFile)
    return render_error('A foto deve ter no máximo 2 MB.', :payload_too_large) if upload.size > ProfilePhoto::MAX_BYTES
    type = Marcel::MimeType.for(upload.tempfile)
    return render_error('Escolha uma foto JPG, PNG ou WebP.') unless ProfilePhoto::TYPES.include?(type)
    upload.tempfile.rewind
    bytes = upload.tempfile.read(ProfilePhoto::MAX_BYTES + 1)
    @current_user.with_lock do
      photo = @current_user.profile_photo || @current_user.build_profile_photo
      photo.update!(image_data: bytes, content_type: type, version: SecureRandom.uuid)
    end
    render json: @current_user.public_profile
  end

  def destroy
    @current_user.with_lock { @current_user.profile_photo&.destroy! }
    render json: @current_user.public_profile
  end

  def show
    photo = ProfilePhoto.find_signed(params[:id], purpose: 'profile_photo')
    return head :not_found unless photo && photo.version == params[:version] && !photo.user.suspended?
    response.headers['X-Content-Type-Options'] = 'nosniff'
    response.headers['Cache-Control'] = 'private, max-age=300'
    send_data photo.image_data, type: photo.content_type, disposition: 'inline', filename: 'profile-photo'
  end
end
