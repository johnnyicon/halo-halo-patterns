#!/usr/bin/env python3
"""Render the hosting research as an offline HTML report. Requires Python markdown."""
from pathlib import Path
import html
import markdown

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/database-hosting-and-idle-workers-2026-10.md'
JS = ROOT / 'docs/assets/database-hosting-explorer.js'
CSS = '''
*{box-sizing:border-box}body{margin:0;background:#f3f1ec;color:#21313b;font:17px/1.65 system-ui,sans-serif}main{max-width:1180px;margin:28px auto;background:#fff;padding:44px 52px;border:1px solid #d9deda;border-radius:14px}h1{font-size:2.4rem;line-height:1.14;letter-spacing:-.035em}h2{font-size:1.5rem;margin-top:2.4em;padding-top:.5em;border-top:1px solid #dbe2e4}h3{font-size:1.12rem}a{color:#12607a;text-underline-offset:3px}table{border-collapse:collapse;display:block;overflow:auto;width:100%;font-size:.88rem;margin:24px 0}th,td{padding:12px;border-bottom:1px solid #dce3e5;text-align:left;vertical-align:top}th{background:#e8f0f1}code{font-size:.88em;overflow-wrap:anywhere}li{margin:.5em 0}.toc{padding:12px 24px;background:#f1f5f4;border-radius:8px;font-size:.9rem}.toc li{margin:.1em 0}.note,.caption{font-size:.86rem;color:#4e6570}.controls{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;padding:20px;background:#edf3f3;border-radius:8px}.controls label{font-size:.9rem;font-weight:600}.controls input,.controls select{display:block;width:100%;min-height:44px;margin-top:6px;padding:6px;font:inherit;color:inherit;background:var(--control,#fff);border:1px solid #728c98;border-radius:5px}input[type=range]{padding:0}input:focus-visible,select:focus-visible,a:focus-visible,summary:focus-visible{outline:3px solid #217ba0;outline-offset:3px}.chart-wrap{overflow:auto}.chart-wrap svg{width:100%;min-width:600px;display:block}.grid{stroke:#cbd6db;stroke-width:1}.axis{fill:currentColor;font-size:14px}.label{fill:currentColor;font-size:16px}.selection{stroke:currentColor}.legend{display:flex;flex-wrap:wrap;gap:10px 20px;font-size:.87rem}.legend span{display:inline-flex;align-items:center;gap:8px}.legend svg{width:40px;height:12px}#break-even{padding:14px 18px;border-left:4px solid #278e81;background:#edf5f2;font-weight:600}summary{cursor:pointer;padding:10px;min-height:44px}details table{margin-top:0}@media(max-width:760px){main{margin:0;padding:22px;border:0;border-radius:0}h1{font-size:1.9rem}.controls{grid-template-columns:1fr 1fr;padding:14px}.chart-wrap{border:1px solid #dce3e5}}@media(prefers-color-scheme:dark){body{background:#121b21;color:#e0e9ed}main{background:#1d2a32;border-color:#3c515d}a{color:#89d3e5}h2,th,td{border-color:#435760}th,.toc,.controls{background:#283e46;--control:#20343e}.note,.caption{color:#b5c9d1}.grid{stroke:#435760}#break-even{background:#243b36}}@media print{body,main{background:white;color:black}main{padding:0;margin:0;border:0;max-width:none}.toc,.controls{display:none}.chart-wrap svg{min-width:0}table{display:table;font-size:9pt}h2,h3{break-after:avoid}.chart-wrap{break-inside:avoid}a{color:inherit}}
'''
EXPLORER = '''
<section aria-label="Interactive infrastructure cost comparison">
<div class="controls">
<label for="storage">Database storage (GB)<select id="storage"><option>10</option><option selected>20</option><option>40</option><option>60</option><option>80</option><option>100</option></select></label>
<label for="compute">Neon compute while awake<select id="compute"><option value="0.25">0.25 CU</option><option value="0.5" selected>0.5 CU</option><option value="1">1 CU</option><option value="2">2 CU</option></select></label>
<label for="ram">Railway average RAM<select id="ram"><option value="1">1 GB</option><option value="2" selected>2 GB</option><option value="4">4 GB</option><option value="8">8 GB</option></select></label>
<label for="awake">Awake time: <output id="awake-value" for="awake">240 h/month</output><input id="awake" type="range" min="0" max="730" value="240" step="1"></label>
</div>
<p class="caption">Default: 20 GB, Neon 0.5 CU and 240 awake hours, Railway 2 GB RAM and 0.1 average vCPU. Database infrastructure only. No performance equivalence, tax, application hosting, independent backup, traffic overage or labor included. Hetzner includes IPv4 + server backup; other backup charges vary.</p>
<h3>1. Monthly cost at the selected usage</h3>
<div class="chart-wrap"><svg id="cost-bars" role="img" aria-label="Monthly infrastructure cost bar chart"></svg></div>
<details><summary>Exact chart values (accessible data table)</summary><table><thead><tr><th scope="col">Configuration</th><th scope="col">USD/month</th></tr></thead><tbody id="scenario-values"></tbody></table></details>
<h3>2. When does a fixed server become cheaper?</h3>
<div class="chart-wrap"><svg id="cost-lines" role="img" aria-label="Cost against database awake hours"></svg></div>
<div class="legend" aria-label="Line styles"><span><svg aria-hidden="true"><path d="M0 6H40" stroke="#278e81" stroke-width="3"/></svg>Hetzner EU</span><span><svg aria-hidden="true"><path d="M0 6H40" stroke="#377cdd" stroke-width="3"/></svg>Neon</span><span><svg aria-hidden="true"><path d="M0 6H40" stroke="#9a73bc" stroke-width="3" stroke-dasharray="7 4"/></svg>Railway example</span><span><svg aria-hidden="true"><path d="M0 6H40" stroke="#c57621" stroke-width="3" stroke-dasharray="3 4"/></svg>Hetzner US</span><span><svg aria-hidden="true"><path d="M0 6H40" stroke="#cc667d" stroke-width="3" stroke-dasharray="12 4 3 4"/></svg>RDS medium</span></div>
<p class="caption">Only Neon's awake hours vary on this graph. Railway's line holds average CPU/RAM fixed—it is not a fixed-price service. RDS and Hetzner hold the chosen instance/server capacity fixed. All hours include users, agents, indexing and maintenance.</p>
<p id="break-even" aria-live="polite"></p><p id="capacity-note" class="caption"></p>
<noscript><p>Interactive charts require JavaScript. The monthly comparison, crossover explanation and matrix below contain the same default assumptions and prices.</p></noscript>
</section>
'''

def main():
    source=SOURCE.read_text()
    lines=source.splitlines(); lines.insert(2, '[TOC]')
    body=markdown.markdown('\n'.join(lines),extensions=['tables','fenced_code','toc'],extension_configs={'toc':{'toc_depth':'2-3'}})
    assert '<!-- hosting-cost-explorer -->' in body
    body=body.replace('<!-- hosting-cost-explorer -->',EXPLORER)
    title=html.escape(source.splitlines()[0].lstrip('# '))
    script=JS.read_text(); assert '</script' not in script.lower()
    out='<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+title+'</title><style>'+CSS+'</style></head><body><main><p class="note">Hosting research · 3 October 2026 · Estimates, not measured bills</p>'+body+'</main><script>'+script+'</script></body></html>'
    SOURCE.with_suffix('.html').write_text(out)
    print(SOURCE.with_suffix('.html'))
if __name__=='__main__': main()
