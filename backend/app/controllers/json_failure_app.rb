# Warden invokes this whenever authentication fails. Devise's default failure app
# assumes an HTML app and would redirect; this keeps the API's single error shape
# ({ "errors": [...] }) for 401s too.
class JsonFailureApp < Devise::FailureApp
  def respond
    self.status = 401
    self.content_type = "application/json"
    self.response_body = { errors: [i18n_message] }.to_json
  end
end
