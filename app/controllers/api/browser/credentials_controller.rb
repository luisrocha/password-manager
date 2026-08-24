# frozen_string_literal: true

require 'uri'

class Api::Browser::CredentialsController < Api::BaseController
  def search
    hosts = extract_hosts
    query = search_query
    credentials = matching_credentials(hosts, query)

    render json: {
      credentials: credentials.map { |credential| credential_metadata(credential) }
    }
  end

  def create
    credential = Credential.new(
      name: browser_credential_name,
      domain: browser_credential_domain,
      encrypted_secret_payload: encrypted_secret_payload(credential_create_params),
      category: 'login'
    )

    if credential.save
      render json: {
        credential: credential_metadata(credential)
      }, status: :created
    else
      render json: {
        error: credential.errors.full_messages.to_sentence,
        code: 'validation_failed'
      }, status: :unprocessable_entity
    end
  end

  def show
    credential = Credential.find(params[:id])

    render json: {
      credential: credential_metadata(credential)
    }
  end

  def update
    credential = Credential.find(params[:id])

    attributes = {
      name: credential_update_name.presence || credential.name
    }
    if encrypted_secret_payload(credential_update_params).present?
      attributes[:encrypted_secret_payload] =
        encrypted_secret_payload(credential_update_params)
    end

    if credential.update(attributes)
      render json: {
        credential: credential_metadata(credential)
      }
    else
      render json: {
        error: credential.errors.full_messages.to_sentence,
        code: 'validation_failed'
      }, status: :unprocessable_entity
    end
  end

  def destroy
    credential = Credential.find(params[:id])
    credential.destroy

    render json: {
      credential: credential_metadata(credential)
    }
  end

  private

  def credential_create_params
    params.permit(:name, :displayName, :domain, :origin, :url, :frameUrl, :frame_url, :title,
                  :encrypted_secret_payload, :encryptedSecretPayload)
  end

  def credential_update_params
    params.permit(:name, :displayName, :encrypted_secret_payload, :encryptedSecretPayload)
  end

  def extract_hosts
    %i[origin url frameUrl frame_url].filter_map do |key|
      host_from_url(params[key])
    end.uniq
  end

  def matching_credentials(hosts, query)
    base_scope = if hosts.empty?
                   query.present? ? Credential.all : Credential.none
                 else
                   host_filtered_scope(hosts)
                 end

    return base_scope.sorted.to_a if query.blank?

    query_filtered_credentials(base_scope, query)
  end

  def host_matches?(host, domain)
    host == domain || host.end_with?(".#{domain}") || domain.end_with?(".#{host}")
  end

  def host_from_url(value)
    raw = value.to_s.strip
    return nil if raw.blank?

    normalized = raw.match?(%r{\A[a-z][a-z0-9+\-.]*://}i) ? raw : "https://#{raw}"
    uri = URI.parse(normalized)
    uri.host&.downcase
  rescue URI::InvalidURIError
    nil
  end

  def search_query
    params[:query].to_s.strip
  end

  def browser_credential_name
    credential_create_params[:name].to_s.strip.presence ||
      credential_create_params[:displayName].to_s.strip.presence ||
      credential_create_params[:title].to_s.strip.presence ||
      browser_credential_domain.presence ||
      'Website Login'
  end

  def credential_update_name
    credential_update_params[:name].to_s.strip.presence ||
      credential_update_params[:displayName].to_s.strip.presence
  end

  def browser_credential_domain
    credential_create_params[:domain].to_s.strip.presence ||
      extract_hosts.first.to_s.strip.presence
  end

  def host_filtered_scope(hosts)
    normalized_hosts = hosts.map(&:downcase).uniq
    return Credential.none if normalized_hosts.empty?

    sql_parts = []
    sql_params = {}

    normalized_hosts.each_with_index do |host, index|
      sql_parts << <<~SQL.squish
        (LOWER(domain) = :eq_#{index}
         OR LOWER(domain) LIKE :sub_#{index}
         OR :host_#{index} LIKE ('%.' || LOWER(domain)))
      SQL
      sql_params[:"eq_#{index}"] = host
      sql_params[:"sub_#{index}"] = "%.#{host}"
      sql_params[:"host_#{index}"] = host
    end

    fast_scope = Credential.where.not(domain: [nil, ''])
                           .where(sql_parts.join(' OR '), sql_params)

    # Fallback for credentials stored as full URLs or paths instead of bare domains.
    irregular_ids = Credential.where.not(domain: [nil, ''])
                              .where(
                                "domain LIKE '%://%' OR domain LIKE '%/%' OR domain LIKE '%?%' OR domain LIKE '%#%'"
                              )
                              .find_each(batch_size: 200)
                              .filter_map do |credential|
                                domain_host = host_from_url(credential.domain)
                                credential.id if domain_host.present? && normalized_hosts.any? do |host|
                                  host_matches?(host, domain_host)
                                end
                              end

    return fast_scope if irregular_ids.empty?

    fast_scope.or(Credential.where(id: irregular_ids))
  end

  def query_filtered_credentials(base_scope, query)
    normalized_query = query.downcase
    sql_query = "%#{ActiveRecord::Base.sanitize_sql_like(normalized_query)}%"

    sql_name_domain_scope = base_scope.where(
      'LOWER(name) LIKE :q OR LOWER(domain) LIKE :q',
      q: sql_query
    )
    sql_name_domain_ids = sql_name_domain_scope.pluck(:id)

    Credential.where(id: sql_name_domain_ids).sorted.to_a
  end

  def credential_metadata(credential)
    CredentialSerializer.new(credential).as_json
  end

  def encrypted_secret_payload(permitted_params)
    permitted_params[:encrypted_secret_payload].presence || permitted_params[:encryptedSecretPayload].presence
  end
end
