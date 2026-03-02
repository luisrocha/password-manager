require "uri"

class Api::Browser::CredentialsController < Api::BaseController
  def search
    hosts = extract_hosts
    credentials = hosts.empty? ? [] : matching_credentials(hosts)

    render json: {
      credentials: credentials.map do |credential|
        {
          id: credential.id.to_s,
          displayName: credential.name,
          username: credential.username.to_s,
          password: credential.password.to_s
        }
      end
    }
  end

  private

  def extract_hosts
    %i[origin url frameUrl frame_url].filter_map do |key|
      host_from_url(params[key])
    end.uniq
  end

  def matching_credentials(hosts)
    Credential.sorted.select do |credential|
      domain = host_from_url(credential.domain)
      domain.present? && hosts.any? { |host| host_matches?(host, domain) }
    end
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
end
