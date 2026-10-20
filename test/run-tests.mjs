// Offline checker for the GTM templates (no dependencies).
// 1. Parses every section of each .tpl (JSON sections must be valid JSON).
// 2. Checks that every sandboxed API the code requires is covered by a declared permission, and enforces the
//    declared permission values at runtime (pixel URL patterns, global keys + read/write/execute, storage keys).
// 3. Runs the ___TESTS___ scenarios with a minimal re-implementation of GTM's test API
//    (mock, runCode, assertApi, assertThat) so the same tests pass here and in the GTM template editor.
// Usage: node test/run-tests.mjs
import fs from 'node:fs'
import path from 'node:path'
import assert from 'node:assert/strict'
import { fileURLToPath } from 'node:url'

const root = path.join(path.dirname(fileURLToPath(import.meta.url)), '..')
const templates = fs.readdirSync(root).filter((f) => f.endsWith('.tpl'))
let failures = 0

function sections(text) {
  const out = {}
  const re = /^___([A-Z_]+)___$/gm
  const marks = []
  let m
  while ((m = re.exec(text))) marks.push({ name: m[1], start: m.index, bodyStart: re.lastIndex })
  marks.forEach((mark, i) => {
    out[mark.name] = text.slice(mark.bodyStart, i + 1 < marks.length ? marks[i + 1].start : text.length).trim()
  })
  return out
}

// Tiny parser for the fixed ___TESTS___ YAML shape GTM exports.
function parseTests(yaml) {
  const lines = yaml.split('\n')
  const scenarios = []
  let setup = ''
  let i = 0
  const block = (indent) => {
    const body = []
    while (i < lines.length && (lines[i].startsWith(' '.repeat(indent)) || lines[i].trim() === '')) {
      body.push(lines[i].slice(indent))
      i++
    }
    return body.join('\n')
  }
  while (i < lines.length) {
    const line = lines[i]
    if (line.startsWith('- name: ')) {
      scenarios.push({ name: line.slice(8).trim() })
      i++
    } else if (line.trim() === 'code: |-') {
      i++
      scenarios[scenarios.length - 1].code = block(4)
    } else if (line.startsWith('setup: |-')) {
      i++
      setup = block(2)
    } else {
      i++
    }
  }
  return { scenarios, setup }
}

function permissionMap(perms) {
  const map = {}
  for (const p of perms) {
    const params = {}
    for (const param of p.instance.param || []) params[param.key] = decode(param.value)
    map[p.instance.key.publicId] = params
  }
  return map
}

function decode(v) {
  if (v.type === 1) return v.string
  if (v.type === 8) return v.boolean
  if (v.type === 2) return v.listItem.map(decode)
  if (v.type === 3) return Object.fromEntries(v.mapKey.map((k, i) => [decode(k), decode(v.mapValue[i])]))
  throw new Error('unknown value type ' + v.type)
}

const API_PERMISSION = {
  sendPixel: 'send_pixel', getUrl: 'get_url', getReferrerUrl: 'get_referrer', copyFromWindow: 'access_globals',
  callInWindow: 'access_globals', setInWindow: 'access_globals', createQueue: 'access_globals',
  localStorage: 'access_local_storage', logToConsole: 'logging', injectScript: 'inject_script'
}
const PURE_APIS = ['encodeUriComponent', 'makeString', 'makeNumber', 'makeTableMap', 'Object', 'JSON']

