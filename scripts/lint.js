import glob from "glob"
import chalk from "chalk"
import { lint_results } from "./lint_results.js"

async function main() {
  let files = glob.sync('**/*.md').filter(file => !file.startsWith('node_module'))
  let results = lint_results(files)

  function rightPad(s, len) {
    let i = -1;
    let length = len - s.length;
    let c = " "

    let str = s;
    while (++i < length) {
      str += c;
    }
    return str;
  }

  var errorCounter = 0

  for (let result of results) {
    if (result.errors.length == 0) {
      continue
    }
    console.log(result.file)

    for (let error of result.errors) {
      errorCounter += 1

      let {
        start,
        end,
        text,
        type,
        description
      } = error;
      let pos = `${start.line}:${start.column}-${end.line}:${end.column}`;

      console.log(
        chalk.grey(
          '  ',
          rightPad(pos, 16),
          '    ',
          rightPad(`${type}`, 24),
          '    ',
          chalk.red(`${description} ${text}`)
        )
      )
    }
    console.log()
  }

  console.log(
    chalk.green(`Lint total ${files.length} files`),
    chalk.red(`${errorCounter} errors`)
  )
}

main()
