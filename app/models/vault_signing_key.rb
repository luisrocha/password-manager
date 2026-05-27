class VaultSigningKey < ApplicationRecord
  validates :public_key_spki, presence: true

  def self.current
    order(:created_at).first
  end
end
