# The web app reaches the API through Vite's proxy, but the Expo app (web preview on :8081, or a
# phone on the LAN) calls it directly, so those origins need CORS.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*ENV.fetch("CORS_ORIGINS", "http://localhost:8081").split(","))
    resource "/api/*", headers: :any, methods: %i[get post patch delete options]
  end
end
