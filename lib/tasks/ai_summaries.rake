namespace :ai_summaries do
  desc "Show summary queue, delivery, and budget status"
  task status: :environment do
    AiSummary::AdminStatus.call.each do |key, value|
      next if key == :recent_failures
      puts "#{key}: #{value}"
    end
  end

  desc "Flush eligible summary work"
  task flush: :environment do
    AiSummary::AdminOperations.flush!
    puts "Flush job enqueued."
  end

  desc "Preview automatic summary candidates without creating work"
  task preview: :environment do
    result = AiSummary::AdminOperations.preview
    puts "candidates: #{result.candidate_count}"
    puts "considered: #{result.considered_count}"
    puts "eligible: #{result.eligible_count}"
    puts "capped: #{result.capped}"
  end

  desc "Run automatic topic-summary scheduling"
  task schedule: :environment do
    AiSummary::AdminOperations.schedule!
    puts "Automatic scheduling job enqueued."
  end

  desc "Retry a terminally failed generation (GENERATION_ID required)"
  task retry: :environment do
    AiSummary::AdminOperations.retry!(TopicSummaryGeneration.find(ENV.fetch("GENERATION_ID")))
  end

  desc "Cancel queued work (GENERATION_ID required)"
  task cancel: :environment do
    AiSummary::AdminOperations.cancel!(TopicSummaryGeneration.find(ENV.fetch("GENERATION_ID")))
  end

  desc "Remove a public summary (SUMMARY_ID required)"
  task remove: :environment do
    AiSummary::AdminOperations.remove!(TopicSummary.find(ENV.fetch("SUMMARY_ID")))
  end

  desc "Queue topic regeneration (TOPIC_ID required)"
  task regenerate: :environment do
    generation = AiSummary::AdminOperations.regenerate!(Topic.find(ENV.fetch("TOPIC_ID")))
    puts "Generation #{generation.id} queued."
  end

  desc "Pause automatic summary scheduling at runtime"
  task pause_automation: :environment do
    AiSummary::OperationalState.pause_automation!
  end

  desc "Pause provider submissions at runtime"
  task pause_submissions: :environment do
    AiSummary::OperationalState.pause_submissions!
  end
end
