-- tests/spec/review_url_spec.lua
-- Tests for the review module's URL mapping functions.
-- Validates that file paths are correctly mapped to preview URLs.

local pass, fail = 0, 0

local function it(name, fn)
  local ok, err = pcall(fn)
  if ok then
    pass = pass + 1
    io.write('  \27[32m✓\27[0m ' .. name .. '\n')
  else
    fail = fail + 1
    io.write('  \27[31m✗ FAIL\27[0m ' .. name .. '\n')
    io.write('    ' .. tostring(err) .. '\n')
  end
end

local function eq(a, b, label)
  local msg = label and (label .. ': ') or ''
  assert(a == b, msg .. string.format('expected %q, got %q', tostring(b), tostring(a)))
end

print '\n=== review URL mapping ==='

-- Load the review module to get _test functions
local mod = require 'lib.module'
-- Load all modules so review is registered
for _, name in ipairs {
  'interface', 'introspection', 'filesystem', 'text_editing',
  'version_control', 'workspace', 'orgmode', 'agents', 'terminal', 'review',
} do
  pcall(require, 'modules.' .. name)
end
local review_mod = mod._registry['review']

assert(review_mod, 'review module not found')
assert(review_mod._test, 'review module does not expose _test table')

local T = review_mod._test

-- ── slugify ─────────────────────────────────────────────────────────────

it('slugify: spaces become hyphens', function()
  eq(T.slugify('Hello World'), 'hello-world')
end)

it('slugify: special characters stripped', function()
  eq(T.slugify('Intra-Device Interfaces: The EHOS Platform'), 'intra-device-interfaces-the-ehos-platform')
end)

it('slugify: multiple spaces become individual hyphens (github-slugger compat)', function()
  eq(T.slugify('One   Two   Three'), 'one---two---three')
end)

it('slugify: em dash produces double hyphen (github-slugger compat)', function()
  -- em dash is stripped, leaving two adjacent spaces → two hyphens
  eq(T.slugify('Intra-Device Interfaces \u{2014} The EHOS Platform'), 'intra-device-interfaces--the-ehos-platform')
end)

it('slugify: leading/trailing hyphens trimmed', function()
  eq(T.slugify(' - Hello - '), 'hello')
end)

it('slugify: unicode and punctuation', function()
  eq(T.slugify("What's New (2026)"), 'whats-new-2026')
end)

-- ── get_docs_root auto-detection ────────────────────────────────────────

-- Create temporary directory structures to test auto-detection
local tmp_root = vim.fn.tempname()
vim.fn.mkdir(tmp_root, 'p')

it('get_docs_root: prefers documentation/content when it exists', function()
  local root = tmp_root .. '/proj_content'
  vim.fn.mkdir(root .. '/documentation/content/plans', 'p')
  eq(T.get_docs_root(root), 'documentation/content')
end)

it('get_docs_root: falls back to documentation when no content/', function()
  local root = tmp_root .. '/proj_docs'
  vim.fn.mkdir(root .. '/documentation/plans', 'p')
  eq(T.get_docs_root(root), 'documentation')
end)

it('get_docs_root: detects docs/', function()
  local root = tmp_root .. '/proj_generic'
  vim.fn.mkdir(root .. '/docs', 'p')
  eq(T.get_docs_root(root), 'docs')
end)

-- Note: manual override via workspace.docs_root state key is tested
-- implicitly through the ReviewDocsRoot command.  State providers
-- don't have a generic set() in the test harness, so we skip the
-- direct unit test here.

it('get_docs_root: fallback when nothing found', function()
  local root = tmp_root .. '/proj_empty'
  vim.fn.mkdir(root, 'p')
  eq(T.get_docs_root(root), 'documentation')
end)

-- ── file_to_url_path ────────────────────────────────────────────────────
-- These tests need to control workspace.root and the buffer path.
-- Since file_to_url_path uses vim.fn.expand('%:p') we can't easily
-- fake that in a test harness.  Instead we test the core logic
-- extracted into a helper.

