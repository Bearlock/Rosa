desc "Refresh the data files"
task :refresh_data => :environment do
  # includes
  require 'open-uri'
  require 'json'

  # importing json confidentials
  conf_file = File.open("config/confidential.json", "r:utf-8") { |f| f.read }
  conf_json = JSON.parse(conf_file)

  puts "Refreshing data files.."
  # Create an opensr file for each username in the app/assets/data directory. 
  Username.all.each do |user|

    puts "Updating data for #{user.name}.."

    # Read in content for open SRs
    read_content = open("#{conf_json["open_srs"]}#{user.name}", "r:utf-8") { |f| f.read.force_encoding("ISO-8859-1").encode("utf-8", replace: nil) }

    # Write out content to file
    File.open("app/assets/data/opensrs_#{user.name}", 'w') { |f| f.write(read_content) }

    # Read in content for closed SRs
    read_content = open("#{conf_json["closed_srs"]}#{user.name}", "r:utf-8") { |f| f.read.force_encoding("ISO-8859-1").encode("utf-8", replace: nil) }

    # Write out content to file
    File.open("app/assets/data/closedsrs_#{user.name}", 'w') { |f| f.write(read_content) }

    # Read in workforce ID
    read_id = open("#{conf_json["workforce_id"]}#{user.name}", "r:utf-8") { |f| f.read.scan(/[0-9]+/).pop }

    # Read in survey scores
    read_content = open("#{conf_json["survey_scores"]}#{read_id}", "r:utf-8") { |f| f.read.force_encoding("ISO-8859-1").encode("utf-8", replace: nil) }

    # Write out survey scores to file
    File.open("app/assets/data/surveys_#{user.name}", "w") { |f| f.write(read_content) }

    puts "#{user.name} data updated."

  end

  puts "Updating history file.."
  # Create history file for the history partial page to manipulate and render
  command = `tail -70 /var/log/qmonhistory.log | awk -F'|' '{print $10" - "$6" - "$3" - "$NF}' | grep -E '^[0-9]' | tac >app/assets/data/history 2>&1`
  system(command)
  puts "History file updated."

  puts "done."
end
