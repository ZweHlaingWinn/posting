# Uniform return value for every service object, so controllers never need to
# know how a service failed - only whether it did, and with what HTTP status.
class ServiceResult
  attr_reader :data, :errors, :status

  def self.success(data: {}, status: :ok)
    new(success: true, data: data, status: status)
  end

  def self.failure(errors:, status: :unprocessable_entity)
    new(success: false, errors: errors, status: status)
  end

  def initialize(success:, data: {}, errors: [], status: :ok)
    @success = success
    @data = data
    @errors = Array(errors)
    @status = status
  end

  def success?
    @success
  end

  def failure?
    !success?
  end
end
