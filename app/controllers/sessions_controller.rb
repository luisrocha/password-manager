class SessionsController < ApplicationController
  skip_before_action :require_master_password, only: %i[new create]

  def new; end

  def create
    if MasterPassword.valid?(params[:master_password])
      session[:master_unlocked_at] = Time.current.to_i
      redirect_to credentials_path, notice: "Vault unlocked."
    else
      flash.now[:alert] = "Invalid master password."
      render :new, status: :unauthorized
    end
  end

  def destroy
    reset_session
    redirect_to unlock_path, notice: "Vault locked."
  end
end
