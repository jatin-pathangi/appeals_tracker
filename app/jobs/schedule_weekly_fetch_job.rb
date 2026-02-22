# Orchestrator job run by SolidQueue's recurring scheduler every Sunday.
# Finds all active AgendaSources and enqueues a FetchAgendaSourceJob for each,
# so every city is fetched independently and failures are isolated.
class ScheduleWeeklyFetchJob < ApplicationJob
  queue_as :default

  def perform
    sources = AgendaSource.all
    Rails.logger.info "[ScheduleWeeklyFetchJob] Scheduling #{sources.count} city fetcher(s)"

    sources.each do |source|
      FetchAgendaSourceJob.perform_later(source.id)
      Rails.logger.info "[ScheduleWeeklyFetchJob] Enqueued FetchAgendaSourceJob for #{source.city.name}"
    end
  end
end
