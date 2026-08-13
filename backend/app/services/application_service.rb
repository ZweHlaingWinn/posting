# Base class for all service objects.
#
# Every service exposes a single public `#call` returning a ServiceResult, and
# keeps its collaborators in the constructor. Controllers instantiate and call;
# they never branch on domain rules themselves.
class ApplicationService
  def self.call(...)
    new(...).call
  end

  def call
    raise NotImplementedError, "#{self.class} must implement #call"
  end

  private

  def success(data: {}, status: :ok)
    ServiceResult.success(data: data, status: status)
  end

  def failure(errors:, status: :unprocessable_entity)
    ServiceResult.failure(errors: errors, status: status)
  end
end
