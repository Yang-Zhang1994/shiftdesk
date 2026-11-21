class Employee < ApplicationRecord
  ROLES = %w[cook cashier shift_lead].freeze

  belongs_to :location
  has_many :shifts, dependent: :restrict_with_error

  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, inclusion: { in: ROLES }
  validates :hourly_rate_cents, numericality: { only_integer: true, greater_than: 0 }

  def as_json(*)
    { id:, name:, email:, role:, hourly_rate_cents:, location_id: }
  end
end
