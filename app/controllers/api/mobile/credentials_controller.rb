class Api::Mobile::CredentialsController < Api::Mobile::BaseController
  def sync
    render json: MobileCredentialSync.call(operations: sync_operations)
  end

  private

  def sync_operations
    return [] unless request.post?

    params.fetch(:operations, []).map(&:to_unsafe_h)
  end
end
