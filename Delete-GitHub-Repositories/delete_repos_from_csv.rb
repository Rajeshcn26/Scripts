#!/usr/bin/env ruby
# Delete GitHub repositories listed in a CSV file (header: name).
#
# CSV format (repos.csv):
#   name
#   RTSTES.common.c.logger
#   RTSTES.common.c.policyparser
#
# Default behavior: DRY-RUN (no deletions)
#
# Usage:
#   export GITHUB_TOKEN="YOUR_TOKEN_WITH_DELETE_REPO_PERMISSION"
#   ruby delete_repos_from_csv.rb                      # dry-run
#   ruby delete_repos_from_csv.rb --execute            # execute (with confirmation)
#   ruby delete_repos_from_csv.rb --execute --yes      # execute without confirmation (DANGEROUS)
#
# Optional env vars:
#   ORG=intcx
#   FILE=repos.csv
#   REPO_PREFIX=RTSTES.     # only allow deletion of repos whose name starts with this prefix
#   GITHUB_API_VERSION=2026-03-10

require "csv"
require "net/http"
require "uri"
require "json"

ORG  = ENV.fetch("ORG", "intcx")
FILE = ENV.fetch("FILE", "repos.csv")
API_VERSION = ENV.fetch("GITHUB_API_VERSION", "2026-03-10")
REPO_PREFIX = ENV["REPO_PREFIX"] # optional safety filter, e.g. "RTSTES."

EXECUTE = ARGV.include?("--execute")
SKIP_CONFIRM = ARGV.include?("--yes") # requires --execute

token = ENV["GITHUB_TOKEN"]
if token.nil? || token.strip.empty?
  warn "ERROR: Please set GITHUB_TOKEN."
  warn "It must have permission to delete repositories in org #{ORG}."
  exit 1
end

unless File.exist?(FILE)
  warn "ERROR: CSV file not found: #{FILE}"
  exit 1
end

def normalize_repo_name(value)
  return nil if value.nil?
  n = value.to_s.strip
  return nil if n.empty?

  # Allow either "repo" or "org/repo" in CSV; normalize to repo only
  if n.include?("/")
    org, repo = n.split("/", 2)
    repo = repo&.strip
    return nil if repo.nil? || repo.empty?
    return repo
  end

  n
end

repo_names = []
CSV.foreach(FILE, headers: true) do |row|
  repo = normalize_repo_name(row["name"])
  next if repo.nil?
  repo_names << repo
end

repo_names.uniq!
if repo_names.empty?
  warn "ERROR: No repository names found in #{FILE} (expected header: name)."
  exit 1
end

if REPO_PREFIX && !REPO_PREFIX.strip.empty?
  before = repo_names.length
  repo_names.select! { |r| r.start_with?(REPO_PREFIX) }
  removed = before - repo_names.length

  if repo_names.empty?
    warn "ERROR: After applying REPO_PREFIX='#{REPO_PREFIX}', there are 0 repos left to delete."
    warn "Check your prefix or your CSV contents."
    exit 1
  end

  puts "Safety filter enabled: REPO_PREFIX='#{REPO_PREFIX}'"
  puts "Filtered out: #{removed} repo(s) that did not match the prefix."
  puts
end

puts "Org: #{ORG}"
puts "CSV: #{FILE}"
puts "Repos to delete (#{repo_names.length}):"
repo_names.each { |r| puts " - #{ORG}/#{r}" }
puts

if !EXECUTE
  puts "Dry-run mode (no deletions)."
  puts "Run with: ruby delete_repos_from_csv.rb --execute"
  puts "Optional safety: REPO_PREFIX=RTSTES. ruby delete_repos_from_csv.rb --execute"
  exit 0
end

# Confirmation is case-insensitive and whitespace-tolerant
confirm_phrase = "DELETE #{ORG} #{repo_names.length}"

unless SKIP_CONFIRM
  puts "You are about to PERMANENTLY DELETE #{repo_names.length} repositories from #{ORG}."
  puts "To confirm, type exactly (case-insensitive; extra spaces ok):"
  puts "  #{confirm_phrase}"
  print "> "

  typed = STDIN.gets
  if typed.nil?
    puts "No input received. Aborting."
    exit 1
  end

  typed_norm = typed.strip.gsub(/\s+/, " ").upcase
  expected_norm = confirm_phrase.strip.gsub(/\s+/, " ").upcase

  if typed_norm != expected_norm
    puts "Confirmation did not match. Aborting."
    exit 1
  end
end

def delete_repo(org, repo, token, api_version)
  uri = URI("https://api.github.com/repos/#{org}/#{repo}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true

  req = Net::HTTP::Delete.new(uri.request_uri)
  req["Accept"] = "application/vnd.github+json"
  req["Authorization"] = "Bearer #{token}"
  req["X-GitHub-Api-Version"] = api_version
  req["User-Agent"] = "delete-repos-from-csv"

  resp = http.request(req)

  case resp.code.to_i
  when 204
    { ok: true, status: 204, message: "deleted" }
  when 404
    { ok: false, status: 404, message: "not found / no access" }
  when 403
    { ok: false, status: 403, message: "forbidden (missing permission / SSO / policy)" }
  else
    body = resp.body.to_s
    msg =
      begin
        j = JSON.parse(body)
        j["message"] || body
      rescue
        body.empty? ? "(no response body)" : body
      end
    { ok: false, status: resp.code.to_i, message: msg }
  end
end

success = 0
failures = 0

repo_names.each_with_index do |repo, idx|
  full = "#{ORG}/#{repo}"
  puts "[#{idx + 1}/#{repo_names.length}] Deleting #{full} ..."

  result = delete_repo(ORG, repo, token, API_VERSION)
  if result[:ok]
    success += 1
    puts "  OK (HTTP #{result[:status]})"
  else
    failures += 1
    puts "  FAILED (HTTP #{result[:status]}): #{result[:message]}"
  end
end

puts
puts "Done."
puts "Deleted: #{success}"
puts "Failed:  #{failures}"
exit(failures > 0 ? 3 : 0)
