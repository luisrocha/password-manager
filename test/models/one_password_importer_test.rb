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

    result = OnePasswordImporter.new(file).call
    assert_equal 0, result.created_count
    assert_match(/Missing required CSV headers/, result.errors.first)
  ensure
    file.close
    file.unlink
  end

  test "handles binary encoded csv content without crashing" do
    file = Tempfile.new(["binary-encoded", ".csv"])
    # Includes invalid UTF-8 bytes in password/notes columns.
    binary_csv = "Title,Website,Username,Password,Notes\n" \
      "Conta,example.com,alice,abc\xC3\x28,ol\xE9\n".b
    file.binmode
    file.write(binary_csv)
    file.rewind

    result = OnePasswordImporter.new(file).call

    assert_equal 1, result.created_count
    assert_empty result.errors
    assert_equal 1, Credential.count
    assert_equal "Conta", Credential.first.name
  ensure
    file&.close
    file&.unlink
  end
end
