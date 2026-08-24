# frozen_string_literal: true

class Credential < ApplicationRecord
  CATEGORIES = %w[login note api_key server database].freeze
  BROADCAST_STREAM = 'credentials'

  validates :name, length: { maximum: 255 }
  validates :category, inclusion: { in: CATEGORIES }
  validates :encrypted_secret_payload, presence: true

  after_commit :broadcast_credentials_index_refresh

  scope :sorted, -> { order(:name, :domain) }

  def self.search(term)
    return sorted if term.blank?

    query = "%#{sanitize_sql_like(term.strip)}%"
    where('name LIKE :q OR domain LIKE :q', q: query).sorted
  end

  def self.broadcast_stream_name
    BROADCAST_STREAM
  end

  private

  def broadcast_credentials_index_refresh
    broadcast_action_to self.class.broadcast_stream_name,
                        action: :refresh_credentials,
                        target: 'credentials_index',
                        render: false
  end
end
