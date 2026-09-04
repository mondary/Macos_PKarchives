(function(){
"use strict";
var pk=window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.pk;
var mode="files",running=false,total=0,finished=0,items=[];
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
  return "<div class=\"thumb "+(item.textPreview&&!preview?"text":"")+"\">"+visual+"</div><div class=\"file-name\" title=\""+escapeHTML(item.name)+"\">"+escapeHTML(item.name)+"</div><div class=\"file-meta\"><span>"+escapeHTML(item.sizeTxt||"")+'</span><span class="file-state"></span></div><span class="check">✓</span><div class="progress"><i></i></div>';
}
function renderItems(ev){
  items=ev.items||[];$("sourceCount").textContent=items.length;$("sourceHint").textContent=items.length?"éléments archivables":"aucun élément archivable";$("archive").disabled=!items.length;
  var stack=$("sourceStack");stack.innerHTML="";
  if(!items.length){stack.innerHTML='<div class="empty"><div><strong>Bureau déjà propre</strong><span>Aucun élément éligible dans ce mode.</span></div></div>';return}
  items.forEach(function(item){var el=document.createElement("div");el.className="file";el.dataset.name=item.name;el.innerHTML=cardHTML(item);stack.appendChild(el)})
}
function renderScanError(ev){items=[];$("sourceCount").textContent="?";$("sourceHint").textContent="accès refusé ou dossier indisponible";$("archive").disabled=true;$("sourceStack").innerHTML='<div class="empty"><div><strong>Accès au dossier impossible</strong><span>'+escapeHTML(ev.path||"Le dossier source")+'<br>Ouvrez les réglages et choisissez le dossier manuellement.</span></div></div>';setStatus("Scan impossible","error");log("Impossible de lire le dossier source")}
function findCard(name){return Array.prototype.find.call(document.querySelectorAll("#sourceStack .file"),function(el){return el.dataset.name===name})}
function fly(name){var card=findCard(name);if(!card)return;card.classList.add("uploading");var bar=card.querySelector(".progress i");bar.style.width="0%";var ghost=card.cloneNode(true);ghost.className="flying";ghost.style.left=(card.offsetLeft+8)+"px";ghost.style.top=(card.offsetTop+8)+"px";ghost.style.transform="translate(0,0)";$("sourceStack").appendChild(ghost);requestAnimationFrame(function(){ghost.classList.add("to-drive")});setTimeout(function(){ghost.remove()},1200)}
function handle(ev){
  switch(ev.type){
    case"items":renderItems(ev);if(ev.source)$("sourcePath").textContent=ev.source;break;
    case"scanError":renderScanError(ev);break;
    case"desktopChosen":$("desktop").value=ev.path||"";break;
    case"dest":$("destination").textContent=ev.name||"Google Drive";$("destinationShort").textContent=ev.short||"Dossier cloud";break;
    case"settings":$("folder").value=ev.folderId||"";$("desktop").value=ev.desktop||"";$("remote").value=ev.remote||"gdrive";break;
    case"run":total=ev.total||0;finished=0;$("archiveCount").textContent="0";break;
    case"status":setStatus(ev.text||"En cours…",running?"busy":"");log(ev.text||"En cours…");break;
    case"log":log(ev.line||"",ev.cls==="ok");break;
    case"uploadStart":fly(ev.name);break;
    case"progress":{var c=findCard(ev.name);if(c){c.classList.add("uploading");c.querySelector(".progress i").style.width=Math.max(0,Math.min(100,ev.pct||0))+"%"}break}
    case"uploaded":{var uploaded=findCard(ev.name);if(uploaded){uploaded.classList.remove("uploading");uploaded.classList.add("done");uploaded.querySelector(".file-state").textContent="archivé"}finished++;$("archiveCount").textContent=finished;break}
    case"deleted":{var deleted=findCard(ev.name);if(deleted){deleted.style.opacity="0";deleted.style.transform="translateY(8px)";setTimeout(function(){deleted.remove();$("sourceCount").textContent=document.querySelectorAll("#sourceStack .file").length},260)}break}
    case"failed":{var failed=findCard(ev.name);if(failed){failed.classList.remove("uploading");failed.classList.add("failed")}break}
    case"runDone":running=false;$("archive").disabled=!document.querySelector("#sourceStack .file");$("cancel").style.display="none";setStatus(ev.ok?"Terminé · "+(ev.success||0)+" archivé(s)":"Échec",""+(ev.ok?"":"error"));log(ev.ok?"Archivage terminé":"Archivage interrompu",ev.ok);break;
  }
}
window.__pkEvent=function(value){var ev=typeof value==="string"?JSON.parse(value):value;handle(ev)};
window.__pkStart=function(nextMode){setMode(nextMode==="all"?"all":"files");if(!running){running=true;$("archive").disabled=true;$("cancel").style.display="inline-block";setStatus("Préparation…","busy");send("archive",{mode:mode})}};
$("mFiles").onclick=function(){setMode("files")};$("mAll").onclick=function(){setMode("all")};
$("archive").onclick=function(){if(running)return;running=true;$("archive").disabled=true;$("cancel").style.display="inline-block";setStatus("Préparation…","busy");send("archive",{mode:mode})};$("cancel").onclick=function(){send("cancel")};
$("chooseDesktop").onclick=function(){send("chooseDesktop")};$("gear").onclick=function(){send("settingsReq");$("drawer").classList.add("open")};$("close").onclick=function(){$("drawer").classList.remove("open")};$("save").onclick=function(){send("saveSettings",{folderId:$("folder").value,desktop:$("desktop").value,remote:$("remote").value,permanent:false});$("drawer").classList.remove("open")};$("logButton").onclick=function(){var l=$("log");l.style.display=l.style.display==="none"?"block":"none"};
 $("destination").parentElement.onclick=function(){send("openDrive")};
 $("drawer").onclick=function(e){if(e.target===$("drawer"))$("drawer").classList.remove("open")};
 send("ready");
})();
