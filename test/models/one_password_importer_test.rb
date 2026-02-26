require "test_helper"

class OnePasswordImporterTest < ActiveSupport::TestCase
  test "imports rows from a 1password csv export" do
    file = file_fixture("1password.csv").open

    result = OnePasswordImporter.new(file).call

    assert_equal 2, result.created_count
    assert_empty result.errors
    assert_equal 2, Credential.count
    assert_equal ["GitHub", "Server SSH"], Credential.order(:name).pluck(:name)
  ensure
    file&.close
  end

  test "returns an error when required headers are missing" do
    file = Tempfile.new(["invalid", ".csv"])
    file.write("Website,Username\nexample.com,alice\n")
    file.rewind

    error = assert_raises(ArgumentError) { OnePasswordImporter.new(file).call }
    assert_match(/Missing required CSV headers/, error.message)
  ensure
    file.close
    file.unlink
  end
end
