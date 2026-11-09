<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>Frame Slideshow</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  html,body { width:100%; height:100%; background:#000; overflow:hidden; cursor:none; }
  #stage { position:fixed; inset:0; background:#000; }
  .layer { position:absolute; inset:0; opacity:0; transition:opacity 1200ms ease-in-out; }
  .layer.show { opacity:1; }
  .bg  { position:absolute; inset:0; background-size:cover; background-position:center; filter:blur(28px) brightness(0.55); transform:scale(1.12); }
  .fg  { position:absolute; inset:0; background-size:contain; background-position:center; background-repeat:no-repeat; }
</style>
</head>
<body>
<div id="stage">
  <div class="layer" id="a"><div class="bg"></div><div class="fg"></div></div>
  <div class="layer" id="b"><div class="bg"></div><div class="fg"></div></div>
</div>
<script>
"use strict";
var BASE = [
__URLS__
];
var DWELL = 8000;
var FG = "=w1920-h1080";
var BG = "=w640-h360";
function shuffle(a){ a=a.slice(); for(var i=a.length-1;i>0;i--){var j=Math.floor(Math.random()*(i+1));var t=a[i];a[i]=a[j];a[j]=t;} return a; }
var order = shuffle(BASE), pos = 0;
var layers = [document.getElementById('a'), document.getElementById('b')];
var cur = 0, dead = 0;
function nextUrl(){ if(pos>=order.length){ order=shuffle(BASE); pos=0; } return order[pos++]; }
function preload(url){ return new Promise(function(res,rej){ var im=new Image(); im.onload=function(){res(url);}; im.onerror=function(){rej(url);}; im.src=url+FG; }); }
function paint(layer,url){ layer.querySelector('.bg').style.backgroundImage="url('"+url+BG+"')"; layer.querySelector('.fg').style.backgroundImage="url('"+url+FG+"')"; }
function show(idx){ layers[idx].classList.add('show'); layers[1-idx].classList.remove('show'); }
function step(){
  var url=nextUrl();
  preload(url).then(function(ok){
    dead=0; var nxt=1-cur; paint(layers[nxt],ok);
    requestAnimationFrame(function(){ requestAnimationFrame(function(){ show(nxt); cur=nxt; setTimeout(step,DWELL); }); });
  }).catch(function(){ dead++; if(dead>BASE.length){ setTimeout(step,3000); } else { step(); } });
}
(function start(){ var u=nextUrl(); preload(u).then(function(ok){ paint(layers[0],ok); show(0); cur=0; setTimeout(step,DWELL); }).catch(function(){ step(); }); })();
document.addEventListener('contextmenu',function(e){e.preventDefault();});
document.addEventListener('dragstart',function(e){e.preventDefault();});
</script>
</body>
</html>
