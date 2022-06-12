require 'uri'
require 'git'
require 'octokit'
require './scripts/helper.rb'

target_ref = ENV['TARGET_REF']

files = Helper.added_files('origin/main', target_ref)
files_as_shell_arguments = Helper.files_as_shell_arguments(files)

puts `yarn markdownlint -f -q -c scripts/markdownlint.json #{files_as_shell_arguments}`
puts `yarn lint-md -f -c scripts/documentlint.json #{files_as_shell_arguments}`

git = Git.open(".")

return unless git.status.changed.keys.select { |f| files.include?(f) }.size > 0

uri = URI(ENV['GITHUB_SERVER_URL'])
uri.path = "/#{ENV['GITHUB_REPOSITORY']}.git"
uri.user = ENV['BOT_ACCESS_TOKEN']

key = 'http.https://github.com/.extraheader'
origin_header = git.config(key)
git.config(key, '')
git.add(files)
git.commit("Fix format by CI", :author => "github-actions[bot] <github-actions[bot]@users.noreply.github.com>")
git.push(uri.to_s, target_ref)
git.config(key, origin_header)
