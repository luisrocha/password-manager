class Credential < ApplicationRecord
  encrypts :username
  encrypts :password
  encrypts :notes

  CATEGORIES = %w[login note api_key server database].freeze

  validates :name, presence: true, length: { maximum: 255 }
  validates :domain, length: { maximum: 255 }, allow_blank: true
  validates :category, inclusion: { in: CATEGORIES }

  scope :sorted, -> { order(:name, :domain) }

  def self.search(term)
    return sorted if term.blank?

    query = "%#{sanitize_sql_like(term.strip)}%"
    where("name LIKE :q OR domain LIKE :q", q: query).sorted
  end
end
