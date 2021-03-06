class Artifact::Log < Artifact
  class << self
    # use job_id to avoid loading a log artifact into memory
    def append(job_id, chars)
      update_all(["content = COALESCE(content, '') || ?", chars], ["job_id = ?", job_id])
    end
  end
end

