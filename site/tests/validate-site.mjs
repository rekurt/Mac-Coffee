import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";

const siteRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const required = ["index.html", "styles.css", "i18n.js", "script.js"];

for (const file of required) {
  assert.ok(existsSync(join(siteRoot, file)), `Missing ${file}`);
}

const html = readFileSync(join(siteRoot, "index.html"), "utf8");
const ids = [...html.matchAll(/\sid="([^"]+)"/g)].map((match) => match[1]);
assert.equal(ids.length, new Set(ids).size, "HTML IDs must be unique");

for (const [, anchor] of html.matchAll(/href="#([^"]+)"/g)) {
  assert.ok(ids.includes(anchor), `Missing internal anchor #${anchor}`);
}

for (const [tag] of html.matchAll(/<img\b[^>]*>/g)) {
  assert.match(tag, /\salt="[^"]*"/, `Image requires alt: ${tag}`);
  assert.match(tag, /\swidth="\d+"/, `Image requires width: ${tag}`);
  assert.match(tag, /\sheight="\d+"/, `Image requires height: ${tag}`);
}

for (const [, asset] of html.matchAll(/(?:src|href)="((?:assets\/|styles\.css|i18n\.js|script\.js)[^"]*)"/g)) {
  const cleanPath = asset.split(/[?#]/)[0];
  assert.ok(existsSync(join(siteRoot, cleanPath)), `Missing local asset ${cleanPath}`);
}

for (const [tag] of html.matchAll(/<a\b[^>]*target="_blank"[^>]*>/g)) {
  assert.match(tag, /rel="[^"]*noopener[^"]*"/, `External target requires noopener: ${tag}`);
}

for (const phrase of [
  "Your agents don’t sleep",
  "maccoffee_set_session",
  "Settings → AI & automation",
  "Battery protection",
  "No cloud backend",
  "lid closure",
]) {
  assert.ok(html.includes(phrase), `Missing required narrative: ${phrase}`);
}

const context = {};
vm.runInNewContext(readFileSync(join(siteRoot, "i18n.js"), "utf8"), context);
const translations = context.MacCoffeeTranslations;
assert.ok(translations?.en && translations?.ru, "English and Russian dictionaries are required");
assert.deepEqual(Object.keys(translations.ru).sort(), Object.keys(translations.en).sort(), "Language keys differ");

const keys = [
  ...html.matchAll(/data-i18n(?:-aria)?="([^"]+)"/g),
].map((match) => match[1]);
for (const key of new Set(keys)) {
  assert.ok(key in translations.en, `Missing English translation for ${key}`);
  assert.ok(key in translations.ru, `Missing Russian translation for ${key}`);
}

new vm.Script(readFileSync(join(siteRoot, "script.js"), "utf8"));
console.log(`Validated ${ids.length} IDs and ${new Set(keys).size} translation keys.`);
