#!/usr/bin/env ruby
# Fetch all repositories for a GitHub team (with pagination), print to console, write to CSV.
#
# Usage:
#   export GITHUB_TOKEN="YOUR_TOKEN"
#   ruby export_team_repos_to_csv.rb
#
# Optional env vars:
#   ORG="intcx" TEAM_SLUG="rtstes-rw" OUT_CSV="rtstes-rw-repos.csv" PER_PAGE="100"

require "net/http"
require "json"
require "csv"
require "uri"

ORG      = ENV.fetch("ORG", "intcx")
TEAM     = ENV.fetch("TEAM_SLUG", "rtstes-rw")
OUT_CSV  = ENV.fetch("OUT_CSV", "#{TEAM}-repos.csv")
PER_PAGE = ENV.fetch("PER_PAGE", "100").to_i

token = ENV["GITHUB_TOKEN"]
if token.nil? || token.strip.empty?
  warn "ERROR: Please set GITHUB_TOKEN (a GitHub token that can read org/team repos)."
  exit 1
end

API_VERSION = ENV.fetch("GITHUB_API_VERSION", "2026-03-10")

def parse_next_link(link_header)
  return nil if link_header.nil? || link_header.strip.empty?

  # Example:
  # <https://api.github.com/...&page=2>; rel="next", <https://api.github.com/...&page=4>; rel="last"
  link_header.split(",").each do |part|
    if part.include?('rel="next"')
      return part[/<([^>]+)>/, 1]
    end
  end

  nil
end

def github_get_json(url, token, api_version)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  req = Net::HTTP::Get.new(uri.request_uri)
  req["Accept"] = "application/vnd.github+json"
  req["Authorization"] = "Bearer #{token}"
  req["X-GitHub-Api-Version"] = api_version
  req["User-Agent"] = "export-team-repos-to-csv"

  resp = http.request(req)

  unless resp.is_a?(Net::HTTPSuccess)
    warn "ERROR: HTTP #{resp.code}"
    warn resp.body
    exit 2
  end

  json = JSON.parse(resp.body)
  next_url = parse_next_link(resp["link"])
  [json, next_url]
end

start_url = "https://api.github.com/orgs/#{ORG}/teams/#{TEAM}/repos?per_page=#{PER_PAGE}"

repos = []
page = 1
url = start_url

while url
  batch, next_url = github_get_json(url, token, API_VERSION)

  puts "Fetched page #{page}: #{batch.length} repos"
  batch.each do |r|
    puts " - #{r["full_name"]}"
  end

  repos.concat(batch)
  url = next_url
  page += 1
end

CSV.open(OUT_CSV, "w", write_headers: true, headers: ["name", "full_name", "html_url", "private"]) do |csv|
  repos.each do |r|
    csv << [r["name"], r["full_name"], r["html_url"], r["private"]]
  end
end

puts
puts "Done. Total repos: #{repos.length}"
puts "CSV written to: #{OUT_CSV}"
