class CredentialsController < ApplicationController
  before_action :set_credential, only: %i[edit update destroy]

  def index
    @query = params[:q].to_s
    @credentials = Credential.search(@query)
  end

  def edit; end

  def create
    @credential = Credential.new(credential_params)

    if @credential.save
      redirect_to credentials_path, notice: "Credential saved."
    else
      @query = ""
      @credentials = Credential.sorted
      flash.now[:alert] = @credential.errors.full_messages.to_sentence
      render :index, status: :unprocessable_entity
    end
  end

  def import
    upload = params[:file]
    if upload.blank?
      redirect_to credentials_path, alert: "Please choose a CSV file to import."
      return
    end

    result = OnePasswordImporter.new(upload).call

    if result.errors.empty?
      redirect_to credentials_path, notice: "Imported #{result.created_count} item(s)."
    else
      redirect_to credentials_path,
        alert: "Imported #{result.created_count} item(s) with errors: #{result.errors.first(5).join(' | ')}"
    end
  rescue ArgumentError => e
    redirect_to credentials_path, alert: e.message
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
    params.require(:credential).permit(:name, :domain, :username, :password, :notes, :category)
  end
end
