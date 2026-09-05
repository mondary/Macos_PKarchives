(function(){
"use strict";
var pk=window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.pk;
 var mode="files",running=false,total=0,finished=0,items=[],refreshTimer;
function send(cmd,data){if(pk)try{pk.postMessage(Object.assign({cmd:cmd},data||{}));}catch(e){}}
function $(id){return document.getElementById(id)}
function setStatus(text,kind){$("status").textContent=text;$("state").className="state "+(kind||"")}
function log(text,good){$("log").innerHTML=(good?"<b>":"")+text+(good?"</b>":"");$("transferLabel").textContent=text}
function setMode(next){mode=next;$("mFiles").classList.toggle("on",mode==="files");$("mAll").classList.toggle("on",mode==="all");send("rescan",{mode:mode})}
function escapeHTML(s){return String(s||"").replace(/[&<>\"]/g,function(c){return{"&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;"}[c]})}
function icon(kind){return kind==="folder"?"▰":"◻"}
function cardHTML(item){
  var preview=item.ext==="html"?(item.preview||item.thumb):(item.textPreview?null:(item.preview||item.thumb));
  var visual=preview?"<img src=\""+preview+"\" alt=\"Aperçu de "+escapeHTML(item.name)+"\">":(item.textPreview?"<div class=\"text\">"+escapeHTML(item.textPreview)+"</div>":icon(item.kind));
  return "<div class=\"thumb "+(item.textPreview&&!preview?"text":"")+"\">"+visual+"<span class=\"fill\"></span></div><div class=\"file-name\" title=\""+escapeHTML(item.name)+"\">"+escapeHTML(item.name)+"</div><div class=\"file-meta\"><span>"+escapeHTML(item.sizeTxt||"")+'</span><span class="file-state"></span></div><span class="check">✓</span>';
}
function renderItems(ev){
  items=ev.items||[];$("sourceCount").textContent=items.length;$("sourceHint").textContent=items.length?"éléments archivables":"aucun élément archivable";$("archive").disabled=!items.length;
  var stack=$("sourceStack");stack.innerHTML="";
  if(!items.length){stack.innerHTML='<div class="empty"><div><strong>Bureau déjà propre</strong><span>Aucun élément éligible dans ce mode.</span></div></div>';return}
  items.forEach(function(item){var el=document.createElement("div");el.className="file";el.dataset.name=item.name;el.innerHTML=cardHTML(item);stack.appendChild(el)})
}
function renderScanError(ev){items=[];$("sourceCount").textContent="?";$("sourceHint").textContent="accès refusé ou dossier indisponible";$("archive").disabled=true;$("sourceStack").innerHTML='<div class="empty"><div><strong>Accès au dossier impossible</strong><span>'+escapeHTML(ev.path||"Le dossier source")+'<br>Ouvrez les réglages et choisissez le dossier manuellement.</span></div></div>';setStatus("Scan impossible","error");log("Impossible de lire le dossier source")}
function fmtBytes(b){return b>=1073741824?(b/1073741824).toFixed(1).replace(".",",")+" Go":b>=1048576?Math.round(b/1048576)+" Mo":b>=1024?Math.round(b/1024)+" Ko":b+" o"}
function renderHistory(ev){var runs=ev.runs||[],years={};runs.forEach(function(r){var d=new Date(r.date),y=d.getFullYear();(years[y]||(years[y]=[])).push(r)});var ys=Object.keys(years).sort().reverse();var current=$("historyYear").value||String(new Date().getFullYear());if(!years[current]&&ys.length)current=ys[0];$("historyYear").innerHTML=ys.map(function(y){return '<option>'+y+'</option>'}).join("")||'<option>'+new Date().getFullYear()+'</option>';$("historyYear").value=current;var months=Array(12).fill(0);(years[current]||[]).forEach(function(r){months[new Date(r.date).getMonth()]+=r.success||0});var max=Math.max.apply(null,months.concat([1]));$("historyTotal").textContent=months.reduce(function(a,b){return a+b},0);$("historyBytes").textContent=ev.bytes?fmtBytes(ev.bytes):"0";$("historyBars").innerHTML=months.map(function(v,i){return '<i class="bar" title="'+["Jan","Fév","Mar","Avr","Mai","Juin","Juil","Août","Sep","Oct","Nov","Déc"][i]+': '+v+' fichier(s)" style="height:'+Math.max(4,Math.round(v/max*78))+'px"></i>'}).join("");$("historyMonths").innerHTML=["Jan","Fév","Mar","Avr","Mai","Juin","Juil","Août","Sep","Oct","Nov","Déc"].map(function(m){return "<span>"+m+"</span>"}).join("");$("historyEmpty").style.display=months.some(Boolean)?"none":"block"}
function findCard(name){return Array.prototype.find.call(document.querySelectorAll("#sourceStack .file"),function(el){return el.dataset.name===name})}
function fly(name){var card=findCard(name);if(!card)return;card.classList.add("uploading");var fill=card.querySelector(".fill");if(fill)fill.style.height="10%";var ghost=card.cloneNode(true);ghost.className="flying";ghost.style.left=(card.offsetLeft+8)+"px";ghost.style.top=(card.offsetTop+8)+"px";ghost.style.transform="translate(0,0)";$("sourceStack").appendChild(ghost);var ds=$("driveStack").getBoundingClientRect(),cr=card.getBoundingClientRect(),dx=ds.left+ds.width/2-(cr.left+cr.width/2),dy=ds.top+ds.height/2-(cr.top+cr.height/2);requestAnimationFrame(function(){ghost.classList.add("to-drive");ghost.style.transform="translate("+dx+"px,"+dy+"px) rotate(5deg) scale(.85)"});setTimeout(function(){ghost.remove()},900)}
function handle(ev){
  switch(ev.type){
    case"items":renderItems(ev);if(ev.source)$("sourcePath").textContent=ev.source;break;
    case"scanError":renderScanError(ev);break;
    case"desktopChosen":$("desktop").value=ev.path||"";break;
    case"history":renderHistory(ev);break;
    case"dest":$("destination").textContent=ev.name||"Google Drive";$("destinationShort").textContent=ev.short||"Dossier cloud";break;
    case"settings":$("folder").value=ev.folderId||"";$("desktop").value=ev.desktop||"";$("remote").value=ev.remote||"gdrive";break;
    case"run":total=ev.total||0;finished=0;$("archiveCount").textContent="0";$("driveStack").innerHTML='<div class="empty"><div><strong>Aucun fichier archivé</strong><span>Les fichiers arrivent ici pendant un archivage.</span></div></div>';break;
    case"status":setStatus(ev.text||"En cours…",running?"busy":"");log(ev.text||"En cours…");break;
    case"log":log(ev.line||"",ev.cls==="ok");break;
    case"uploadStart":fly(ev.name);break;
    case"progress":{var c=findCard(ev.name);if(c){c.classList.add("uploading");var f=c.querySelector(".fill");if(f)f.style.height=Math.max(0,Math.min(100,ev.pct||0))+"%"}break}
    case"uploaded":{var uploaded=findCard(ev.name);if(uploaded){uploaded.classList.remove("uploading");uploaded.classList.add("done");var pf=uploaded.querySelector(".fill");if(pf)pf.style.height="100%";uploaded.querySelector(".file-state").textContent="archivé"}var ds=$("driveStack"),empty=ds.querySelector(".empty");if(empty)empty.remove();var chip=document.createElement("div");chip.className="drive-chip";chip.innerHTML="<span class=\"ok\">✓</span><span class=\"n\">"+escapeHTML(ev.name)+"</span>";ds.appendChild(chip);finished++;$("archiveCount").textContent=finished;break}
    case"deleted":{var deleted=findCard(ev.name);if(deleted){deleted.style.opacity="0";deleted.style.transform="translateY(8px)";setTimeout(function(){deleted.remove();$("sourceCount").textContent=document.querySelectorAll("#sourceStack .file").length},260)}break}
    case"failed":{var failed=findCard(ev.name);if(failed){failed.classList.remove("uploading");failed.classList.add("failed");var ff=failed.querySelector(".fill");if(ff)ff.style.height="0%"}break}
    case"runDone":running=false;$("archive").disabled=!document.querySelector("#sourceStack .file");$("cancel").style.display="none";setStatus(ev.ok?"Terminé · "+(ev.success||0)+" archivé(s)":"Échec",""+(ev.ok?"":"error"));log(ev.ok?"Archivage terminé":"Archivage interrompu",ev.ok);break;
  }
}
window.__pkEvent=function(value){var ev=typeof value==="string"?JSON.parse(value):value;handle(ev)};
window.__pkStart=function(nextMode){setMode(nextMode==="all"?"all":"files");if(!running){running=true;$("archive").disabled=true;$("cancel").style.display="inline-block";setStatus("Préparation…","busy");send("archive",{mode:mode})}};
$("mFiles").onclick=function(){setMode("files")};$("mAll").onclick=function(){setMode("all")};
$("archive").onclick=function(){if(running)return;running=true;$("archive").disabled=true;$("cancel").style.display="inline-block";setStatus("Préparation…","busy");send("archive",{mode:mode})};$("cancel").onclick=function(){send("cancel")};
$("chooseDesktop").onclick=function(){send("chooseDesktop")};$("gear").onclick=function(){send("settingsReq");$("drawer").classList.add("open")};$("close").onclick=function(){$("drawer").classList.remove("open")};$("save").onclick=function(){send("saveSettings",{folderId:$("folder").value,desktop:$("desktop").value,remote:$("remote").value,permanent:false});$("drawer").classList.remove("open")};$("logButton").onclick=function(){var h=$("history");h.classList.toggle("open");if(h.classList.contains("open"))send("historyReq")};
 $("destination").parentElement.onclick=function(){send("openDrive")};
 $("openFinder").onclick=function(){send("openFinder")};
 $("openDriveBtn").onclick=function(){send("openDrive")};
 $("drawer").onclick=function(e){if(e.target===$("drawer"))$("drawer").classList.remove("open")};
 $("logButton").addEventListener("click",function(e){e.preventDefault();e.stopPropagation();var h=$("history"),open=h.classList.toggle("open");h.style.display=open?"block":"none";if(open)send("historyReq")},true);
 $("closeHistory").onclick=function(e){e.preventDefault();e.stopPropagation();$("history").classList.remove("open");$("history").style.display="none"};
 $("historyYear").onchange=function(){send("historyReq")};
  document.addEventListener("click",function(){if(running)return;clearTimeout(refreshTimer);refreshTimer=setTimeout(function(){send("rescan",{mode:mode})},250)});
  send("ready");
})();
