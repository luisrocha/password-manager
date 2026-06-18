class MobileCredentialSync
  def self.call(operations: [])
    new(operations:).call
  end

  def initialize(operations: [])
    @operations = operations.map(&:to_h)
  end

  def call
    {
      operations: apply_pending_operations,
      credentials: Credential.sorted.map { |credential| credential_payload(credential) },
      syncedAt: Time.current.iso8601
    }
  end

  private

  attr_reader :operations

  def credential_payload(credential)
    CredentialSerializer.new(credential).sync_json
  end

  def apply_pending_operations
    operations.map { |operation| apply_pending_operation(operation) }
  end

  def apply_pending_operation(operation)
    case operation["type"]
    when "create"
      create_credential_from_operation(operation)
    when "update"
      update_credential_from_operation(operation)
    when "delete"
      delete_credential_from_operation(operation)
    else
      operation_result(operation, "failed", code: "invalid_operation_type")
    end
  end

  def create_credential_from_operation(operation)
    credential = create_idempotent_credential(operation)

    operation_result(operation, "confirmed", credential:)
  rescue ActiveRecord::RecordInvalid, KeyError
    operation_result(operation, "failed", code: "invalid_credential")
  end

  def create_idempotent_credential(operation)
    attributes = credential_attributes(operation.fetch("credential", {}))
    client_uid = operation["localId"].presence
    return Credential.create!(attributes) if client_uid.blank?

    Credential.create_or_find_by!(client_uid:) do |credential|
      credential.assign_attributes(attributes)
    end
  end

  def update_credential_from_operation(operation)
    credential = find_operation_credential(operation)
    return operation_result(operation, "failed", code: "credential_missing") if credential.blank?
    return operation_result(operation, "conflict", credential:) unless operation_based_on_current_version?(credential, operation)

    credential.update!(credential_attributes(operation.fetch("credential", {})))
    operation_result(operation, "confirmed", credential:)
  rescue ActiveRecord::RecordInvalid, KeyError
    operation_result(operation, "failed", code: "invalid_credential")
  end

  def delete_credential_from_operation(operation)
    credential = find_operation_credential(operation)
    return operation_result(operation, "confirmed") if credential.blank?
    return operation_result(operation, "conflict", credential:) unless operation_based_on_current_version?(credential, operation)

    credential.destroy!
    operation_result(operation, "confirmed")
  end

  def find_operation_credential(operation)
    server_id = operation["serverId"].presence
    return if server_id.blank?

    Credential.find_by(id: server_id)
  end

  def operation_based_on_current_version?(credential, operation)
    operation["baseUpdatedAt"].to_s == credential.updated_at.iso8601
  end

  def credential_attributes(raw_attributes)
    attributes = raw_attributes.to_h

    {
      name: attributes["displayName"].to_s,
      domain: attributes["domain"].to_s,
      category: attributes["category"].presence || "login",
      encrypted_secret_payload: attributes.fetch("encryptedSecretPayload")
    }
  end

  def operation_result(operation, status, code: nil, credential: nil)
    {
      id: operation["id"].to_s,
      localId: operation["localId"].to_s,
      serverId: credential&.id&.to_s || operation["serverId"],
      status:,
      code:,
      credential: credential && credential_payload(credential)
    }.compact
  end
end
