/* Offline cost explorer. Provider rates checked 2026-10-03; no network requests. */
(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const ns = 'http://www.w3.org/2000/svg';
  const money = n => '$' + n.toFixed(2);
  const controls = ['storage','compute','awake','ram'];
  const read = () => ({ storage: +$('storage').value, compute: +$('compute').value, awake: +$('awake').value, ram: +$('ram').value });
  function models(p) {
    return [
      {name:'Hetzner EU · CX33*', value:9.99*1.2+.60, color:'#278e81', dash:'', fn:()=>9.99*1.2+.60},
      {name:'Neon Launch', value:p.storage*.35+p.compute*.106*p.awake, color:'#377cdd', dash:'', fn:h=>p.storage*.35+p.compute*.106*h},
      {name:'Railway example†', value:Math.max(20,p.ram*10+2+p.storage*.15), color:'#9a73bc', dash:'7 4', fn:()=>Math.max(20,p.ram*10+2+p.storage*.15)},
      {name:'Hetzner US · CPX21', value:37.49*1.2+.60, color:'#c57621', dash:'3 4', fn:()=>37.49*1.2+.60},
      {name:'RDS medium · Single-AZ', value:.065*730+Math.max(20,p.storage)*.115, color:'#cc667d', dash:'12 4 3 4', fn:()=>.065*730+Math.max(20,p.storage)*.115}
    ];
  }
  function el(tag, attrs, text) {
    const node=document.createElementNS(ns,tag);
    Object.entries(attrs||{}).forEach(([k,v])=>node.setAttribute(k,String(v)));
    if(text!==undefined) node.textContent=String(text);
    return node;
  }
  function chart(id, title, desc, height) {
    const svg=$(id); svg.replaceChildren(); svg.setAttribute('viewBox',`0 0 900 ${height}`);
    svg.append(el('title',{},title),el('desc',{},desc)); return svg;
  }
  function render() {
    const p=read(), rows=models(p), max=Math.ceil(Math.max(...rows.map(r=>r.value))/10)*10;
    $('awake-value').textContent=p.awake+' h/month';
    const bar=chart('cost-bars','Monthly infrastructure cost under selected assumptions','Dollar values are also listed in the table below. Plans are not performance-equivalent.',355);
    const ordered=[...rows].sort((a,b)=>b.value-a.value);
    for(let i=0;i<=4;i++) {
      const x=250+i*540/4;
      bar.append(el('line',{x1:x,y1:20,x2:x,y2:315,class:'grid'}),el('text',{x,y:342,'text-anchor':'middle',class:'axis'},money(max*i/4)));
    }
    ordered.forEach((r,i)=>{
      const y=32+i*56;
      bar.append(el('text',{x:238,y:y+23,'text-anchor':'end',class:'label'},r.name));
      const rect=el('rect',{x:250,y,width:r.value/max*540,height:34,rx:4,fill:r.color});
      rect.append(el('title',{},r.name+': '+money(r.value))); bar.append(rect);
      bar.append(el('text',{x:260+r.value/max*540,y:y+23,class:'label'},money(r.value)));
    });
    const line=chart('cost-lines','Monthly cost against database awake hours','Neon rises with awake hours. Other lines hold their selected capacity and usage assumptions fixed. Dashed patterns and a legend distinguish providers.',395);
    const ymax=Math.ceil(Math.max(...rows.map(r=>r.fn(730)))/10)*10;
    const X=h=>65+h/730*800, Y=v=>330-v/ymax*295;
    for(let i=0;i<=5;i++) {
      const v=ymax*i/5,y=Y(v);
      line.append(el('line',{x1:65,y1:y,x2:865,y2:y,class:'grid'}),el('text',{x:55,y:y+5,'text-anchor':'end',class:'axis'},'$'+v.toFixed(0)));
    }
    for(const h of [0,120,240,360,480,600,730]) line.append(el('text',{x:X(h),y:354,'text-anchor':'middle',class:'axis'},h));
    rows.forEach(r=>line.append(el('path',{d:`M${X(0)},${Y(r.fn(0))} L${X(730)},${Y(r.fn(730))}`,fill:'none',stroke:r.color,'stroke-width':3,'stroke-dasharray':r.dash})));
    line.append(el('line',{x1:X(p.awake),x2:X(p.awake),y1:30,y2:330,class:'selection','stroke-dasharray':'2 5'}),el('text',{x:465,y:384,'text-anchor':'middle',class:'axis'},'Database awake hours per month (all clients and maintenance)'));
    const tbody=$('scenario-values'); tbody.replaceChildren();
    ordered.forEach(r=>{const tr=document.createElement('tr');for(const text of [r.name,money(r.value)]) {const td=document.createElement('td');td.textContent=text;tr.append(td);}tbody.append(tr);});
    const crossings=rows.filter(r=>r.name.startsWith('Hetzner')).map(r=>{
      const h=(r.value-p.storage*.35)/(p.compute*.106);
      const result=h<0?'cheaper than Neon storage alone':h>730?'no crossing within 730 hours':`Neon matches at ${h.toFixed(0)} awake hours/month`;
      return r.name+': '+result+'.';
    });
    $('break-even').textContent=crossings.join(' ');
    $('capacity-note').textContent=p.storage>=60?'Capacity warning: quoted server disks also need OS, WAL, indexes and working headroom. At this setting the Hetzner flat lines are not viable capacity quotes without sizing review; larger-server costs are excluded.':'* EU CX33 availability unverified; public page showed unavailable. Its 80 GB disk includes OS and working space. † Railway assumes 0.1 average vCPU and applies a $20 sole-workspace floor; do not allocate that floor twice when other services already cover it.';
  }
  controls.forEach(id=>$(id).addEventListener('input',render));
  render();
  // Pure calculations exposed only for local regression checks; contains no private data.
  window.hostingCostModels=models;
})();
