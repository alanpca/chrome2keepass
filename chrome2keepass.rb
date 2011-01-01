#!/usr/bin/env ruby
=begin

chrome2keepass will take a Chrome password database and convert it to proper
XML format importation into Keepass (http://keepass.info/download.html).

If you're like me, then you sometimes want to access sites from a remote
computer, but have a massive amount of different passwords that are
site-specific.  By combining Keepass with Dropbox, I have found the best
method (for me) to access my web passwords remotely.

Gems required: sqlite3, cgi, optparse, ostruct

Copyright (C) 2011 Alan P. Laudicina <contact@laudicina.net>

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

=end

require 'optparse'
require 'ostruct'
require 'sqlite3'
require 'cgi'

def put_top
  puts "<!DOCTYPE KEEPASSX_DATABASE>"
  puts "<database>\n"
  puts "<group><title>Chrome Import " + Time.new.strftime('%Y%m%d-%H%M%S') + "</title>"
  puts "<icon>1</icon>"
end

def put_bottom
  puts "</group>\n</database>\n"
end

def get_title(entry)
  # This is here for future support of renaming
  title = CGI.escapeHTML(entry['origin_url'])
end

# Put the entry to $stdout based on the Keepass XML formatting
def put_entry(entry)
  # Chrome seems to have put a bunch of no user/pass logins in my DB, which are quite
  # useless, so we just ignore them and return back to the next row.
  return if entry['username_value'] == '' && entry['password_value'] = ''

  # The datestring that Keepass likes
  datestring = Time.now.strftime('%Y-%m-%dT%H:%M:%S')

  # The 'meat' of the entry
  puts "<entry>\n<title>" + get_title(entry) + "</title>\n"
  puts "<username>" + CGI.escapeHTML(entry['username_value']) + "</username>\n"
  puts "<password>" + CGI.escapeHTML(entry['password_value']) + "</password>\n"
  puts "<url>" + CGI.escapeHTML(entry['origin_url']) + "</url>\n"
  puts "<comment></comment><icon>1</icon>"
  puts "<creation>" + datestring + "</creation>\n"
  puts "<lastaccess>" + datestring + "</lastaccess>\n"
  puts "<lastmod>" + datestring + "</lastmod>\n"
  puts "<expire>Never</expire>\n"
  puts "</entry>\n"
end

def getoptions(args)
  options = OpenStruct.new
  # Default values
  options.location = ENV['HOME'] + "/.config/chromium"
  options.profile = 'Default'
  options.show_help = false

  opts = OptionParser.new do |opts|
    opts.banner = "Usage: chrome2keepass [options]"
    opts.separator ""
    opts.on("-p", "--profile [PROFILE]", "Name of Chrome Profile",
      "Default: 'Default'") do |profile|
        options.profile = profile
    end

    opts.on("-l", "--location [LOCATION]", "Location to chrome config",
      "Default: '$HOME/.config/chromium'") do |location|
        options.location = location
    end

    opts.on("-f", "--filename [FILENAME]", "Filename to use instead of STDOUT") do |filename|
      options.filename = filename
    end

    opts.on("-h", "--help", "Show this help") do |helpme|
      options.show_help = true
    end
  end
  others = Array.new
  # Loop through each argument and parse it.
  args.each do |arg|
    begin
      opts.parse!
    rescue OptionParser::InvalidOption => e
      others.push e.args[0]
    end
  end
  # Return a hash with the data we may need.
  # @options are the options that were set by arguments
  # @others are the bad options
  # @usage is the usage help
  {"options" => options, "others" => others, "usage" => opts}
end

values = getoptions(ARGV)
options = values['options']

if options.show_help
  # If we get sent the help options, show help and exit
  print values['usage']
  exit
end

if values['others'].size > 0
  # We got some bad arguments, let the user know
  print "Bad arguments: "
  values['others'].each { |badopt| print badopt }
else
  # Set the location of the DB based on options sent by user
  sqdb = options.location + "/" + options.profile + "/Login Data"
  db = SQLite3::Database.new(sqdb)
  # Give the results as a hash
  db.results_as_hash = true
  begin
    rows = db.execute("SELECT * FROM `logins`")
  # Leave on SQLException
  rescue SQLite3::SQLException
    print "Database is locked or the location was invalid\n"
    exit
  end
  # Print out the XML for importation
  put_top
  # Cycle through each entry and print it out
  rows.each do |row|
    put_entry(row)
  end
  put_bottom
end