function urlMatches(url, pattern) {
  const re = new RegExp('^' + pattern.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*'))
  return re.test(url)
}

function runTemplate(file) {
  const text = fs.readFileSync(path.join(root, file), 'utf8')
  const s = sections(text)
  for (const name of ['TERMS_OF_SERVICE', 'INFO', 'TEMPLATE_PARAMETERS', 'SANDBOXED_JS_FOR_WEB_TEMPLATE', 'WEB_PERMISSIONS', 'TESTS']) {
    assert.ok(s[name], `${file}: missing ___${name}___`)
  }
  const info = JSON.parse(s.INFO)
  const params = JSON.parse(s.TEMPLATE_PARAMETERS)
  const perms = permissionMap(JSON.parse(s.WEB_PERMISSIONS))
  assert.equal(info.type, 'TAG')
  assert.ok(Array.isArray(params) && params.length > 0)
  const code = s.SANDBOXED_JS_FOR_WEB_TEMPLATE

  // Static checks: sandboxed JS forbids these constructs.
  const stripped = code.replace(/'(?:[^'\\]|\\.)*'/g, "''").replace(/\/\/.*$/gm, '')
  for (const bad of [/\bnew\s/, /\bthis\b/, /\bwindow\./, /\bdocument\./, /\bclass\s/]) {
    assert.ok(!bad.test(stripped), `${file}: sandboxed JS must not use ${bad}`)
  }
  const required = [...code.matchAll(/require\('([A-Za-z]+)'\)/g)].map((m) => m[1])
  for (const api of required) {
    if (PURE_APIS.includes(api)) continue
    assert.ok(API_PERMISSION[api], `${file}: unknown API ${api}`)
    assert.ok(perms[API_PERMISSION[api]], `${file}: ${api} needs permission ${API_PERMISSION[api]}`)
  }
  for (const id of Object.keys(perms)) {
    assert.ok(required.some((api) => API_PERMISSION[api] === id), `${file}: permission ${id} declared but unused`)
  }
  const globals = Object.fromEntries((perms.access_globals?.keys || []).map((k) => [k.key, k]))
  const needGlobal = (key, right) => {
    assert.ok(globals[key] && globals[key][right], `${file}: global '${key}' needs ${right} permission`)
  }

  const { scenarios, setup } = parseTests(s.TESTS)
  assert.ok(scenarios.length > 0, `${file}: no test scenarios`)

  for (const scenario of scenarios) {
    const calls = {}
    const mocks = {}
    const win = {}
    const record = (name, args) => { (calls[name] = calls[name] || []).push(args) }
    const getPath = (key) => key.split('.').reduce((o, k) => (o == null ? undefined : o[k]), win)
    const setPath = (key, value) => {
      const keys = key.split('.')
      let o = win
      keys.slice(0, -1).forEach((k) => { o = o[k] = o[k] || {} })
      o[keys[keys.length - 1]] = value
    }
    const defaults = {
      sendPixel: (url, ok) => ok && ok(),
      getUrl: () => 'https://example.com/',
      getReferrerUrl: () => '',
      encodeUriComponent: encodeURIComponent,
      makeString: (v) => String(v),
      makeNumber: (v) => Number(v),
      makeTableMap: (rows, k, v) => (rows && rows.length ? Object.fromEntries(rows.map((r) => [r[k], r[v]])) : undefined),
      copyFromWindow: (key) => getPath(key),
      callInWindow: (key, ...args) => (typeof getPath(key) === 'function' ? getPath(key)(...args) : undefined),
      setInWindow: (key, value, override) => { if (override || getPath(key) === undefined) setPath(key, value); return true },
      createQueue: (key) => { if (!Array.isArray(getPath(key))) setPath(key, []); return (item) => getPath(key).push(item) },
      logToConsole: () => {},
      localStorage: { getItem: () => null },
      Object: { keys: Object.keys, values: Object.values, entries: Object.entries }
    }
    const guards = {
      sendPixel: (url) => assert.ok(perms.send_pixel.allowedUrls === 'any' ||
        perms.send_pixel.urls.some((p) => urlMatches(url, p)), `${file}: sendPixel URL not permitted: ${url}`),
      copyFromWindow: (key) => needGlobal(key, 'read'),
      callInWindow: (key) => needGlobal(key, 'execute'),
      setInWindow: (key) => needGlobal(key, 'write'),
      createQueue: (key) => { needGlobal(key, 'read'); needGlobal(key, 'write') }
    }
    const require = (name) => {
      if (name === 'localStorage') {
        const impl = mocks.localStorage || defaults.localStorage
        return {
          getItem: (key) => {
            assert.ok(perms.access_local_storage.keys.some((k) => k.key === key && k.read), `${file}: localStorage read of ${key} not permitted`)
            record('localStorage.getItem', [key])
            return impl.getItem(key)
          }
        }
      }
      if (name === 'Object') return defaults.Object
      assert.ok(name in defaults, `${file}: harness lacks API ${name}`)
      return (...args) => {
        if (guards[name]) guards[name](...args)
        record(name, args)
        const impl = mocks[name] !== undefined ? mocks[name] : defaults[name]
        return typeof impl === 'function' ? impl(...args) : impl
      }
    }
    const testApi = {
      mock: (name, impl) => { mocks[name] = impl },
      runCode: (data) => {
        const input = Object.assign({}, data, {
          gtmOnSuccess: () => record('gtmOnSuccess', []),
          gtmOnFailure: () => record('gtmOnFailure', [])
        })
        new Function('require', 'data', code)(require, input)
      },
      assertApi: (name) => ({
        wasCalled: () => assert.ok(calls[name], `${name} was not called`),
        wasNotCalled: () => assert.ok(!calls[name], `${name} was called`),
        wasCalledWith: (...args) => assert.ok((calls[name] || []).some((c) => {
          try { assert.deepEqual(c, args); return true } catch { return false }
        }), `${name} not called with ${JSON.stringify(args)}; calls: ${JSON.stringify(calls[name])}`)
      }),
      assertThat: (actual) => ({
        isEqualTo: (expected) => assert.deepEqual(actual, expected),
        isDefined: () => assert.notEqual(actual, undefined)
      })
    }
    try {
      new Function(...Object.keys(testApi), setup + '\n' + scenario.code)(...Object.values(testApi))
      console.log(`ok   ${file} › ${scenario.name}`)
    } catch (e) {
      failures++
      console.log(`FAIL ${file} › ${scenario.name}\n     ${e.message}`)
    }
  }
}

for (const file of templates) {
  try {
    runTemplate(file)
  } catch (e) {
    failures++
    console.log(`FAIL ${file}: ${e.message}`)
  }
}
const metadata = fs.readFileSync(path.join(root, 'metadata.yaml'), 'utf8')
assert.match(metadata, /^homepage: /m)
assert.match(metadata, /^versions:/m)
console.log(failures ? `\n${failures} failure(s)` : `\nall ${templates.length} templates passed`)
process.exit(failures ? 1 : 0)
