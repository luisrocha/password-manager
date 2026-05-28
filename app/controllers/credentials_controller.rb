class CredentialsController < ApplicationController
  before_action :set_credential, only: %i[edit update destroy]

  def index
    @query = params[:q].to_s
    @credentials = Credential.search(@query)
  end

  def new
    @credential = Credential.new(category: "login")
  end

  def edit; end

  def create
    @credential = Credential.new(credential_params)

    if @credential.save
      redirect_to credentials_path, notice: "Credential saved."
    else
      flash.now[:alert] = @credential.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  def import
    return if request.get?

    redirect_to import_credentials_path, alert: "CSV import must be encrypted in the browser before it can be stored."
  end

  def update
    if @credential.update(credential_params)
      redirect_to credentials_path, notice: "Credential updated."
    else
      flash.now[:alert] = @credential.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @credential.destroy
    redirect_to credentials_path, notice: "Credential deleted."
  end

  private

  def set_credential
    @credential = Credential.find(params[:id])
  end

  def credential_params
    params.require(:credential).permit(:name, :domain, :category, :encrypted_secret_payload)
  end
end
