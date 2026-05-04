require "uri"

class Api::Browser::CredentialsController < Api::BaseController
  def search
    hosts = extract_hosts
    query = search_query
    credentials = matching_credentials(hosts, query)

    render json: {
      credentials: credentials.map do |credential|
        {
          id: credential.id.to_s,
          displayName: credential.name,
          domain: credential.domain.to_s,
          username: credential.username.to_s,
          password: credential.password.to_s
        }
      end
    }
  end

  def create
    if credential_create_params[:password].to_s.empty?
      render json: {
        error: "Password can't be blank",
        code: "validation_failed"
      }, status: :unprocessable_entity
      return
    end

    credential = Credential.new(
      name: browser_credential_name,
      domain: browser_credential_domain,
      username: credential_create_params[:username].to_s.strip,
      password: credential_create_params[:password].to_s,
      notes: credential_create_params[:notes].to_s.strip.presence,
      category: "login"
    )

    if credential.save
      render json: {
        credential: {
          id: credential.id.to_s,
          displayName: credential.name,
          domain: credential.domain.to_s,
          username: credential.username.to_s
        }
      }, status: :created
    else
      render json: {
        error: credential.errors.full_messages.to_sentence,
        code: "validation_failed"
      }, status: :unprocessable_entity
    end
  end

  def update
    credential = Credential.find(params[:id])

    if credential_update_params[:password].to_s.empty?
      render json: {
        error: "Password can't be blank",
        code: "validation_failed"
      }, status: :unprocessable_entity
      return
    end

    if credential.update(
      username: credential_update_params[:username].to_s.strip,
      password: credential_update_params[:password].to_s,
      notes: credential_update_params[:notes].to_s.strip.presence
    )
      render json: {
        credential: {
          id: credential.id.to_s,
          displayName: credential.name,
          domain: credential.domain.to_s,
          username: credential.username.to_s
        }
      }
    else
      render json: {
        error: credential.errors.full_messages.to_sentence,
        code: "validation_failed"
      }, status: :unprocessable_entity
    end
  end

  def destroy
    credential = Credential.find(params[:id])
    credential.destroy

    render json: {
      credential: {
        id: credential.id.to_s,
        displayName: credential.name,
        domain: credential.domain.to_s,
        username: credential.username.to_s
      }
    }
  end

  private

  def credential_create_params
    params.permit(:name, :displayName, :domain, :origin, :url, :frameUrl, :frame_url, :title, :username, :password, :notes)
  end

  def credential_update_params
    params.permit(:username, :password, :notes)
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

    normalized = raw.match?(/\A[a-z][a-z0-9+\-.]*:\/\//i) ? raw : "https://#{raw}"
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
      "Website Login"
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

    fast_scope = Credential.where.not(domain: [nil, ""])
      .where(sql_parts.join(" OR "), sql_params)

    # Fallback for credentials stored as full URLs or paths instead of bare domains.
    irregular_ids = Credential.where.not(domain: [nil, ""])
      .where("domain LIKE '%://%' OR domain LIKE '%/%' OR domain LIKE '%?%' OR domain LIKE '%#%'")
      .find_each(batch_size: 200)
      .filter_map do |credential|
        domain_host = host_from_url(credential.domain)
        credential.id if domain_host.present? && normalized_hosts.any? { |host| host_matches?(host, domain_host) }
      end

    return fast_scope if irregular_ids.empty?

    fast_scope.or(Credential.where(id: irregular_ids))
  end

  def query_filtered_credentials(base_scope, query)
    normalized_query = query.downcase
    sql_query = "%#{ActiveRecord::Base.sanitize_sql_like(normalized_query)}%"

    sql_name_domain_scope = base_scope.where(
      "LOWER(name) LIKE :q OR LOWER(domain) LIKE :q",
      q: sql_query
    )
    sql_name_domain_ids = sql_name_domain_scope.pluck(:id)

    username_ids = []
    base_scope.reorder(nil).where.not(id: sql_name_domain_ids).find_each(batch_size: 200) do |credential|
      username_ids << credential.id if credential.username.to_s.downcase.include?(normalized_query)
    end

    Credential.where(id: (sql_name_domain_ids + username_ids)).sorted.to_a
  end
end
