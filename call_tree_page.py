#!/usr/bin/env python3
"""
call_tree_page.py - call_graph.json -> call_tree.html, a self-contained viewer of Mappy's call tree.

The page shows what call_tree.txt shows (each routine expanded once, at its first place in a
depth-first walk from RESET, NMI, IRQ), plus each routine's callers and callees with their edge
kinds, and a search. No data is written by hand: run call_graph.py, then this.

  call_tree_page.py [out.html]      (default: call_tree.html beside this file)
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).parent

PAGE = r"""<title>Mappy Call Tree</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;500;600&family=Instrument+Sans:wght@400;500;600&display=swap">
<style>
/* Layout: a header strip with the counts and legend, then the tree beside a routine panel (stacked on phones). */
:root {
  --bg: #f6f7fa; --surface: #ffffff; --fg: #1b2130; --muted: #5d6679; --line: #dde1ea;
  --accent: #2346c8; --hilite: #fff3c4;
  --k-jmp: #8a5a00; --k-flow: #0f7a5c; --k-dispatch: #b3261e; --k-inline: #b25e09; --k-task: #6b2fb3;
  --mono: "IBM Plex Mono", ui-monospace, "Cascadia Mono", Consolas, monospace;
  --sans: "Instrument Sans", system-ui, "Segoe UI", sans-serif;
}
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) {
  --bg: #11141b; --surface: #181c25; --fg: #e3e6ee; --muted: #949db0; --line: #2a303d;
  --accent: #8fa7ff; --hilite: #3b3415;
  --k-jmp: #e2b45c; --k-flow: #5fd1ac; --k-dispatch: #ff8a80; --k-inline: #f5a35a; --k-task: #c39bff;
  color-scheme: dark } }
:root[data-theme="dark"] {
  --bg: #11141b; --surface: #181c25; --fg: #e3e6ee; --muted: #949db0; --line: #2a303d;
  --accent: #8fa7ff; --hilite: #3b3415;
  --k-jmp: #e2b45c; --k-flow: #5fd1ac; --k-dispatch: #ff8a80; --k-inline: #f5a35a; --k-task: #c39bff;
  color-scheme: dark }
body { background: var(--bg); color: var(--fg); font-family: var(--sans); font-size: 14px; }
.wrap { padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px));
  padding-block: 20px 32px; max-width: 1280px; margin: 0 auto; display: grid; gap: 16px; }
header { display: grid; gap: 10px; }
h1 { font-family: var(--mono); font-weight: 600; font-size: 20px; margin: 0; letter-spacing: -0.01em; text-wrap: balance; }
.sub { color: var(--muted); margin: 0; max-width: 72ch; line-height: 1.5; }
.stats { display: flex; flex-wrap: wrap; gap: 6px 18px; font-family: var(--mono); font-size: 12.5px; color: var(--muted);
  font-variant-numeric: tabular-nums; }
.stats b { color: var(--fg); font-weight: 600; }
.legend { display: flex; flex-wrap: wrap; gap: 6px; }
.legend button { font: inherit; font-size: 12.5px; display: inline-flex; gap: 6px; align-items: center; cursor: help;
  background: var(--surface); border: 1px solid var(--line); border-radius: 999px; padding: 3px 10px; color: var(--fg); }
.legend button[aria-pressed="true"] { outline: 2px solid var(--accent); outline-offset: 1px; }
.legend .n { color: var(--muted); font-family: var(--mono); font-variant-numeric: tabular-nums; }
.kdesc { color: var(--muted); font-size: 13px; min-height: 1.4em; margin: 0; }
.tools { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; position: relative; }
.tools input { font: inherit; font-family: var(--mono); font-size: 13px; padding: 7px 10px; border-radius: 6px;
  border: 1px solid var(--line); background: var(--surface); color: var(--fg); width: min(340px, 100%); }
.tools button { font: inherit; font-size: 13px; padding: 6px 12px; border-radius: 6px; border: 1px solid var(--line);
  background: var(--surface); color: var(--fg); cursor: pointer; }
