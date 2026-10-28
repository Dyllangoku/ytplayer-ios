// ==UserScript==
// @name         YT 광고 차단기 (아이폰)
// @namespace    yt-adblock
// @version      1.0.1
// @description  유튜브·유튜브 뮤직: 광고 건너뛰기 + 광고 칸 숨김 + 화면을 꺼도/다른 앱을 써도 계속 재생
// @match        *://m.youtube.com/*
// @match        *://www.youtube.com/*
// @match        *://music.youtube.com/*
// @run-at       document-start
// @inject-into  page
// @grant        none
// ==/UserScript==

(() => {
  'use strict';
  if (!/(^|\.)youtube\.com$/.test(location.hostname)) return; // 유튜브 외(구글 로그인 등)에서는 아무것도 안 함
  if (window.__ytabIos) return;
  window.__ytabIos = true;

  // 영상이 안 나오거나 "광고 차단기 사용 불가" 경고가 뜨면 false로 바꾸세요.
  const STRONG = true;

  /* ───────── 1. 백그라운드 재생 ─────────
     유튜브는 화면이 꺼지거나 앱이 내려가면 스스로 영상을 멈춘다.
     → 유튜브에게는 '화면이 항상 보이는 중'이라고 알려 준다. */
  const realStateGetter = Object.getOwnPropertyDescriptor(Document.prototype, 'visibilityState').get;
  const reallyHidden = () => realStateGetter.call(document) === 'hidden';
  const fake = (obj, prop, value) => {
    try { Object.defineProperty(obj, prop, { configurable: true, get: () => value }); } catch (e) { /* 무시 */ }
  };
  fake(document, 'hidden', false);
  fake(document, 'webkitHidden', false);
  fake(document, 'visibilityState', 'visible');
  fake(document, 'webkitVisibilityState', 'visible');
  try { document.hasFocus = () => true; } catch (e) { /* 무시 */ }

  // 아이폰이 잠금/앱 전환 순간 저절로 멈춘 경우에만 다시 재생 (잠금화면에서 직접 누른 정지는 그대로)
  const WINDOW_MS = 1000;
  let hiddenAt = 0;
  let lastPause = null;
  let holdUntil = 0; // 앱이 일부러 멈춘 직후에는 다시 재생하지 않음 (탭 전환 등)
  window.__ytabPauseAll = () => {
    holdUntil = Date.now() + 3000;
    lastPause = null;
    document.querySelectorAll('video,audio').forEach((m) => m.pause());
  };
  // "계속 보시겠습니까?" 창 때문에 오래 듣다가 멈추지 않도록 활동 시각을 계속 갱신
  setInterval(() => { window._lact = Date.now(); }, 60000);
  const resume = (media) => setTimeout(() => {
    if (media.paused && !media.ended) media.play().catch(() => {});
  }, 300);

  const onVisibility = (e) => {
    e.stopImmediatePropagation(); // 유튜브에게는 전달하지 않음
    if (!reallyHidden()) return;
    hiddenAt = Date.now();
    if (lastPause && hiddenAt - lastPause.t < WINDOW_MS) resume(lastPause.media);
    lastPause = null;
  };
  for (const type of ['visibilitychange', 'webkitvisibilitychange']) {
    window.addEventListener(type, onVisibility, true);
  }

  document.addEventListener('pause', (e) => {
    const media = e.target;
    if (!(media instanceof HTMLMediaElement) || media.ended || inAd || Date.now() < holdUntil) return;
    const now = Date.now();
    if (reallyHidden() && now - hiddenAt < WINDOW_MS) resume(media);
    else lastPause = { media, t: now };
  }, true);

  /* ───────── 2. 강력 모드: 영상 정보에서 광고 일정 지우기 ───────── */
  if (STRONG) {
    const AD_KEYS = ['adPlacements', 'adSlots', 'playerAds', 'adBreakHeartbeatParams'];
    const prune = (obj) => {
      if (!obj || typeof obj !== 'object') return obj;
      for (const key of AD_KEYS) if (key in obj) delete obj[key];
      if (obj.playerResponse && typeof obj.playerResponse === 'object') prune(obj.playerResponse);
      if (Array.isArray(obj)) obj.forEach((item) => item && item.playerResponse && prune(item.playerResponse));
      return obj;
    };
    let initial;
    try {
      Object.defineProperty(window, 'ytInitialPlayerResponse', {
        configurable: true,
        get() { return initial; },
        set(value) { initial = prune(value); }
      });
    } catch (e) { /* 이미 정의돼 있으면 건너뜀 */ }
    const nativeParse = JSON.parse;
    JSON.parse = function (...args) {
      const result = nativeParse.apply(this, args);
      try { prune(result); } catch (e) { /* 무시 */ }
      return result;
    };
    const nativeJson = Response.prototype.json;
    Response.prototype.json = async function (...args) {
      const result = await nativeJson.apply(this, args);
      try { prune(result); } catch (e) { /* 무시 */ }
      return result;
    };
  }

  /* ───────── 3. 광고 칸 숨기기 (모바일·뮤직 포함) ───────── */
  const style = document.createElement('style');
  style.textContent = [
    '#masthead-ad', '#player-ads', 'ad-slot-renderer', 'ytd-ad-slot-renderer',
    'ytm-promoted-sparkles-web-renderer', 'ytm-promoted-video-renderer', 'ytm-companion-ad-renderer',
    'ytm-companion-slot', 'ytm-mealbar-promo-renderer', 'ytm-statement-banner-renderer',
    'ytm-rich-item-renderer:has(ad-slot-renderer)', 'ytd-rich-item-renderer:has(ytd-ad-slot-renderer)',
    'ytd-in-feed-ad-layout-renderer', 'ytd-banner-promo-renderer', 'ytd-promoted-sparkles-web-renderer',
    'ytmusic-mealbar-promo-renderer', 'ytmusic-statement-banner-renderer',
    '.ytp-ad-overlay-container', '.ytp-ad-overlay-slot', '.ytp-ad-image-overlay'
  ].join(',') + '{display:none!important}';
  // 문서 시작 직후엔 <html>이 아직 없을 수 있어 생길 때까지 기다렸다가 붙인다
  const addStyle = () => (document.head || document.documentElement).appendChild(style);
  if (document.documentElement) addStyle();
  else new MutationObserver((_, obs) => {
    if (document.documentElement) { obs.disconnect(); addStyle(); }
  }).observe(document, { childList: true });

  /* ───────── 4. 영상 광고 건너뛰기 ───────── */
  const SKIP = [
    '.ytp-skip-ad-button', '.ytp-ad-skip-button', '.ytp-ad-skip-button-modern',
    '.ytp-ad-skip-button-slot button', 'button[id^="skip-button"]'
  ];
  let inAd = false;
  let saved = null;

  const getPlayer = () => document.querySelector('#movie_player') || document.querySelector('.html5-video-player');
  const getVideo = (p) => p && (p.querySelector('video.html5-main-video') || p.querySelector('video'));

  function leaveAd(video) {
    if (!inAd) return;
    inAd = false;
    if (video && saved) {
      video.muted = saved.muted;
      if (video.playbackRate === 16) video.playbackRate = saved.rate || 1;
    }
    saved = null;
  }

  function tick() {
    try { tickInner(); } catch (e) { /* 유튜브 화면 구조가 바뀌어도 재생은 망가뜨리지 않음 */ }
  }

  function tickInner() {
    const player = getPlayer();
    const video = getVideo(player);
    if (!player || !video) return;
    player.querySelectorAll('.ytp-ad-overlay-close-button').forEach((b) => b.click());
    const isAd = player.classList.contains('ad-showing') || player.classList.contains('ad-interrupting');
    if (!isAd) { leaveAd(video); return; }
    if (!inAd) {
      inAd = true;
      saved = { muted: video.muted, rate: video.playbackRate === 16 ? 1 : video.playbackRate };
    }
    for (const sel of SKIP) { const b = player.querySelector(sel); if (b) b.click(); }
    video.muted = true;
    if (video.playbackRate !== 16) video.playbackRate = 16;
    // 광고가 영상에 붙어 오는 경우(duration = 본편 전체) 본편까지 건너뛰지 않도록 3분 미만일 때만 끝으로 이동
    if (Number.isFinite(video.duration) && video.duration > 0 && video.duration < 180 &&
        video.currentTime < video.duration) {
      video.currentTime = video.duration;
    }
  }

  const observer = new MutationObserver(tick);
  let observed = null;
  setInterval(() => {
    const player = getPlayer();
    if (player && player !== observed) {
      observer.disconnect();
      observer.observe(player, { attributes: true, attributeFilter: ['class'] });
      observed = player;
    }
    tick();
  }, 300);
})();
