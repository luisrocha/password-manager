require "test_helper"
require "capybara/rails"
require "selenium/webdriver"

Selenium::WebDriver.logger.level = :warn

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  Capybara.default_max_wait_time = ENV.fetch("CAPYBARA_WAIT_TIME", 15).to_i

  DOWNLOADS_PATH = Rails.root.join("tmp/system_downloads")

  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1000] do |options|
    options.binary = ENV["CHROME_BIN"] if ENV["CHROME_BIN"].present?
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_preference(:download, default_directory: DOWNLOADS_PATH.to_s, prompt_for_download: false)
  end

  setup do
    FileUtils.mkdir_p(DOWNLOADS_PATH)
    FileUtils.rm_f(Dir[DOWNLOADS_PATH.join("*")])
  end
end