.tools button:hover, .legend button:hover { border-color: var(--accent); }
:focus-visible { outline: 2px solid var(--accent); outline-offset: 2px; }
.results { position: absolute; top: 100%; left: 0; z-index: 5; margin-top: 4px; width: min(420px, 100%);
  background: var(--surface); border: 1px solid var(--line); border-radius: 8px; box-shadow: 0 8px 24px rgb(0 0 0 / .18);
  max-height: 320px; overflow: auto; }
.results button { display: flex; justify-content: space-between; gap: 12px; width: 100%; text-align: left; border: 0;
  border-bottom: 1px solid var(--line); border-radius: 0; background: transparent; font-family: var(--mono); font-size: 12.5px; padding: 7px 10px; }
.results button:hover, .results button.on { background: var(--hilite); }
main { display: grid; grid-template-columns: minmax(0, 1fr) 340px; gap: 16px; align-items: start; }
@media (max-width: 820px) { main { grid-template-columns: minmax(0, 1fr); } }
.tree { background: var(--surface); border: 1px solid var(--line); border-radius: 10px; padding: 10px 0; overflow-x: auto; }
.vec { font-family: var(--mono); font-size: 11.5px; letter-spacing: .08em; text-transform: uppercase; color: var(--muted);
  padding: 12px 14px 4px; }
.vec:first-child { padding-top: 2px; }
.row { display: flex; align-items: center; gap: 6px; white-space: nowrap; font-family: var(--mono); font-size: 13px;
  padding: 2px 14px 2px 0; line-height: 1.55; cursor: pointer; }
.row:hover { background: color-mix(in srgb, var(--accent) 7%, transparent); }
.row.sel { background: var(--hilite); }
.tog { width: 18px; flex: 0 0 18px; text-align: center; color: var(--muted); border: 0; background: none; font: inherit; cursor: pointer; padding: 0; }
.tog:disabled { visibility: hidden; }
.nm { color: var(--fg); }
.nm.anon { color: var(--muted); font-style: italic; }
.ad { color: var(--muted); font-size: 11.5px; }
.ref { color: var(--accent); font-size: 11.5px; }
.badge { font-size: 10.5px; font-family: var(--sans); font-weight: 600; letter-spacing: .02em; padding: 0 6px; border-radius: 4px;
  border: 1px solid currentColor; line-height: 1.5; }
.k-jmp { color: var(--k-jmp); } .k-flows-into { color: var(--k-flow); } .k-dispatch { color: var(--k-dispatch); }
.k-inline { color: var(--k-inline); } .k-task { color: var(--k-task); } .k-call { color: var(--muted); }
.dim { opacity: .35; }
aside { position: sticky; top: calc(env(safe-area-inset-top, 0px) + 12px); background: var(--surface); border: 1px solid var(--line);
  border-radius: 10px; padding: 14px; display: grid; gap: 12px; max-height: calc(100vh - 24px); overflow: auto; min-width: 0; }
@media (max-width: 820px) { aside { position: static; max-height: none; } }
aside h2 { font-family: var(--mono); font-size: 15px; font-weight: 600; margin: 0; overflow-wrap: anywhere; }
aside h3 { font-size: 11.5px; letter-spacing: .08em; text-transform: uppercase; color: var(--muted); margin: 0 0 6px; font-weight: 600; }
aside .path { font-family: var(--mono); font-size: 12px; color: var(--muted); line-height: 1.6; overflow-wrap: anywhere; }
aside ul { list-style: none; margin: 0; padding: 0; display: grid; gap: 2px; }
aside li button { display: flex; gap: 6px; align-items: center; width: 100%; text-align: left; border: 0; background: none;
  font-family: var(--mono); font-size: 12.5px; color: var(--fg); padding: 3px 4px; border-radius: 4px; cursor: pointer; flex-wrap: wrap; }
aside li button:hover { background: var(--hilite); }
.empty { color: var(--muted); font-size: 13px; }
@media (prefers-reduced-motion: no-preference) { .row.flash { animation: flash 1.2s ease-out; }
  @keyframes flash { from { background: color-mix(in srgb, var(--accent) 30%, transparent); } } }
