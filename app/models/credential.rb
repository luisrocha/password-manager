class Credential < ApplicationRecord
  CATEGORIES = %w[login note api_key server database].freeze
  BROADCAST_STREAM = "credentials"

  validates :name, length: { maximum: 255 }
  validates :category, inclusion: { in: CATEGORIES }
  validates :encrypted_secret_payload, presence: true

  after_commit :broadcast_credentials_index

  scope :sorted, -> { order(:name, :domain) }

  def self.search(term)
    return sorted if term.blank?

    query = "%#{sanitize_sql_like(term.strip)}%"
    where("name LIKE :q OR domain LIKE :q", q: query).sorted
  end

  def self.broadcast_stream_name
    BROADCAST_STREAM
  end

  private

  def broadcast_credentials_index
    Turbo::StreamsChannel.broadcast_replace_to(
      self.class.broadcast_stream_name,
      target: "credentials_index",
      partial: "credentials/index_list",
      locals: { credentials: self.class.sorted }
    )
  end
end
