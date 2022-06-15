require 'json'
require './scripts/helper.rb'

files = git.added_files.select { |f| f.end_with?('.md') }

if files.empty?
  puts 'No markdown file needs to be lint'
  return
end

pull_request_url = github.pr_json.html_url
pull_request_author = ENV['GITHUB_ACTOR']
session_ids = Helper.session_ids(files)

if session_ids.empty?
  fail Helper.session_ids_not_found_message

  begin
    message = "markdown 文件无法识别出 session_ids，请按照 GitHub 上的提示正确填写。 #{pull_request_url}"
    response = Helper.send_message(message, [pull_request_author])
    puts response.status, response.body

    response_data = JSON.parse response.body

    fail "通知失败: #{response_data["msg"]}" if response.status != 200
  rescue => e
    fail "通知失败：请联系管理员检查服务器是否正常运行。 #{e.message}"
  end

  return
end

lint_results_json = `node ./scripts/lint_results_output #{files.map{ |file| "'#{file}'" }.join(' ')}`
lint_results = JSON.parse lint_results_json

has_error = false

lint_results.first(1000).each do |lint_result|
  file = lint_result['file']
  errors = lint_result["errors"]
  errors&.each do |error|
    has_error = true

    start = error["start"]
    line = start['line']
    text = error['text']
    rule_information = error['ruleInformation']
    message = ""
    message << error['description']
    message << " `#{text}`\n" if text
    message << "For more details please visit [#{error['type']}](#{rule_information})." if rule_information
    fail(message, file: file, line: line)
  end
end

message = ""
from_ci = ENV['GITHUB_ACTOR'] == 'SwiftOldDriverBot'

if has_error
  if from_ci
    message = "CI 已尝试自动修复格式问题，但仍有部分需要手动处理，请尽快根据 GitHub 上的评论完成修改。 #{pull_request_url}"
  else
    message = "PR 有新的提交，文章格式存在问题，请尽快根据 GitHub 上的评论完成修改。 #{pull_request_url}"
  end
else
  message = "PR 有新的提交，已通过格式检查，请尽快查阅审核。 #{pull_request_url}"
end

begin
  type = has_error ? 0 : 1
  response = Helper.send_group_message(message, session_ids, type)
  puts response.status, response.body

  response_data = JSON.parse response.body

  fail "通知失败：#{response_data["msg"]}" if response.status != 200

  if response_data["code"] != 0
    Helper.send_message(response_data["msg"], [pull_request_author])
  end
rescue => e
  fail "通知失败：请联系管理员检查服务器是否正常运行。 #{e.message}"
end
