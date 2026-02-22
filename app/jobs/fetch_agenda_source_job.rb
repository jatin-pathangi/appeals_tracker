# Fetches all agenda PDFs for a single AgendaSource and processes them
# through Gemini. Kicked off by ScheduleWeeklyFetchJob.
class FetchAgendaSourceJob < ApplicationJob
  queue_as :fetchers

  def perform(agenda_source_id)
    source = AgendaSource.find(agenda_source_id)
    fetcher = source.fetcher

    Rails.logger.info "[FetchAgendaSourceJob] Starting fetch for #{source.city.name} (AgendaSource ##{source.id})"
    meetings = fetcher.fetch
    Rails.logger.info "[FetchAgendaSourceJob] Done. #{meetings.count} meeting(s) updated for #{source.city.name}"
  rescue => e
    Rails.logger.error "[FetchAgendaSourceJob] Failed for AgendaSource ##{agenda_source_id}: #{e.message}"
    raise # re-raise so SolidQueue marks it as failed and can retry
  end
end
