class ApplicationController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound do |e|
    render json: { errors: ["#{e.model || 'Record'} not found"] }, status: :not_found
  end

  private

  def location
    @location ||= Location.find(params[:location_id])
  end

  # Any date in the week works; the week starts on the Sunday before it.
  def week_start
    date = params[:week].present? ? Date.iso8601(params[:week]) : Time.current.in_time_zone(location.zone).to_date
    location.week_start_for(date)
  rescue Date::Error
    raise ActionController::BadRequest, "week must be a date like 2026-11-22"
  end

  def render_errors(record_or_messages, status: :unprocessable_content)
    errors = record_or_messages.respond_to?(:errors) ? record_or_messages.errors.full_messages : Array(record_or_messages)
    render json: { errors: }, status:
  end
end
