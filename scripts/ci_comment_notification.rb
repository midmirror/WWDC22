require 'json'
require 'octokit'
require 'danger'
require './scripts/helper.rb'

pull_request_url = ENV['PULL_REQUEST_URL']
pull_request_id = Danger::FindRepoInfoFromURL.new(pull_request_url).call.id
pull_request = Octokit::Client
  .new(:access_token => ENV['DANGER_GITHUB_API_TOKEN'])
  .pull_request(ENV['GITHUB_REPOSITORY'], pull_request_id)
pull_request_author = pull_request.user.login

files = Helper.added_markdown_files("origin/#{pull_request.base.ref}", pull_request.head.ref)
session_ids = Helper.session_ids(files)
puts "Files: ", files

if session_ids.empty?
  puts Helper.session_ids_not_found_message
  return
end

comment_sender = ENV['COMMENT_SENDER']

message = ""
comment_from_pr_author = pull_request_author == comment_sender
if comment_from_pr_author
  message = "PR 有新的审核留言，请尽快查阅。 #{pull_request_url}"
else
  message = "PR 作者已回复留言，请尽快查阅。 #{pull_request_url}"
end

begin
  type = comment_from_pr_author ? 0 : 1
  response = Helper.send_group_message(message, session_ids, type)
  puts response.status, response.body
  response_data = JSON.parse response.body
  fail "通知失败：#{response_data["msg"]}" if response.status != 200
rescue => e
  fail "通知失败，请联系管理员检查服务器是否正常运行。 #{e.message}"
end