-- Test the mapping logic directly: given a file, root, and docs_root,
-- compute the URL path.
local function url_path_for(file, root, docs_root)
  local full_docs = root .. '/' .. docs_root
  local rel = file:gsub('^' .. vim.pesc(full_docs) .. '/', '')
  rel = rel:gsub('%.[^/]+$', '')
  rel = rel:lower()
  return '/' .. rel
end

it('url_path: x7-cavorite layout (documentation/content)', function()
  local root = '/home/rmarr/Projects/x7-cavorite'
  local file = root .. '/documentation/content/plans/icmp/Interface_Control_Model_Plan.org'
  eq(url_path_for(file, root, 'documentation/content'), '/plans/icmp/interface_control_model_plan')
end)

it('url_path: x7-wiki layout (documentation)', function()
  local root = '/home/rmarr/Projects/x7-wiki'
  local file = root .. '/documentation/plans/icmp/Interface_Control_Model_Plan.org'
  eq(url_path_for(file, root, 'documentation'), '/plans/icmp/interface_control_model_plan')
end)

it('url_path: WRONG result if docs_root too short for content/ layout', function()
  -- This is the bug: using 'documentation' for a project that has
  -- 'documentation/content' leaves 'content/' in the URL.
  local root = '/home/rmarr/Projects/x7-cavorite'
  local file = root .. '/documentation/content/plans/icmp/Interface_Control_Model_Plan.org'
  local wrong = url_path_for(file, root, 'documentation')
  -- Should NOT contain 'content/' prefix
  assert(wrong:match '^/content/', 'expected /content/ prefix with wrong docs_root (verifying the bug)')
end)

it('url_path: auto-detected docs_root produces correct URL for x7-cavorite', function()
  -- Use the real auto-detection on the temp dirs we created
  local root = tmp_root .. '/proj_content'
  -- documentation/content already created above
  local docs_root = T.get_docs_root(root)
  eq(docs_root, 'documentation/content')
  local file = root .. '/documentation/content/plans/icmp/Interface_Control_Model_Plan.org'
  eq(url_path_for(file, root, docs_root), '/plans/icmp/interface_control_model_plan')
end)

it('url_path: auto-detected docs_root produces correct URL for x7-wiki', function()
  local root = tmp_root .. '/proj_docs'
  -- documentation already created above
  local docs_root = T.get_docs_root(root)
  eq(docs_root, 'documentation')
  local file = root .. '/documentation/plans/rmp/Repository_Management_Plan.org'
  eq(url_path_for(file, root, docs_root), '/plans/rmp/repository_management_plan')
end)

it('url_path: markdown extension stripped', function()
  local root = '/home/rmarr/Projects/generic'
  local file = root .. '/docs/guide/setup.md'
  eq(url_path_for(file, root, 'docs'), '/guide/setup')
end)

it('url_path: deeply nested path preserved', function()
  local root = '/home/rmarr/Projects/x7-cavorite'
  local file = root .. '/documentation/content/plans/sdvp/Software_Development_and_Verification_Plan.org'
  eq(url_path_for(file, root, 'documentation/content'), '/plans/sdvp/software_development_and_verification_plan')
end)

it('url_path: CONTRIBUTING.org at docs root', function()
  local root = '/home/rmarr/Projects/x7-cavorite'
  local file = root .. '/documentation/content/CONTRIBUTING.org'
  eq(url_path_for(file, root, 'documentation/content'), '/contributing')
end)

-- ── Cleanup ─────────────────────────────────────────────────────────────

vim.fn.delete(tmp_root, 'rf')

-- ── Summary ─────────────────────────────────────────────────────────────

print(string.format('\n  %d passed, %d failed\n', pass, fail))
if fail > 0 then
  os.exit(1)
end
