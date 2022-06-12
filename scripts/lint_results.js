import markdownlint from "markdownlint"
import * as lintmd from "@lint-md/core"
import fs from "fs"
import util from "util"

export function lint_results(files) {
    let markdownlintConfig = JSON.parse(fs.readFileSync("scripts/markdownlint.json"))
    let markdownlintOptions = { files: files, config: markdownlintConfig }

    var errorCounter = 0
    var results = new Map()

    let markdownlint_results = markdownlint.sync(markdownlintOptions)
    for (let [file, violations] of Object.entries(markdownlint_results)) {
        var fileResults = []
        for (let violation of violations) {
            var description = `[${violation.ruleNames[0]}] ${violation.ruleDescription}`
            if (violation.errorDetail) {
                description += `: ${violation.errorDetail}`
            }

            let startColumn = violation.errorRange?.[0] || 0
            let endColumn = violation.errorRange?.[1] || 0
            fileResults.push({
                start: {
                    line: violation.lineNumber,
                    column: startColumn
                },
                end: {
                    line: violation.lineNumber,
                    column: endColumn
                },
                text: violation.errorContext,
                type: violation.ruleNames[1],
                description: violation.ruleDescription,
                ruleInformation: violation.ruleInformation
            })
            errorCounter += 1
        }
        results.set(file, fileResults)
    }

    let lintmdOptions = JSON.parse(fs.readFileSync("scripts/documentlint.json")).rules
    for (let file of files) {
        let markdown = fs.readFileSync(file, 'utf8')
        let errors = lintmd.lint(markdown, lintmdOptions)
        var fileResults = results.get(file) || []
        for (let error of errors) {
            let description = lintmd.getDescription(error.type).message
            fileResults.push({
                ...error,
                description: description
            })
            errorCounter += 1
        }
        results.set(file, fileResults)
    }

    var structuredResult = new Array()

    for (let [file, errors] of results) {
        errors.sort((lhs, rhs) => {
            if (lhs.start.line > rhs.start.line) {
                return 1
            }
            if (lhs.start.line < rhs.start.line) {
                return -1
            }
            return 0
        })

        structuredResult.push({
            file: file,
            errors: errors
        })
    }

    return structuredResult
}
