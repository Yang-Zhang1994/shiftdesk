module Api
  class SwapRequestsController < ApplicationController
    def index
      swaps = SwapRequest.joins(:shift).where(shifts: { location_id: location.id })
                         .includes(:from_employee, :to_employee, shift: :employee).order(:created_at)
      swaps = swaps.where(status: params[:status]) if params[:status].present?
      render json: swaps
    end

    def create
      shift = Shift.find(params[:shift_id])
      swap = SwapRequest.new(shift:, from_employee: shift.employee, to_employee: Employee.find(params[:to_employee_id]))
      if swap.save
        render json: swap, status: :created
      else
        render_errors(swap)
      end
    rescue ActiveRecord::RecordNotUnique
      render_errors("This shift already has a pending swap request.", status: :conflict)
    end

    def approve
      respond(SwapApproval.new(SwapRequest.find(params[:id])).approve(note: params[:note]))
    end

    def reject
      respond(SwapApproval.new(SwapRequest.find(params[:id])).reject(note: params[:note]))
    end

    private

    def respond(outcome)
      if outcome.ok
        render json: { swap: outcome.swap, warnings: outcome.warnings }
      else
        render json: { swap: outcome.swap, errors: outcome.errors }, status: :conflict
      end
    end
  end
end
