require_relative "config/environment"

sf = City.find_by!(slug: "san-francisco")

puts "sf = City.find_by!(slug: 'san-francisco')"
puts "sf.housing_appeals.destroy_all"
puts ""
sf.housing_appeals.each do |appeal|
  puts "appeal = sf.housing_appeals.create!("
  puts "  reference_number: #{appeal.reference_number.inspect},"
  puts "  project_address: #{appeal.project_address.inspect},"
  puts "  project_name: #{appeal.project_name.inspect},"
  puts "  apn: #{appeal.apn.inspect},"
  puts "  appellant_name: #{appeal.appellant_name.inspect},"
  puts "  grounds_description: #{appeal.grounds_description.inspect},"
  puts "  status: #{appeal.status.inspect},"
  puts "  decision: #{appeal.decision.inspect},"
  puts "  filed_date: #{appeal.filed_date.inspect}"
  puts ")"

  appeal.housing_appeal_hearings.each do |hearing|
    puts "appeal.housing_appeal_hearings.create!("
    puts "  council_meeting_id: AgendaSource.find_by(city: sf, fetcher_class: 'Fetchers::SanFranciscoFetcher').council_meetings.find_or_create_by!(meeting_date: #{hearing.council_meeting.meeting_date.inspect}, meeting_type: 'regular').id,"
    puts "  hearing_type: #{hearing.hearing_type.inspect},"
    puts "  action_taken: #{hearing.action_taken.inspect},"
    puts "  description: #{hearing.description.inspect},"
    puts "  grounds_description: #{hearing.grounds_description.inspect},"
    puts "  page_number: #{hearing.page_number.inspect}"
    puts ")"
  end
  puts ""
end
