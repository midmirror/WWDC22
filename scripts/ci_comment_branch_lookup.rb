require 'danger'
require 'octokit'

pull_request_url = ENV['PULL_REQUEST_URL']
pull_request_id = Danger::FindRepoInfoFromURL.new(pull_request_url).call.id
pull_request = Octokit::Client
  .new(:access_token => ENV['DANGER_GITHUB_API_TOKEN'])
  .pull_request(ENV['GITHUB_REPOSITORY'], pull_request_id)
puts pull_request.head.ref
