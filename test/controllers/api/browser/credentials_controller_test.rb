# frozen_string_literal: true

require 'test_helper'

class Api::Browser::CredentialsControllerTest < ActionDispatch::IntegrationTest
  ENCRYPTED_PAYLOAD = "-----BEGIN PGP MESSAGE-----\napi-test-payload\n-----END PGP MESSAGE-----"
  UPDATED_PAYLOAD = "-----BEGIN PGP MESSAGE-----\nupdated-api-test-payload\n-----END PGP MESSAGE-----"

  setup do
    @previous_api_token_hashes = ENV.fetch('PASSWORD_MANAGER_API_TOKEN_SHA256_HASHES', nil)
    @auth_header = { 'Authorization' => "Bearer #{BrowserJwt.issue_encrypted_token[:token]}" }
  end

  teardown do
    restore_env('PASSWORD_MANAGER_API_TOKEN_SHA256_HASHES', @previous_api_token_hashes)
  end

  test 'returns encrypted credentials matching request host' do
    matching = Credential.create!(name: 'GitHub', domain: 'github.com', category: 'login',
                                  encrypted_secret_payload: ENCRYPTED_PAYLOAD)
    Credential.create!(name: 'Mail', domain: 'mail.example.com', category: 'login',
                       encrypted_secret_payload: ENCRYPTED_PAYLOAD)

    post '/api/browser/credentials/search',
         params: { origin: 'https://github.com', url: 'https://github.com/login' },
         headers: @auth_header,
         as: :json

    assert_response :success

    body = response.parsed_body
    assert_equal 1, body.fetch('credentials').size
    assert_equal matching.id.to_s, body.dig('credentials', 0, 'id')
    assert_equal 'GitHub', body.dig('credentials', 0, 'displayName')
    assert_equal 'github.com', body.dig('credentials', 0, 'domain')
    assert_equal ENCRYPTED_PAYLOAD, body.dig('credentials', 0, 'encryptedSecretPayload')
    assert_no_plaintext_secret_keys(body.dig('credentials', 0))
  end

  test 'matches parent domains from subdomains' do
    Credential.create!(name: 'Main Site', domain: 'example.com', category: 'login',
                       encrypted_secret_payload: ENCRYPTED_PAYLOAD)

    post '/api/browser/credentials/search',
         params: { url: 'https://auth.example.com/login' },
         headers: @auth_header,
         as: :json

    assert_response :success
    assert_equal 1, response.parsed_body.fetch('credentials').size
  end

  test 'returns multiple encrypted credentials for the same domain' do
    first = Credential.create!(name: 'GitHub Personal', domain: 'github.com', category: 'login',
                               encrypted_secret_payload: ENCRYPTED_PAYLOAD)
    second = Credential.create!(name: 'GitHub Work', domain: 'github.com', category: 'login',
                                encrypted_secret_payload: UPDATED_PAYLOAD)

    post '/api/browser/credentials/search',
         params: { origin: 'https://github.com' },
         headers: @auth_header,
         as: :json

    assert_response :success
    ids = response.parsed_body.fetch('credentials').map { |item| item.fetch('id') }
    assert_equal [first.id.to_s, second.id.to_s].sort, ids.sort
  end

  test 'supports global search by name and domain only' do
    github = Credential.create!(name: 'GitHub', domain: 'github.com', category: 'login',
                                encrypted_secret_payload: ENCRYPTED_PAYLOAD)
    gitlab = Credential.create!(name: 'GitLab', domain: 'gitlab.com', category: 'login',
                                encrypted_secret_payload: ENCRYPTED_PAYLOAD)
    Credential.create!(name: 'Mail', domain: 'mail.example.com', category: 'login',
                       encrypted_secret_payload: ENCRYPTED_PAYLOAD)

    post '/api/browser/credentials/search',
         params: { query: 'hub' },
         headers: @auth_header,
         as: :json
    assert_response :success
    assert_equal([github.id.to_s], response.parsed_body.fetch('credentials').map { |item| item.fetch('id') })

    post '/api/browser/credentials/search',
         params: { query: 'lab.com' },
         headers: @auth_header,
         as: :json
    assert_response :success
    assert_equal([gitlab.id.to_s], response.parsed_body.fetch('credentials').map { |item| item.fetch('id') })
  end

  test 'returns no credentials when host and query are both missing' do
    Credential.create!(name: 'GitHub', domain: 'github.com', category: 'login',
                       encrypted_secret_payload: ENCRYPTED_PAYLOAD)

    post '/api/browser/credentials/search',
         params: {},
         headers: @auth_header,
         as: :json

    assert_response :success
    assert_empty response.parsed_body.fetch('credentials')
  end

  test 'returns encrypted credential payload on show' do
    credential = Credential.create!(
      name: 'GitHub',
      domain: 'github.com',
      category: 'login',
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )

    get "/api/browser/credentials/#{credential.id}",
        headers: @auth_header,
        as: :json

    assert_response :success
    assert_equal credential.id.to_s, response.parsed_body.dig('credential', 'id')
    assert_equal ENCRYPTED_PAYLOAD, response.parsed_body.dig('credential', 'encryptedSecretPayload')
    assert_no_plaintext_secret_keys(response.parsed_body.fetch('credential'))
  end

  test 'returns unauthorized when browser token is missing' do
    post '/api/browser/credentials/search',
         params: { origin: 'https://github.com' },
         as: :json

    assert_response :unauthorized
    assert_equal 'invalid_token', response.parsed_body['code']
  end

  test 'returns unauthorized when browser token is expired' do
    expired_token = BrowserJwt.issue_encrypted_token(expires_in: -1)[:token]

    post '/api/browser/credentials/search',
         params: { origin: 'https://github.com' },
         headers: { 'Authorization' => "Bearer #{expired_token}" },
         as: :json

    assert_response :unauthorized
    assert_equal 'token_expired', response.parsed_body['code']
  end

  test 'rejects bootstrap bearer token for credential search' do
    ENV['PASSWORD_MANAGER_API_TOKEN_SHA256_HASHES'] = BrowserApiToken.sha256('test-token')

    post '/api/browser/credentials/search',
         params: { origin: 'https://github.com' },
         headers: { 'Authorization' => 'Bearer test-token' },
         as: :json

    assert_response :unauthorized
    assert_equal 'invalid_token', response.parsed_body['code']
  end

  test 'creates an encrypted credential from browser api data' do
    assert_difference('Credential.count', 1) do
      post '/api/browser/credentials',
           params: {
             origin: 'https://github.com',
             name: 'GitHub Personal',
             title: 'GitHub',
             username: 'ignored@example.com',
             password: 'ignored-secret',
             notes: 'ignored note',
             encryptedSecretPayload: ENCRYPTED_PAYLOAD
           },
           headers: @auth_header,
           as: :json
    end

    assert_response :created

    credential = Credential.order(:created_at).last
    assert_equal 'GitHub Personal', credential.name
    assert_equal 'github.com', credential.domain
    assert_equal ENCRYPTED_PAYLOAD, credential.encrypted_secret_payload
    assert_not credential.attributes.key?('username')
    assert_not credential.attributes.key?('password')
    assert_not credential.attributes.key?('notes')
    assert_no_plaintext_secret_keys(response.parsed_body.fetch('credential'))
  end

  test 'returns validation error when encrypted payload is missing during browser create' do
    post '/api/browser/credentials',
         params: {
           origin: 'https://github.com',
           username: 'ignored@example.com',
           password: 'ignored-secret'
         },
         headers: @auth_header,
         as: :json

    assert_response :unprocessable_entity
    assert_equal 'validation_failed', response.parsed_body['code']
  end

  test 'updates an encrypted credential from browser api data' do
    credential = Credential.create!(
      name: 'GitHub',
      domain: 'github.com',
      category: 'login',
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )

    patch "/api/browser/credentials/#{credential.id}",
          params: {
            name: 'GitHub Updated',
            username: 'ignored.updated@example.com',
            password: 'ignored-updated-secret',
            encryptedSecretPayload: UPDATED_PAYLOAD
          },
          headers: @auth_header,
          as: :json

    assert_response :success
    assert_equal 'GitHub Updated', credential.reload.name
    assert_equal UPDATED_PAYLOAD, credential.encrypted_secret_payload
    assert_no_plaintext_secret_keys(response.parsed_body.fetch('credential'))
  end

  test 'updates metadata without replacing encrypted payload' do
    credential = Credential.create!(
      name: 'GitHub',
      domain: 'github.com',
      category: 'login',
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )

    patch "/api/browser/credentials/#{credential.id}",
          params: { name: 'GitHub Updated' },
          headers: @auth_header,
          as: :json

    assert_response :success
    assert_equal 'GitHub Updated', credential.reload.name
    assert_equal ENCRYPTED_PAYLOAD, credential.encrypted_secret_payload
  end

  test 'deletes a credential from browser edit flow' do
    credential = Credential.create!(
      name: 'GitHub',
      domain: 'github.com',
      category: 'login',
      encrypted_secret_payload: ENCRYPTED_PAYLOAD
    )

    assert_difference('Credential.count', -1) do
      delete "/api/browser/credentials/#{credential.id}",
             headers: @auth_header,
             as: :json
    end

    assert_response :success
    assert_equal credential.id.to_s, response.parsed_body.dig('credential', 'id')
  end

  private

  def restore_env(key, value)
    value.nil? ? ENV.delete(key) : ENV[key] = value
  end

  def assert_no_plaintext_secret_keys(payload)
    assert_not payload.key?('username')
    assert_not payload.key?('password')
    assert_not payload.key?('notes')
  end
end
