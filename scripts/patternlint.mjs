#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import matter from "gray-matter";
import Ajv from "ajv";

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const repoRoot = path.resolve(__dirname, "..");

function readJSON(p){return JSON.parse(fs.readFileSync(p,"utf8"));}
function walk(dir){
  const out=[];
  for(const e of fs.readdirSync(dir,{withFileTypes:true})){
    const p=path.join(dir,e.name);
    if(e.isDirectory()) out.push(...walk(p));
    else out.push(p);
  }
  return out;
}
function getAllPatternFiles(dir){
  if(!fs.existsSync(dir)) return [];
  return walk(dir).filter(p=>p.endsWith(".md"));
}
function hasSection(md, heading){
  const esc = heading.replace(/[.*+?^${}()|[\]\\]/g,"\\$&");
  return new RegExp(`^##\\s+${esc}\\s*$`,"m").test(md);
}
function extractBodyChars(md){return md.replace(/^---[\s\S]*?---\s*/m,"").trim().length;}
function normalizeTitle(s){return (s||"").toLowerCase().replace(/[^a-z0-9\s-]/g,"").replace(/\s+/g," ").trim();}
function levenshteinRatio(a,b){
  a=normalizeTitle(a); b=normalizeTitle(b);
  if(!a&&!b) return 1; if(!a||!b) return 0;
  const m=a.length,n=b.length;
  const dp=Array.from({length:m+1},()=>new Array(n+1).fill(0));
  for(let i=0;i<=m;i++) dp[i][0]=i;
  for(let j=0;j<=n;j++) dp[0][j]=j;
  for(let i=1;i<=m;i++) for(let j=1;j<=n;j++){
    const cost=a[i-1]===b[j-1]?0:1;
    dp[i][j]=Math.min(dp[i-1][j]+1,dp[i][j-1]+1,dp[i-1][j-1]+cost);
  }
  const dist=dp[m][n], maxLen=Math.max(m,n);
  return maxLen===0?1:1-dist/maxLen;
}
function compileSan(san){
  const mk=(r)=>({name:r.name, re:new RegExp(r.regex, r.flags||"")});
  return {block:(san.block||[]).map(mk), warn:(san.warn||[]).map(mk)};
}
function scan(content, compiled){
  const blocked=[], warned=[];
  for(const r of compiled.block) if(r.re.test(content)) blocked.push(r.name);
  for(const r of compiled.warn) if(r.re.test(content)) warned.push(r.name);
  return {blocked, warned};
}
function getReqSections(lifecycle, type){
  return lifecycle?.validated_requirements?.required_sections_by_type?.[type]||[];
}
function todayISO(){return new Date().toISOString().slice(0,10);}

