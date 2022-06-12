import { argv } from "process"
import { lint_results } from "./lint_results.js"

let files = argv.slice(2)
console.log(JSON.stringify(lint_results(files)))
