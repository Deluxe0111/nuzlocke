// Documentation regression checks for v3 without rewriting 2.9.x history.
// Run: node tests/gen3_docs_gate.js
const fs=require("fs");
const path=require("path");
function read(p){return fs.readFileSync(p,"utf8");}
function check(ok,msg){if(!ok)throw new Error(msg);}
const manifest=JSON.parse(read("manifest.json"));
const readme=read("README.md");
const change=read("CHANGELOG.md");
const notes=read("RELEASE_NOTES.md");
const credits=read("CREDITS.md");
const matrix=read("docs/GEN3_FEATURE_MATRIX.md");
const overview=read("docs/GEN3_PORT.md");
const checklist=read("docs/GEN3_TEST_CHECKLIST.md");
check(manifest.version==="3.0.0-BETA","v3 manifest version drift");
check(readme.includes("v3.0.0-BETA")&&notes.includes("v3.0.0-BETA")
  &&change.includes("## 3.0.0-BETA"),"v3 release identity must match");
check(notes.indexOf("v3.0.0-BETA")<notes.indexOf("# Nuzlocke 2.9.72")
  &&change.indexOf("## 3.0.0-BETA")<change.indexOf("## 2.9.72"),
  "v3 must be separate from preceding release notes");
for(const old of ["2.9.72","2.9.71","2.9.70"]){
  check(change.includes("## "+old),
      "historical changelog entry missing: "+old);
}
for(const contributor of ["bryanthaboi","Stone696","masterwebx","Deluxe0111"]){
  check(credits.includes(contributor)&&readme.includes(contributor),
      "missing contributor credit: "+contributor);
}
for(const group of ["Ported","Adapted","New v3"]){
  check(matrix.includes(group),"feature classification missing "+group);
}
check(readme.includes("FireRed")&&readme.includes("LeafGreen")
  &&readme.includes("Ruby")&&readme.includes("Sapphire")
  &&readme.includes("Emerald"),"incomplete Gen 3 edition declaration");
check(overview.includes("RUN JOURNAL")&&overview.includes("MOD SUPPORT")
  &&checklist.includes("RUN JOURNAL"),"current navigation drift");
check(!/^.*(?:six other advanced groups remain|three other advanced categories remain|PC Survivors Allowed is still \[Soon\]).*$/im.test(overview+"\n"+checklist),
  "stale Gen 3 implementation label");
const files=[
 "README.md","RELEASE_NOTES.md","CREDITS.md",
 "docs/GEN3_FEATURE_MATRIX.md","docs/GEN3_PORT.md",
 "docs/GEN3_TEST_CHECKLIST.md","docs/GEN3_CORE_SPEC.md",
 "docs/GEN3_ADVANCED_RULES.md","docs/DEVELOPER_GEN3.md"
];
for(const p of files){
 let body=read(p);
 // RELEASE_NOTES has archived 2.9 entries with historical links/versions;
 // the section above the divider is the current-release document.
 if(p==="RELEASE_NOTES.md")body=body.split("\n---\n")[0];
 for(const m of body.matchAll(/\[[^\]\n]*\]\(([^)]+)\)/g)){
   const target=m[1].split("#")[0].trim();
   if(!target||/^https?:|^mailto:|^data:/.test(target))continue;
   check(fs.existsSync(path.resolve(path.dirname(p),decodeURIComponent(target))),
      "broken relative link in "+p+": "+target);
 }
}
console.log("Gen 3 release docs, credits, history and links: PASS");
