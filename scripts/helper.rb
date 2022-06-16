require 'json'
require 'danger'
require 'faraday'

module Helper
  def self.session_ids(files)
    front_matters(files)
      .map { |result| result['frontMatter']['session_ids'] }
      .select { |ids| ids.is_a?(Array) }
      .flatten
      .uniq
  end

  def self.front_matters(files)
    arguments = []
    arguments << "node"
    arguments << "./scripts/front_matters_output.js"
    arguments << files_as_shell_arguments(files)
    command = arguments.join(' ')

    puts "Command: ", command
    results_json = `#{command}`
    puts "Command output: ", results_json
    results = JSON.parse(results_json)
    results
  end

  def self.added_files(from, to)
    git_repo = Danger::GitRepo.new
    git_repo.diff_for_folder('.', from: from, to: to, lookup_top_level: true)
    file_list = git_repo.diff.select { |diff| diff.type == "new" }.map(&:path)
    file_list
  end

  def self.added_markdown_files(from, to)
    added_files(from, to).select { |f| f.end_with?('.md') }
  end

  def self.files_as_shell_arguments(files)
    files.map{ |f| "'#{f}'" }
         .join(' ')
  end

  def self.send_group_message(message, session_ids, type)
    content = {
      message: message,
      session_ids: session_ids,
      type: type
    }
    puts content
    Faraday.post(
      "http://127.0.0.1:4040/wwdc/notify",
      content.to_json,
      'Content-Type' => 'application/json'
    )
  end

  def self.send_message(message, at_user_list)
    content = {
      message: message,
      at_user_list: at_user_list
    }
    puts content
    Faraday.post(
      'http://127.0.0.1:4040/wwdc/mention',
      content.to_json,
      'Content-Type' => 'application/json'
    )
  end

  def self.session_ids_not_found_message
    message = ""
    message << "Markdown 文件中无法识别到 session_id，请在 markdown 文件前面加上对应的 session_id。范例：\n\n"
    message << "```markdown\n"
    message << "---\n"
    message << "session_ids: [10118]\n"
    message << "---\n\n"
    message << "# Session 10118 - CloudKit 自动化开发\n\n"
    message << "本文基于[Session 10118](https://developer.apple.com/videos/play/wwdc2021/10118/)梳理...\n\n"
    message << "```"
    message
  end
end
