# frozen_string_literal: true

FactoryBot.define do
  factory :credential do
    name { FFaker::Product.product_name }
    domain { FFaker::Internet.domain_name }
    category { 'login' }
    encrypted_secret_payload { "-----BEGIN PGP MESSAGE-----\nplaceholder\n-----END PGP MESSAGE-----" }
  end
end
