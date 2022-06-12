import fs from 'fs'
import * as fm from 'hexo-front-matter'
import { argv } from 'process'

let files = argv.slice(2)
let fileFrontMatters = files.map(file => {
    let str = fs.readFileSync(file, 'utf8')
    let frontMatter = fm.parse(str) 
    delete frontMatter._content
    return { file: file, frontMatter: frontMatter }
})

console.log(JSON.stringify(fileFrontMatters))
