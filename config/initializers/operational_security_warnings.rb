if Rails.env.production?
  Rails.application.config.after_initialize do
    OperationalSecurityWarnings.messages.each do |message|
      Rails.logger.warn("[security] #{message}")
    end
  end
end
