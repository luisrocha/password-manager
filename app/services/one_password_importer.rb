class OnePasswordImporter
  REQUIRED_HEADERS = ["title"].freeze
  HEADER_MAP = {
    "title" => :name,
    "name" => :name,
    "website" => :domain,
    "url" => :domain,
    "username" => :username,
    "password" => :password,
    "notes" => :notes,
    "category" => :category,
    "type" => :category
  }.freeze

  Result = Struct.new(:created_count, :errors, keyword_init: true)

  def initialize(file)
    @file = file
  end

  def call
    rows = parse_rows
    created_count = 0
    errors = []

    rows.each_with_index do |row, index|
      begin
        attrs = normalize(row)
        credential = Credential.new(attrs)

        if credential.save
          created_count += 1
        else
          errors << "Row #{index + 2}: #{credential.errors.full_messages.join(', ')}"
        end
      rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError => e
        errors << "Row #{index + 2}: invalid character encoding (#{e.message})"
      end
    end

    Result.new(created_count: created_count, errors: errors)
  rescue ArgumentError, RuntimeError => e
    Result.new(created_count: 0, errors: ["Malformed CSV: #{e.message}"])
  end

  private

  attr_reader :file

  def parse_rows
    content = normalize_text(file.read.to_s)
    rows = parse_csv(content)
    headers = rows.shift || []
    normalized_headers = headers.map { |h| normalize_header(h) }

    missing = REQUIRED_HEADERS - normalized_headers
    if missing.any?
      raise ArgumentError, "Missing required CSV headers: #{missing.join(', ')}"
    end

    mapped_rows = rows.map do |values|
      headers.each_with_index.to_h { |header, idx| [header, normalize_text(values[idx].to_s)] }
    end

    mapped_rows
  end

  def normalize(row)
    attrs = {
      name: nil,
      domain: nil,
      username: nil,
      password: nil,
      notes: nil,
      category: "login"
    }

    row.each_key do |header|
      key = HEADER_MAP[normalize_header(header)]
      next unless key

      value = normalize_text(row[header]).strip
      next if value.blank?

      attrs[key] = value
    end

    attrs[:category] = normalize_category(attrs[:category])
    attrs
  end

  def normalize_header(header)
    header.to_s.strip.downcase
  end

  def normalize_category(category)
    value = category.to_s.strip.downcase
    return "login" if value.blank?

    Credential::CATEGORIES.include?(value) ? value : "note"
  end

  def parse_csv(content)
    lines = content.split(/\r?\n/)
    lines.reject!(&:blank?)
    lines.map { |line| parse_csv_line(line) }
  end

  def parse_csv_line(line)
    values = []
    current = +""
    in_quotes = false
    i = 0

    while i < line.length
      char = line[i]

      if char == "\""
        if in_quotes && line[i + 1] == "\""
          current << "\""
          i += 1
        else
          in_quotes = !in_quotes
        end
      elsif char == "," && !in_quotes
        values << current
        current = +""
      else
        current << char
      end

      i += 1
    end

    values << current
    values
  end

  def normalize_text(value)
    text = value.to_s
    return "" if text.empty?

    utf8_text = text.dup.force_encoding(Encoding::UTF_8)
    return utf8_text.scrub if utf8_text.valid_encoding?

    latin1_text = text.dup.force_encoding(Encoding::ISO_8859_1).encode(Encoding::UTF_8)
    latin1_text.scrub
  rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
    text.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")
  end
end
