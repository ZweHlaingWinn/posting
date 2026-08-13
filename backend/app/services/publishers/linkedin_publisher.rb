module Publishers
  # LinkedIn adapter.
  #
  # Auth: OAuth 2.0, credentials in LINKEDIN_CLIENT_ID/SECRET.
  # Publishing: POST /rest/posts with an author URN. Images and video go through
  # the assets registration flow first.
  # Metrics: the socialActions and organizationalEntityShareStatistics endpoints.
  #
  # Not implemented yet - awaiting credentials and the live API contract.
  class LinkedinPublisher < Base
    def self.implemented?
      false
    end
  end
end
