class Credential < ApplicationRecord
  CATEGORIES = %w[login note api_key server database].freeze

  validates :name, presence: true, length: { maximum: 255 }
  validates :domain, presence: true
  validates :category, inclusion: { in: CATEGORIES }
  validates :encrypted_secret_payload, presence: true

  scope :sorted, -> { order(:name, :domain) }

  def self.search(term)
    return sorted if term.blank?

    query = "%#{sanitize_sql_like(term.strip)}%"
    where("name LIKE :q OR domain LIKE :q", q: query).sorted
  end
end