</style>

<div class="wrap">
  <header>
    <h1 id="title">Mappy call tree</h1>
    <p class="sub">Every routine reached from the 6502 vectors, with how it is reached. A routine expands once, at its first
      place in a depth-first walk from RESET, NMI and IRQ; anywhere else it links back there. Plain JSR calls carry no badge.</p>
    <div class="stats" id="stats"></div>
    <div class="legend" id="legend" role="group" aria-label="Edge kinds"></div>
    <p class="kdesc" id="kdesc">Select an edge kind to fade every other kind.</p>
    <div class="tools">
      <input id="q" type="search" placeholder="Find a routine: name or $address" autocomplete="off" aria-label="Find a routine">
      <button id="exp" type="button">Expand 3 levels</button>
      <button id="col" type="button">Collapse all</button>
      <div class="results" id="res" hidden></div>
    </div>
  </header>
  <main>
    <div class="tree" id="tree" role="tree" aria-label="Call tree"></div>
    <aside id="panel" aria-live="polite"></aside>
  </main>
</div>

<script id="graph" type="application/json">__DATA__</script>
<script>
(() => {
  const G = JSON.parse(document.getElementById('graph').textContent);
  const DESC = {
    "call": "JSR to another routine.",
    "jmp": "JMP to another routine: a tail call, or a jump back to a loop head.",
    "flows-into": "No call at all: the routine's code runs on into the next routine, by falling through or branching into it.",
    "dispatch": "JMP (indirect) through a jump table; one edge per handler in the table.",
    "inline": "JSR to the dispatcher at $F49F, which jumps through the word table placed right after the call.",
    "task": "The reset-time task switch: the stack is swapped and the game task starts. The switch back (swap_stack_pointer) returns into the other task, which no static edge can show."
  };
  const VEC_AT = { "C031": "RESET $FFFC", "C2EF": "NMI $FFFA", "C304": "IRQ $FFFE" };
  const name = a => G.nodes[a] || ('sub_' + a);
  const anon = a => !G.nodes[a] || /^sub_/.test(G.nodes[a]);
  const succ = {}, pred = {};
  for (const a in G.nodes) { succ[a] = []; pred[a] = []; }
  for (const [s, d, ks] of G.edges) { succ[s].push({ a: d, ks }); pred[d].push({ a: s, ks }); }
  for (const a in succ) { succ[a].sort((x, y) => x.a < y.a ? -1 : 1); pred[a].sort((x, y) => x.a < y.a ? -1 : 1); }
  const roots = ["C031", "C2EF", "C304"].filter(a => a in G.nodes);

  // first place of each routine in the depth-first walk (the same walk call_tree.txt prints)
  const parent = {}, seen = new Set();
  const visit = (v, p) => { if (seen.has(v)) return; seen.add(v); parent[v] = p; for (const e of succ[v]) visit(e.a, v); };
  roots.forEach(r => visit(r, null));

  const count = {}; G.kinds.forEach(k => count[k] = 0);
  G.edges.forEach(([, , ks]) => ks.forEach(k => count[k]++));
  document.getElementById('title').textContent = G.title.replace(/ \(.*\)/, '') + ' call tree';
  document.getElementById('stats').innerHTML =
    `<span><b>${Object.keys(G.nodes).length}</b> routines</span><span><b>${G.edges.length}</b> edges</span>` +
    `<span><b>${seen.size}</b> of ${Object.keys(G.nodes).length} reached from a vector</span><span>source: call_graph.py</span>`;

  let focusKind = null;
  const legend = document.getElementById('legend'), kdesc = document.getElementById('kdesc');
  G.kinds.forEach(k => {
    const b = document.createElement('button'); b.type = 'button'; b.setAttribute('aria-pressed', 'false');
    b.innerHTML = `<span class="badge k-${k}">${k}</span><span class="n">${count[k]}</span>`;
    b.title = DESC[k];
    b.onclick = () => { focusKind = focusKind === k ? null : k;
      legend.querySelectorAll('button').forEach(x => x.setAttribute('aria-pressed', 'false'));
      if (focusKind) b.setAttribute('aria-pressed', 'true');
      kdesc.textContent = focusKind ? DESC[focusKind] : 'Select an edge kind to fade every other kind.';
      applyFocus(); };
    b.onmouseenter = () => { if (!focusKind) kdesc.textContent = DESC[k]; };
    b.onmouseleave = () => { if (!focusKind) kdesc.textContent = 'Select an edge kind to fade every other kind.'; };
    legend.appendChild(b);
  });
  const badges = ks => ks.filter(k => k !== 'call').map(k => `<span class="badge k-${k}" title="${DESC[k]}">${k}</span>`).join('');

  const tree = document.getElementById('tree');
  const rowOf = {};                         // address -> its first-place row element
  function makeRow(v, depth, ks, first) {
    const row = document.createElement('div');
    row.className = 'row'; row.dataset.a = v; row.dataset.ks = ks.join(' ');
    row.setAttribute('role', 'treeitem');
    row.style.paddingLeft = (8 + depth * 18) + 'px';
    const kids = first ? succ[v] : [];
    row.innerHTML = `<button class="tog" type="button" aria-label="expand" ${kids.length ? '' : 'disabled'}>▸</button>` +
      `<span class="nm${anon(v) ? ' anon' : ''}">${name(v)}</span>${badges(ks)}` +
      (first ? `<span class="ad">$${v}</span>` : `<span class="ref">↗ $${v}, expanded at its first place</span>`);
    const box = document.createElement('div'); box.hidden = true; box.setAttribute('role', 'group');
    row._box = box; row._depth = depth; row._open = false;
    if (first) rowOf[v] = row;
    row.querySelector('.tog').onclick = ev => { ev.stopPropagation(); toggle(row); };
    row.onclick = () => { select(v); if (!first) reveal(v); };
    const wrap = document.createDocumentFragment(); wrap.append(row, box);
    return wrap;
  }
  function fill(row) {
    if (row._filled) return; row._filled = true;
    const v = row.dataset.a;
    for (const e of succ[v]) row._box.appendChild(makeRow(e.a, row._depth + 1, e.ks, parent[e.a] === v && !rowOf[e.a]));
    applyFocus(row._box);
  }
  function toggle(row, open) {
    const v = row.dataset.a; if (!succ[v].length || row.querySelector('.tog').disabled) return;
    row._open = open === undefined ? !row._open : open;
    if (row._open) fill(row);
    row._box.hidden = !row._open;
    const t = row.querySelector('.tog'); t.textContent = row._open ? '▾' : '▸';
    t.setAttribute('aria-label', row._open ? 'collapse' : 'expand'); row.setAttribute('aria-expanded', row._open);
  }
  function applyFocus(scope = tree) {
    scope.querySelectorAll('.row').forEach(r => r.classList.toggle('dim',
      !!focusKind && !r.dataset.ks.split(' ').includes(focusKind) && !(r._depth === 0)));
  }
  function build() {
    tree.innerHTML = ''; for (const k in rowOf) delete rowOf[k];
    roots.forEach(r => {
      const h = document.createElement('div'); h.className = 'vec'; h.textContent = VEC_AT[r]; tree.appendChild(h);
      tree.appendChild(makeRow(r, 0, [], true));
    });
  }
  function reveal(v) {
    const chain = []; for (let x = v; x; x = parent[x]) chain.unshift(x);
    for (const x of chain.slice(0, -1)) { const r = rowOf[x]; if (r) toggle(r, true); }
    const r = rowOf[v]; if (!r) return;
    r.scrollIntoView({ block: 'center', behavior: matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' });
    r.classList.remove('flash'); void r.offsetWidth; r.classList.add('flash');
  }

  const panel = document.getElementById('panel');
  function list(items, empty) {
    if (!items.length) return `<p class="empty">${empty}</p>`;
    return '<ul>' + items.map(e => `<li><button type="button" data-go="${e.a}"><span class="nm${anon(e.a) ? ' anon' : ''}">${name(e.a)}</span>` +
      `${badges(e.ks)}<span class="ad">$${e.a}</span></button></li>`).join('') + '</ul>';
  }
  function select(v) {
    tree.querySelectorAll('.row.sel').forEach(r => r.classList.remove('sel'));
    tree.querySelectorAll(`.row[data-a="${v}"]`).forEach(r => r.classList.add('sel'));
    const chain = []; for (let x = v; x; x = parent[x]) chain.unshift(x);
    panel.innerHTML = `<div><h2>${name(v)}</h2><div class="ad">$${v}${VEC_AT[v] ? ' · vector ' + VEC_AT[v] : ''}</div></div>` +
      `<div><h3>First reached by</h3><div class="path">${chain.map(name).join(' → ')}</div></div>` +
      `<div><h3>Callers (${pred[v].length})</h3>${list(pred[v], VEC_AT[v] ? 'Entered by the CPU through its vector.' : 'None.')}</div>` +
      `<div><h3>Callees (${succ[v].length})</h3>${list(succ[v], 'None: a leaf.')}</div>`;
    panel.querySelectorAll('[data-go]').forEach(b => b.onclick = () => { select(b.dataset.go); reveal(b.dataset.go); });
  }

  const q = document.getElementById('q'), res = document.getElementById('res');
  let hits = [], hi = 0;
  function search() {
    const s = q.value.trim().toLowerCase().replace(/^\$/, '');
    if (!s) { res.hidden = true; return; }
    hits = Object.keys(G.nodes).filter(a => a.toLowerCase().startsWith(s) || name(a).toLowerCase().includes(s)).slice(0, 30);
    hi = 0;
    res.innerHTML = hits.length ? hits.map((a, i) => `<button type="button" data-i="${i}" class="${i ? '' : 'on'}"><span>${name(a)}</span><span class="ad">$${a}</span></button>`).join('')
      : '<p class="empty" style="padding:8px 10px;margin:0">No routine matches.</p>';
    res.hidden = false;
    res.querySelectorAll('button').forEach(b => b.onclick = () => go(hits[+b.dataset.i]));
  }
  function go(a) { res.hidden = true; q.value = name(a); select(a); reveal(a); }
  q.addEventListener('input', search);
  q.addEventListener('keydown', ev => {
    if (res.hidden || !hits.length) return;
    if (ev.key === 'ArrowDown' || ev.key === 'ArrowUp') { ev.preventDefault();
      hi = (hi + (ev.key === 'ArrowDown' ? 1 : hits.length - 1)) % hits.length;
      res.querySelectorAll('button').forEach((b, i) => b.classList.toggle('on', i === hi)); }
    if (ev.key === 'Enter') { ev.preventDefault(); go(hits[hi]); }
    if (ev.key === 'Escape') res.hidden = true;
  });
  document.addEventListener('click', ev => { if (!ev.target.closest('.tools')) res.hidden = true; });

  function expandTo(n) {
    const walk = (row, d) => { if (d >= n) return; toggle(row, true);
      row._box.querySelectorAll(':scope > .row').forEach(r => { if (rowOf[r.dataset.a] === r) walk(r, d + 1); }); };
    roots.forEach(r => walk(rowOf[r], 0));
  }
  document.getElementById('exp').onclick = () => expandTo(3);
  document.getElementById('col').onclick = () => { build(); };

  build(); expandTo(2); select('C031');
})();
</script>
"""


def main(out=None):
    data = json.loads((HERE / "call_graph.json").read_text(encoding="utf-8"))
    html = PAGE.replace("__DATA__", json.dumps(data, separators=(",", ":")).replace("</", "<\\/"))
    out = Path(out) if out else HERE / "call_tree.html"
    out.write_text(html, encoding="utf-8")
    print(f"wrote {out} ({len(html):,} bytes)")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)
