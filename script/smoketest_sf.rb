#!/usr/bin/env ruby
# frozen_string_literal: true

#
# Smoke test: fetches one page of SF BOS agendas, downloads PDFs, runs Gemini
# extraction, and prints a summary of what was found.
#
# Usage:
#   bin/rails runner script/smoketest_sf.rb
#
# Optional env vars:
#   MAX_PAGES=1          how many listing pages to scrape (default: 1)
#   REPROCESS=true       re-run Gemini on meetings already marked processed
#   DRY_RUN=true         scrape + parse only, skip DB writes (uses first stored meeting)

require_relative "../lib/fetchers/base_fetcher"
require_relative "../lib/fetchers/san_francisco_fetcher"

MAX_PAGES  = (ENV["MAX_PAGES"] || 1).to_i
REPROCESS  = ENV["REPROCESS"] == "true"
DRY_RUN    = ENV["DRY_RUN"] == "true"

puts "=" * 60
puts "SF BOS Agenda Smoketest — #{Time.current.strftime("%Y-%m-%d %H:%M")}"
puts "MAX_PAGES=#{MAX_PAGES}  REPROCESS=#{REPROCESS}  DRY_RUN=#{DRY_RUN}"
puts "=" * 60

# --- Setup city + agenda source ---
city = City.find_or_create_by!(slug: "san-francisco") do |c|
  c.name   = "San Francisco"
  c.county = "San Francisco County"
end

source = city.agenda_sources.find_or_create_by!(
  fetcher_class: "Fetchers::SanFranciscoFetcher"
) do |s|
  s.agenda_url = "https://sfbos.org/meetings/full-board-meetings"
  s.config     = {}
end
source.update!(config: source.config.merge("max_pages" => MAX_PAGES))

if DRY_RUN
  # --- Dry run: just test Gemini on the most recent stored meeting ---
  meeting = source.council_meetings.where(status: "processed").order(meeting_date: :desc).first
  unless meeting
    puts "ERROR: No processed meetings found. Run without DRY_RUN=true first."
    exit 1
  end

  puts "\n[DRY RUN] Testing GeminiAgendaProcessor on #{meeting.meeting_date}..."
  appeals = GeminiAgendaProcessor.new(meeting).process
  puts "  Appeals extracted: #{appeals.count}"
  appeals.each { |a| puts "    • [#{a.grounds_category}] #{a.project_address || a.project_name} — #{a.appellant_name}" }

else
  # --- Full run: fetch + process ---
  puts "\nStep 1: Fetching PDFs from sfbos.org..."
  fetcher = source.fetcher
  meetings = fetcher.fetch

  puts "  Meetings newly fetched/processed: #{meetings.count}"
  puts "  Total meetings for SF: #{source.council_meetings.count}"
  puts "  Processed: #{source.council_meetings.where(status: "processed").count}"
  puts "  Pending:   #{source.council_meetings.where(status: "pending").count}"

  puts "\nStep 2: Gemini extraction summary..."
  all_appeals = HousingAppeal.where(city: city).order(filed_date: :desc)
  puts "  Total housing appeals for SF: #{all_appeals.count}"

  if all_appeals.any?
    puts "\n  Latest 5 appeals:"
    all_appeals.limit(5).each do |a|
      puts "    [#{a.filed_date}] #{a.project_address || a.project_name || "(unknown)"}"
      puts "         Appellant: #{a.appellant_name || "(unknown)"}"
      puts "         Grounds:   #{a.grounds_category} — #{a.grounds_description&.truncate(80)}"
      puts
    end
  else
    puts "  (No appeals extracted yet — Gemini may have found none in these agendas)"
  end
end

puts "=" * 60
puts "Done."