async function main(){
  const args=process.argv.slice(2);
  const cmd=args[0];
  const opt=(k,def=null)=>{const i=args.indexOf(k); return i===-1?def:(args[i+1]??def);};
  if(!cmd||cmd==="--help"||cmd==="-h"){
    console.log("patternlint validate|sanitize-scan|index|staleness [--root <path>] [--patterns <dir>]");
    process.exit(0);
  }
  const root=path.resolve(opt("--root", repoRoot));
  const patternsDir=path.join(root, opt("--patterns","patterns"));
  const schema=readJSON(path.join(root,"schema","pattern.schema.json"));
  const lifecycle=readJSON(path.join(root,"rules","lifecycle.json"));
  const sanRules=readJSON(path.join(root,"rules","sanitization.json"));
  const gate=readJSON(path.join(root,"rules","gatekeeper.json"));
  const ajv=new Ajv({allErrors:true});
  const validateSchema=ajv.compile(schema);
  const compiled=compileSan(sanRules);
  const files=getAllPatternFiles(patternsDir);

  if(cmd==="sanitize-scan"){
    let failed=false;
    for(const f of files){
      const content=fs.readFileSync(f,"utf8");
      const s=scan(content, compiled);
      if(s.warned.length) console.warn(`WARN ${path.relative(root,f)}: ${s.warned.join(", ")}`);
      if(s.blocked.length){console.error(`BLOCK ${path.relative(root,f)}: ${s.blocked.join(", ")}`); failed=true;}
    }
    process.exit(failed?1:0);
  }

  if(cmd==="validate"){
    let failed=false;
    const meta=[];
    for(const f of files){
      const raw=fs.readFileSync(f,"utf8");
      const parsed=matter(raw);
      meta.push({file:f,id:parsed.data?.id,title:parsed.data?.title,domain:parsed.data?.domain,tags:parsed.data?.tags||[]});
    }
    for(const f of files){
      const raw=fs.readFileSync(f,"utf8");
      const parsed=matter(raw);
      const data=parsed.data||{};
      const body=parsed.content||"";

      const ok=validateSchema(data);
      if(!ok){
        failed=true;
        console.error(`SCHEMA FAIL ${path.relative(root,f)}`);
        for(const e of (validateSchema.errors||[])){
          console.error(`  - ${e.instancePath||"(root)"} ${e.message}`);
        }
      }

      const s=scan(raw, compiled);
      if(s.warned.length) console.warn(`WARN ${path.relative(root,f)}: ${s.warned.join(", ")}`);
      if(s.blocked.length){console.error(`SANITIZE BLOCK ${path.relative(root,f)}: ${s.blocked.join(", ")}`); failed=true;}

      if(data.status==="validated"){
        const req=getReqSections(lifecycle, data.type);
        for(const sec of req){
          if(!hasSection(body, sec)){
            failed=true;
            console.error(`STRUCTURE FAIL ${path.relative(root,f)}: missing ## ${sec}`);
          }
        }
        const min=lifecycle?.validated_requirements?.min_body_chars||0;
        const chars=extractBodyChars(raw);
        if(chars<min){failed=true; console.error(`STRUCTURE FAIL ${path.relative(root,f)}: body too short (${chars}<${min})`);}
        for(const fld of (lifecycle?.validated_requirements?.required_front_matter_fields||[])){
          if(!data[fld] || (Array.isArray(data[fld]) && data[fld].length===0)){
            failed=true;
            console.error(`FRONTMATTER FAIL ${path.relative(root,f)}: missing/empty ${fld}`);
          }
        }
      }

      // similarity warnings
      const self=meta.find(m=>m.file===f);
      if(self?.id){
        for(const other of meta){
          if(other.file===f||!other.id) continue;
          const sameDomain=self.domain && other.domain && self.domain===other.domain;
          const overlap=new Set((self.tags||[]).filter(t=>(other.tags||[]).includes(t))).size;
          const lev=levenshteinRatio(self.title||"", other.title||"");
          const minOverlap=gate?.similarity_triggers_consolidate?.same_domain_and_tag_overlap?.min_tag_overlap??3;
          const levThresh=gate?.similarity_triggers_consolidate?.or_title_levenshtein_ratio??0.70;
          if((sameDomain && overlap>=minOverlap) || (lev>=levThresh)){
            console.warn(`SIMILARITY WARN ${self.id} ~ ${other.id}: domain_match=${sameDomain} tag_overlap=${overlap} title_ratio=${lev.toFixed(2)}`);
          }
        }
      }
    }
    process.exit(failed?1:0);
  }

  if(cmd==="index"){
    const rows=[];
    for(const f of files){
      const {data}=matter(fs.readFileSync(f,"utf8"));
      rows.push({domain:data.domain,id:data.id,title:data.title,type:data.type,status:data.status,path:path.relative(root,f).replace(/\\/g,"/")});
    }
    rows.sort((a,b)=>(a.domain||"").localeCompare(b.domain||"") || (a.id||"").localeCompare(b.id||""));
    const lines=["# Patterns Index","","> Auto-generated by `patternlint index`.","","| Domain | ID | Title | Type | Status | Path |","|---|---|---|---|---|---|"];
    for(const r of rows){lines.push(`| ${r.domain} | \`${r.id}\` | ${r.title} | ${r.type} | ${r.status} | \`${r.path}\` |`);}
    fs.writeFileSync(path.join(root,"INDEX.md"), lines.join("\n")+"\n","utf8");
    console.log(`Wrote INDEX.md (${rows.length} patterns)`);
    process.exit(0);
  }

  if(cmd==="staleness"){
    const today=todayISO();
    const overdue=[], deprecatedRefs=[];
    const byId=new Map();
    for(const f of files){
      const {data}=matter(fs.readFileSync(f,"utf8"));
      if(data?.id) byId.set(data.id,{status:data.status,file:f});
    }
    for(const f of files){
      const {data}=matter(fs.readFileSync(f,"utf8"));
      if(data.status==="validated" && data.review_by && data.review_by<today){
        overdue.push({id:data.id,review_by:data.review_by,maintainers:data.maintainers||[],file:path.relative(root,f)});
      }
      for(const rel of (data.related||[])){
        const ref=byId.get(rel);
        if(ref?.status==="deprecated"){
          deprecatedRefs.push({id:data.id,references:rel,file:path.relative(root,f)});
        }
      }
    }
    console.log(JSON.stringify({generated_at:new Date().toISOString(), overdue, deprecatedRefs}, null, 2));
    process.exit(0);
  }

  console.error(`Unknown command: ${cmd}`);
  process.exit(2);
}
main().catch(e=>{console.error(e); process.exit(1);});
