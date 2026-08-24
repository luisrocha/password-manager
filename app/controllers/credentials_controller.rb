# frozen_string_literal: true

class CredentialsController < ApplicationController
  include RateLimitResponse

  EXPORT_THROTTLE_LIMIT = ENV.fetch('PASSWORD_MANAGER_CREDENTIAL_EXPORT_THROTTLE_LIMIT', 10).to_i

  before_action :set_credential, only: %i[edit update destroy]
  rate_limit to: EXPORT_THROTTLE_LIMIT,
             within: 1.minute,
             only: :export,
             with: :render_rate_limit_response,
             name: 'credential_export'

  def index
    @query = params[:q].to_s
    @credentials = Credential.search(@query)
  end

  def new
    @credential = Credential.new(category: 'login')
  end

  def edit; end

  def create
    @credential = Credential.new(credential_params)

    if @credential.save
      redirect_to credentials_path, notice: 'Credential saved.'
    else
      flash.now[:alert] = @credential.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def import
    @totp_enabled = TotpSetting.enabled?
    return if request.get?

    if params[:encrypted_import] == '1'
      import_encrypted_credentials
      return
    end

    redirect_to import_credentials_path, alert: 'CSV import must be encrypted in the browser before it can be stored.'
  end

  def export
    if TotpSetting.enabled? && !TotpSetting.valid_second_factor_code?(params[:code])
      render json: { error: 'Two-factor code is invalid.', code: 'invalid_totp_code' }, status: :unauthorized
      return
    end

    render json: {
      credentials: Credential.sorted.map { |credential| CredentialSerializer.new(credential).sync_json }
    }
  end

  def update
    if @credential.update(credential_params)
      redirect_to credentials_path, notice: 'Credential updated.'
    else
      flash.now[:alert] = @credential.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @credential.destroy
    redirect_to credentials_path, notice: 'Credential deleted.'
  end

  private

  def set_credential
    @credential = Credential.find(params[:id])
  end

  def credential_params
    params.require(:credential).permit(:name, :domain, :category, :encrypted_secret_payload)
  end

  def import_encrypted_credentials
    credentials = encrypted_import_params.map { |attrs| Credential.new(attrs) }
    errors = credentials.each_with_index.filter_map do |credential, index|
      "Row #{index + 1}: #{credential.errors.full_messages.to_sentence}" unless credential.valid?
    end

    if credentials.empty?
      redirect_to import_credentials_path, alert: 'No encrypted credentials were submitted.'
    elsif errors.any?
      redirect_to import_credentials_path, alert: errors.to_sentence
    else
      Credential.transaction { credentials.each(&:save!) }
      redirect_to credentials_path, notice: "Imported #{credentials.count} credentials."
    end
  end

  def encrypted_import_params
    params.permit(credentials: %i[name domain category encrypted_secret_payload])
          .fetch(:credentials, {})
          .values
  end
end
