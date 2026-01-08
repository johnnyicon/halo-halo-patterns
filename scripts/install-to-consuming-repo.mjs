#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { execSync } from "node:child_process";

const __dirname = path.dirname(new URL(import.meta.url).pathname);
const repoRoot = path.resolve(__dirname, "..");

function ensureDir(p){fs.mkdirSync(p,{recursive:true});}
function copyDir(src,dst){
  ensureDir(dst);
  for(const e of fs.readdirSync(src,{withFileTypes:true})){
    const s=path.join(src,e.name), d=path.join(dst,e.name);
    if(e.isDirectory()) copyDir(s,d);
    else { ensureDir(path.dirname(d)); fs.copyFileSync(s,d); }
  }
}
function appendGitignore(targetRoot){
  const gi=path.join(targetRoot,".gitignore");
  const block=["","# Patterns local workspace (cases/scratch)",".patterns/local/**","!.patterns/local/README.md",""].join("\n");
  const existing=fs.existsSync(gi)?fs.readFileSync(gi,"utf8"):"";
  if(!existing.includes(".patterns/local/**")){
    fs.writeFileSync(gi, existing.trimEnd()+block, "utf8");
  }
}
function writeLocalReadme(targetRoot){
  const p=path.join(targetRoot,".patterns","local","README.md");
  if(!fs.existsSync(p)){
    fs.writeFileSync(p, "# Local Pattern Cases (Summary)\n\n> Safe to commit. Do not add sensitive details here.\n", "utf8");
  }
}
const args=process.argv.slice(2);
const opt=(k,def=null)=>{const i=args.indexOf(k); return i===-1?def:(args[i+1]??def);};
const target=path.resolve(opt("--target","."));
const catalogUrl=opt("--catalog-url", null);
const branch=opt("--branch","main");

ensureDir(path.join(target,".patterns","local","cases"));
ensureDir(path.join(target,".patterns","local","scratch"));

appendGitignore(target);
writeLocalReadme(target);

copyDir(path.join(repoRoot,"templates","consuming"), target);
console.log("✅ Templates copied and local folders created.");

if(catalogUrl && !args.includes("--skip-submodule")){
  try{
    execSync(`git submodule add -b ${branch} ${catalogUrl} .patterns/catalog`, {cwd: target, stdio:"inherit"});
  }catch(e){
    console.warn("⚠️ Submodule add failed; run manually:");
    console.warn(`   git submodule add -b ${branch} ${catalogUrl} .patterns/catalog`);
  }
} else {
  console.log("ℹ️ Submodule not added. Add it when ready:");
  console.log("   git submodule add <CATALOG_REPO_URL> .patterns/catalog");
}
