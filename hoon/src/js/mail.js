// =============================================================================
// Urbit Mail - Combined JavaScript
// Extracted from src/lib/mail-ui.hoon inline Sail script blocks
// =============================================================================

// =============================================================================
// Section 1: Main JS (markdown, dates, copy, polling, theme, drafts, etc.)
// Original: lines 400-690
// =============================================================================

if (window.innerWidth <= 600) {
  document.querySelectorAll('.label-details').forEach(function(d) {
    d.removeAttribute('open');
  });
  document.querySelectorAll('.msg-details').forEach(function(d) {
    d.removeAttribute('open');
  });
}
document.querySelectorAll('.date[data-da]').forEach(function(el) {
  var da = el.dataset.da;
  var m = da.match(/~(\d+)\.(\d+)\.(\d+)\.\.(\d+)\.(\d+)\.(\d+)/);
  if (m) {
    var d = new Date(Date.UTC(+m[1], m[2]-1, +m[3], +m[4], +m[5], +m[6]));
    el.textContent = d.toLocaleString();
  }
});
var hasImages = false;
document.querySelectorAll('.message-body').forEach(function(el) {
  var t = el.textContent;
  t = t.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  t = t.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
  t = t.replace(/^(#{1,4})\s+(.+)$/gm, function(m, hashes, text) {
    var n = hashes.length;
    return '<h' + (n+1) + ' class="md-heading">' + text + '</h' + (n+1) + '>';
  });
  t = t.replace(/(^&gt;\s?.*(\n|$))+/gm, function(block) {
    var inner = block.replace(/^&gt;\s?/gm, '').replace(/^\s*\n/gm, '<br>').trim();
    return '<blockquote class="md-quote">' + inner + '</blockquote>';
  });
  t = t.replace(/(^\s*[\*\-]\s+.+(\n|$))+/gm, function(block) {
    var items = block.trim().split('\n').map(function(line) {
      return '<li>' + line.replace(/^\s*[\*\-]\s+/, '') + '</li>';
    }).join('');
    return '<ul>' + items + '</ul>';
  });
  t = t.replace(/(^\s*\d+[\.\)]\s+.+(\n|$))+/gm, function(block) {
    var items = block.trim().split('\n').map(function(line) {
      return '<li>' + line.replace(/^\s*\d+[\.\)]\s+/, '') + '</li>';
    }).join('');
    return '<ol>' + items + '</ol>';
  });
  t = t.replace(/\[\s*!\[([^\]]*)\]\(([^)]*)\)\s*\]\(<?([^)>\s]+)>?\)/g, function(m, alt, iurl, url) {
    hasImages = true; var a = alt.trim() || 'image'; url = safeUrl(url); iurl = safeUrl(iurl);
    return '<span class="img-wrap" style="display:none"><a href="' + url + '" target="_blank" rel="noopener"><img data-src="' + iurl + '" alt="' + a + '"></a></span><span class="img-placeholder"><a href="' + url + '" target="_blank" rel="noopener" class="img-link">\ud83d\uddbc ' + a + '</a></span>';
  });
  t = t.replace(/\[\s*\[Image:\s*([^\]]*)\]\s*\]\(<?([^)>\s]+)>?\)/g, function(m, alt, url) {
    hasImages = true; var a = alt.trim() || 'image'; url = safeUrl(url);
    return '<a href="' + url + '" target="_blank" rel="noopener" class="img-link">\ud83d\uddbc ' + a + '</a>';
  });
  function safeUrl(u) { return (/^https?:\/\//i.test(u) || /^\/mail\//i.test(u)) ? u : '#'; }
  t = t.replace(/!\[([^\]]*)\]\((https?:\/\/[^)\s]+)\)/g, function(m, alt, iurl) {
    hasImages = true; var a = alt || 'image'; iurl = safeUrl(iurl);
    return '<span class="img-wrap" style="display:none"><a href="' + iurl + '" target="_blank" rel="noopener"><img data-src="' + iurl + '" alt="' + a + '"></a></span><span class="img-placeholder">[Image: ' + a + ']</span>';
  });
  t = t.replace(/\[Image:\s*([^\]]*)\]\(<?([^)>\s]+)>?\)/g, function(m, alt, url) {
    hasImages = true; var a = alt.trim() || 'image'; url = safeUrl(url);
    return '<a href="' + url + '" target="_blank" rel="noopener" class="img-link">\ud83d\uddbc ' + a + '</a>';
  });
  t = t.replace(/\[([^\]]+)\]\(<?([^)>\s]+)>?\)/g, function(m, text, url) {
    url = safeUrl(url);
    var extra = /^\/mail\//.test(url) ? '' : ' target="_blank" rel="noopener"';
    return '<a href="' + url + '"' + extra + '>' + text.trim() + '</a>';
  });
  t = t.replace(/(^|[^"'>])(https?:\/\/[^\s<]+)/g, function(m, pre, url) {
    return pre + '<a href="' + url + '" target="_blank" rel="noopener">' + url + '</a>';
  });
  t = t.replace(/\n/g, '<br>');
  el.innerHTML = t;
  if (hasImages) {
    var btn = document.createElement('button');
    btn.className = 'img-toggle';
    btn.textContent = 'Show images';
    btn.addEventListener('click', function() {
      var show = btn.textContent === 'Show images';
      btn.textContent = show ? 'Hide images' : 'Show images';
      if (show) { el.querySelectorAll('.img-wrap img[data-src]').forEach(function(img) { img.src = img.dataset.src; img.removeAttribute('data-src'); }); }
      el.querySelectorAll('.img-wrap').forEach(function(w) { w.style.display = show ? 'block' : 'none'; });
      el.querySelectorAll('.img-placeholder').forEach(function(p) { p.style.display = show ? 'none' : 'inline'; });
    });
    el.parentNode.insertBefore(btn, el);
  }
});
function copyText(text) {
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text);
    return;
  }
  var ta = document.createElement('textarea');
  ta.value = text;
  ta.style.position = 'fixed';
  ta.style.left = '-9999px';
  document.body.appendChild(ta);
  ta.select();
  document.execCommand('copy');
  document.body.removeChild(ta);
}
function showToast(msg) {
  var t = document.getElementById('toast');
  if (!t) return;
  t.textContent = msg || 'Copied!';
  t.classList.add('show');
  setTimeout(function() { t.classList.remove('show'); }, 1500);
}
document.querySelectorAll('.copy-btn').forEach(function(btn) {
  btn.addEventListener('click', function(e) {
    e.stopPropagation();
    copyText(btn.dataset.copy);
    showToast('Copied: ' + btn.dataset.copy);
  });
});
document.querySelectorAll('tr[data-href]').forEach(function(tr) {
  tr.addEventListener('click', function(e) {
    if (e.target.tagName === 'A' || e.target.tagName === 'BUTTON' || e.target.tagName === 'INPUT' || e.target.closest('form')) return;
    window.location = tr.dataset.href;
  });
});
document.querySelectorAll('.sortable').forEach(function(th) {
  th.classList.add('desc');
  th.addEventListener('click', function() {
    var tbody = th.closest('table').querySelector('tbody');
    if (!tbody) return;
    var rows = Array.from(tbody.querySelectorAll('tr'));
    var asc = th.classList.contains('desc');
    rows.sort(function(a, b) {
      var da = a.querySelector('.date'); var db = b.querySelector('.date');
      if (!da || !db) return 0;
      var ta = da.dataset.da || ''; var tb = db.dataset.da || '';
      return asc ? ta.localeCompare(tb) : tb.localeCompare(ta);
    });
    rows.forEach(function(r) { tbody.appendChild(r); });
    th.classList.toggle('asc', asc);
    th.classList.toggle('desc', !asc);
  });
});
var overlay = document.getElementById('img-overlay');
var overlayImg = document.getElementById('img-overlay-img');
document.querySelectorAll('.img-wrap img').forEach(function(img) {
  img.addEventListener('click', function() {
    overlayImg.src = img.src;
    overlay.classList.add('show');
  });
});
if (overlay) overlay.addEventListener('click', function() { overlay.classList.remove('show'); });
var palette = ['#3498db','#e74c3c','#2ecc71','#9b59b6','#e67e22','#1abc9c','#34495e','#f39c12','#d35400','#8e44ad','#27ae60','#c0392b','#16a085','#2980b9','#e84393','#00b894','#6c5ce7','#fdcb6e','#e17055','#00cec9','#a29bfe','#fab1a0','#55efc4','#74b9ff','#ff7675','#fd79a8','#636e72','#b2bec3','#0984e3','#d63031','#00b4d8','#e76f51','#2a9d8f','#264653','#f4a261','#a8dadc','#457b9d','#bc6c25','#606c38','#dda15e'];
function hashStr(s) { var h = 0; for (var i = 0; i < s.length; i++) { h = ((h << 5) - h) + s.charCodeAt(i); h = h & h; } return Math.abs(h); }
document.querySelectorAll('.label-badge').forEach(function(el) {
  var text = el.textContent.trim().replace(/\s*x$/, '');
  el.style.background = palette[hashStr(text) % palette.length];
});
document.querySelectorAll('.label-dot').forEach(function(el) {
  var name = el.dataset.label;
  if (name) el.style.background = palette[hashStr(name) % palette.length];
});
(function() {
  var pg = document.body.dataset.page;
  var knownTotal = -1, knownUnread = -1, knownPendingGw = -1;
  var lastEtag = null;
  function poll() {
    var opts = {credentials: 'same-origin'};
    if (lastEtag) opts.headers = {'If-None-Match': lastEtag};
    fetch('/mail/api/status', opts)
      .then(function(r) {
        if (r.status === 304) return null;
        var etag = r.headers.get('etag');
        if (etag) lastEtag = etag;
        return r.json();
      })
      .then(function(data) {
        if (!data) return;
        var badge = document.querySelector('nav .badge');
        var link = document.querySelector('.nav-links a[href="/mail"]');
        if (data.unread > 0) {
          if (badge) { badge.textContent = data.unread; }
          else if (link) {
            var s = document.createElement('span');
            s.className = 'badge';
            s.textContent = data.unread;
            link.appendChild(s);
          }
        } else if (badge) { badge.remove(); }
        var gwLink = document.querySelector('nav a[href="/mail/gateway"]');
        if (gwLink) {
          var gwBadge = gwLink.querySelector('.badge');
          if (data.pending_gw > 0) {
            if (gwBadge) { gwBadge.textContent = data.pending_gw; }
            else {
              var gs = document.createElement('span');
              gs.className = 'badge';
              gs.textContent = data.pending_gw;
              gwLink.appendChild(gs);
            }
          } else if (gwBadge) { gwBadge.remove(); }
        }
        if (pg === 'inbox' && knownTotal >= 0 && data.total !== knownTotal) {
          window.location.reload();
        }
        if (pg === 'gateway' && data.pending_gw !== knownPendingGw && knownPendingGw >= 0) {
          window.location.reload();
        }
        if (pg !== 'inbox' && knownUnread >= 0 && data.unread > knownUnread) {
          showToast('New mail! (' + data.unread + ' unread)');
        }
        knownTotal = data.total;
        knownUnread = data.unread;
        knownPendingGw = data.pending_gw;
        // recovery banner
        if (data.recovered_from && !document.getElementById('recovery-banner')) {
          var banner = document.createElement('div');
          banner.id = 'recovery-banner';
          banner.style.cssText = 'background:var(--color-warning);color:#fff;padding:12px 20px;text-align:center;position:fixed;top:0;left:0;right:0;z-index:9999;';
          banner.textContent = 'Data restored from backup (' + data.recovered_from + '). Some recent changes may be lost. ';
          var dismissBtn = document.createElement('button');
          dismissBtn.textContent = 'Dismiss';
          dismissBtn.style.cssText = 'background:rgba(255,255,255,0.3);border:none;color:#fff;padding:4px 12px;border-radius:3px;cursor:pointer;margin-left:8px';
          dismissBtn.addEventListener('click', function() { fetch('/mail/dismiss-recovery',{method:'POST',credentials:'same-origin'}).then(function(){document.getElementById('recovery-banner').remove()}); });
          banner.appendChild(dismissBtn);
          document.body.prepend(banner);
        }
      }).catch(function() {});
  }
  poll();
  setInterval(poll, 30000);
})();
(function() {
  var btn = document.getElementById('theme-toggle');
  function isDark() { return document.documentElement.getAttribute('data-theme') === 'dark'; }
  function updateIcon() { btn.textContent = isDark() ? '\u2600' : '\u263d'; }
  updateIcon();
  btn.addEventListener('click', function() {
    var dark = !isDark();
    document.documentElement.setAttribute('data-theme', dark ? 'dark' : 'light');
    localStorage.setItem('theme', dark ? 'dark' : 'light');
    updateIcon();
  });
})();
(function() {
  var ship = document.getElementById('ship-name');
  if (ship) ship.addEventListener('click', function() {
    copyText(ship.dataset.copy);
    showToast('Copied: ' + ship.dataset.copy);
  });
})();
(function() {
  var params = new URLSearchParams(window.location.search);
  var msg = params.get('msg');
  if (msg) {
    var messages = {
      'verifying': 'Verifying DNS...',
      'invalid-alias': 'Invalid alias format.',
      'alias-is-ship': 'This alias matches a ship name and cannot be used.',
      'alias-updated': 'Alias updated. Reload in a few seconds to see the change.'
    };
    showToast(messages[msg] || msg);
    history.replaceState(null, '', window.location.pathname);
  }
})();
(function() {
  var tog = document.getElementById('cc-toggle');
  var fields = document.getElementById('cc-fields');
  if (!tog || !fields) return;
  var cc = document.getElementById('cc');
  if (cc && cc.value) { fields.style.display = 'block'; tog.style.display = 'none'; }
  tog.addEventListener('click', function(e) {
    e.preventDefault();
    fields.style.display = 'block';
    tog.style.display = 'none';
    if (cc) cc.focus();
  });
})();
(function() {
  var src = document.querySelector('.message-source');
  var body = document.querySelector('.message-body');
  if (!src || !body) return;
  var btn = document.createElement('button');
  btn.className = 'btn-source';
  btn.textContent = 'View source';
  btn.addEventListener('click', function() {
    var show = src.style.display === 'none';
    src.style.display = show ? 'block' : 'none';
    body.style.display = show ? 'none' : 'block';
    btn.textContent = show ? 'View rendered' : 'View source';
  });
  body.parentNode.insertBefore(btn, body);
})();
/* Autosave drafts */
// Compose: dynamic label badges
(function() {
  var container = document.getElementById('compose-labels');
  var hidden = document.getElementById('compose-labels-hidden');
  var input = document.getElementById('label-add-input');
  var addBtn = document.getElementById('label-add-btn');
  if (!container || !hidden || !input || !addBtn) return;
  // palette and hashStr are global from Section 1
  function addLabel(name) {
    name = name.trim().toLowerCase().replace(/[^a-z0-9_-]/g, '');
    if (!name) return;
    // check duplicate
    if (hidden.querySelector('input[value="' + name + '"]')) return;
    // badge
    var span = document.createElement('span');
    span.className = 'label-badge';
    span.dataset.label = name;
    span.innerHTML = '<span>' + name + '</span> <button type="button" class="remove-x label-remove">x</button>';
    if (palette) span.style.background = palette[hashStr(name) % palette.length];
    container.appendChild(span);
    // hidden input
    var inp = document.createElement('input');
    inp.type = 'hidden'; inp.name = 'labels'; inp.value = name;
    hidden.appendChild(inp);
  }
  function removeLabel(name) {
    container.querySelectorAll('.label-badge').forEach(function(el) {
      if (el.dataset.label === name) el.remove();
    });
    hidden.querySelectorAll('input[value="' + name + '"]').forEach(function(el) { el.remove(); });
  }
  // expose for draft restore
  window._composeAddLabel = addLabel;
  addBtn.addEventListener('click', function() {
    addLabel(input.value);
    input.value = '';
    input.focus();
  });
  input.addEventListener('keydown', function(e) {
    if (e.key === 'Enter') { e.preventDefault(); addLabel(input.value); input.value = ''; }
  });
  container.addEventListener('click', function(e) {
    if (e.target.classList.contains('label-remove')) {
      var badge = e.target.closest('.label-badge');
      if (badge) removeLabel(badge.dataset.label);
    }
  });
  // color existing badges
  container.querySelectorAll('.label-badge').forEach(function(el) {
    if (palette) el.style.background = palette[hashStr(el.dataset.label) % palette.length];
  });
})();
(function() {
  if (document.body.dataset.page !== 'compose') return;
  var form = document.querySelector('.compose-form form');
  if (!form) return;
  var KEY = 'mail-draft';
  var draftFields = ['to', 'cc', 'bcc', 'subject', 'body'];
  var isNew = !document.querySelector('h2') || document.querySelector('h2').textContent === 'Compose Message';
  function showDraftStatus(text) {
    var el = document.getElementById('draft-status');
    if (!el) return;
    el.textContent = text;
    el.style.opacity = '1';
    setTimeout(function() { el.style.opacity = '0'; }, 2000);
  }
  var clearBtn = document.getElementById('clear-draft');
  // helper: get current labels from hidden inputs
  function getLabels() {
    var hidden = document.getElementById('compose-labels-hidden');
    if (!hidden) return [];
    return Array.from(hidden.querySelectorAll('input[name="labels"]')).map(function(i) { return i.value; });
  }
  if (isNew) { try { var saved = JSON.parse(localStorage.getItem(KEY));
    if (saved) { var hasDraft = false;
      draftFields.forEach(function(f) { var el = document.getElementById(f);
        if (el && saved[f] && !el.value) { el.value = saved[f]; hasDraft = true; }
      });
      // restore labels if no prefilled labels
      if (saved.labels && saved.labels.length && !getLabels().length) {
        saved.labels.forEach(function(l) {
          if (window._composeAddLabel) window._composeAddLabel(l);
        });
        hasDraft = true;
      }
      if (hasDraft) { showDraftStatus('Draft restored'); if (clearBtn) clearBtn.style.display = ''; }
    }
  } catch(e) {} }
  if (clearBtn) { clearBtn.addEventListener('click', function() {
    localStorage.removeItem(KEY);
    draftFields.forEach(function(f) { var el = document.getElementById(f); if (el) el.value = ''; });
    // clear labels
    var container = document.getElementById('compose-labels');
    var hidden = document.getElementById('compose-labels-hidden');
    if (container) container.innerHTML = '';
    if (hidden) hidden.innerHTML = '';
    clearBtn.style.display = 'none'; showDraftStatus('Draft cleared');
  }); }
  var timer = null;
  function saveDraft() { var data = {}; var hasContent = false;
    draftFields.forEach(function(f) { var el = document.getElementById(f);
      if (el) { data[f] = el.value; if (el.value) hasContent = true; }
    });
    data.labels = getLabels();
    if (data.labels.length) hasContent = true;
    if (hasContent) { localStorage.setItem(KEY, JSON.stringify(data)); showDraftStatus('Draft saved'); }
  }
  draftFields.forEach(function(f) { var el = document.getElementById(f);
    if (el) { el.addEventListener('input', function() { clearTimeout(timer); timer = setTimeout(saveDraft, 500); }); }
  });
  // save draft when labels change
  var labelsContainer = document.getElementById('compose-labels');
  if (labelsContainer) {
    var obs = new MutationObserver(function() { clearTimeout(timer); timer = setTimeout(saveDraft, 500); });
    obs.observe(labelsContainer, { childList: true });
  }
  form.addEventListener('submit', function() { localStorage.removeItem(KEY); });
})();

// =============================================================================
// Section 2: Push notifications
// Original: lines 691-725
// =============================================================================

/* Push notifications */
(function() {
  var pushBtn = document.getElementById('push-toggle');
  if (!pushBtn) return;
  if (!navigator.serviceWorker) { pushBtn.textContent = 'Push not supported'; pushBtn.disabled = true; return; }
  if (!window.PushManager) { pushBtn.textContent = 'Push not supported'; pushBtn.disabled = true; return; }
  function urlB64(b64) { var p = b64.replace(/-/g,'+').replace(/_/g,'/'); var r = atob(p); var a = new Uint8Array(r.length); for(var i=0;i<r.length;i++) a[i]=r.charCodeAt(i); return a; }
  function updateBtn(enabled) { pushBtn.textContent = enabled ? 'Notifications ON' : 'Enable notifications'; pushBtn.className = enabled ? 'btn btn-secondary' : 'btn'; }
  navigator.serviceWorker.register('/mail/sw.js', {scope: '/mail/'}).then(function() {
    return navigator.serviceWorker.ready;
  }).then(function(reg) {
    reg.pushManager.getSubscription().then(function(sub) { updateBtn(!!sub); });
    pushBtn.addEventListener('click', function() {
      Notification.requestPermission().then(function(perm) {
        if (perm !== 'granted') { showToast('Notifications blocked'); return; }
        reg.pushManager.getSubscription().then(function(sub) {
          if (sub) { sub.unsubscribe().then(function() {
            fetch('/mail-push/unsubscribe', {method:'POST', credentials:'same-origin', headers:{'Content-Type':'application/json'}, body:JSON.stringify({id:localStorage.getItem('push-sub-id')||''})});
            updateBtn(false); showToast('Notifications disabled');
          }); return; }
          fetch('/mail-push/vapid-key', {credentials:'same-origin'}).then(function(r){ return r.text(); }).then(function(raw) { var key = raw.trim();
            return reg.pushManager.subscribe({userVisibleOnly:true, applicationServerKey:urlB64(key)});
          }).then(function(sub) {
            var j = sub.toJSON(); var sid = 'b-' + Date.now();
            localStorage.setItem('push-sub-id', sid);
            var p = j.keys || {};
            return fetch('/mail-push/subscribe', {method:'POST', credentials:'same-origin', headers:{'Content-Type':'application/json'}, body:JSON.stringify({id:sid, endpoint:j.endpoint, p256dh:p.p256dh||'', auth:p.auth||''})});
          }).then(function() { updateBtn(true); showToast('Notifications enabled'); }).catch(function(e) { showToast('Error: ' + e.message); });
        });
      });
    });
  }).catch(function(e) { pushBtn.textContent = 'SW error'; showToast('SW: ' + e.message); });
})();

// =============================================================================
// Section 3: Batch operations
// Original: lines 726-761
// =============================================================================

/* Batch operations */
(function() {
  var bar = document.getElementById('batch-bar');
  var cnt = document.getElementById('batch-count');
  var sa = document.getElementById('select-all');
  if (!bar) return;
  if (document.body.dataset.page === 'sent') {
    document.querySelectorAll('.batch-read, .batch-unread').forEach(function(b) { b.style.display = 'none'; });
  }
  // only count visible checkboxes (mobile cards OR desktop table, not both)
  function getVisibleChecks() {
    var mobile = document.querySelector('.mobile-cards');
    if (mobile && mobile.offsetParent !== null) {
      return mobile.querySelectorAll('.msg-check');
    }
    return document.querySelectorAll('table .msg-check');
  }
  function getVisibleChecked() {
    var mobile = document.querySelector('.mobile-cards');
    if (mobile && mobile.offsetParent !== null) {
      return mobile.querySelectorAll('.msg-check:checked');
    }
    return document.querySelectorAll('table .msg-check:checked');
  }
  function updateBar() {
    var checked = getVisibleChecked();
    if (checked.length > 0) { bar.classList.add('visible'); cnt.textContent = checked.length + ' selected'; }
    else { bar.classList.remove('visible'); }
  }
  if (sa) { sa.addEventListener('change', function() {
    getVisibleChecks().forEach(function(c) { c.checked = sa.checked; });
    updateBar();
  }); }
  // Mobile select all
  document.querySelectorAll('.select-all-mobile').forEach(function(cb) {
    cb.addEventListener('change', function() {
      getVisibleChecks().forEach(function(c) { c.checked = cb.checked; });
      updateBar();
    });
  });
  document.addEventListener('change', function(e) { if (e.target.classList.contains('msg-check')) updateBar(); });
  window.batchAction = function(action) {
    var checked = getVisibleChecked();
    if (checked.length === 0) return;
    if (action === 'batch-delete' && !confirm('Delete ' + checked.length + ' messages?')) return;
    var form = document.createElement('form');
    form.method = 'POST';
    form.action = '/mail/' + action;
    checked.forEach(function(c) {
      var inp = document.createElement('input');
      inp.type = 'hidden'; inp.name = 'ids'; inp.value = c.value;
      form.appendChild(inp);
    });
    var pg = document.body.dataset.page;
    if (pg === 'sent') { var f = document.createElement('input'); f.type='hidden'; f.name='from'; f.value='sent'; form.appendChild(f); }
    var ret = document.createElement('input');
    ret.type = 'hidden'; ret.name = 'return'; ret.value = window.location.pathname + window.location.search;
    form.appendChild(ret);
    document.body.appendChild(form);
    form.submit();
  };
})();

// =============================================================================
// Section 4: Sigil rendering (dynamic import)
// Original: lines 762-782
// =============================================================================

// Avatar cache + pending dedup
var _avatarCache = {};
var _avatarPending = {};
function fetchAvatar(patp, cb) {
  if (patp in _avatarCache) { cb(_avatarCache[patp]); return; }
  if (patp in _avatarPending) { _avatarPending[patp].push(cb); return; }
  _avatarPending[patp] = [cb];
  fetch('/mail/api/avatar?ship=' + encodeURIComponent(patp), {credentials: 'same-origin'})
    .then(function(r) { return r.json(); })
    .then(function(url) {
      _avatarCache[patp] = url || '';
      _avatarPending[patp].forEach(function(fn) { fn(url || ''); });
      delete _avatarPending[patp];
    })
    .catch(function() {
      _avatarCache[patp] = '';
      _avatarPending[patp].forEach(function(fn) { fn(''); });
      delete _avatarPending[patp];
    });
}

import('https://esm.sh/urbit-sigil-js@1.3.13?bundle').then(function(m) {
  var isDark = document.documentElement.getAttribute('data-theme') === 'dark';
  var bg = isDark ? '#252545' : '#333333';
  var fg = isDark ? '#d8d8e8' : '#ffffff';
  function sigilPatp(patp) {
    var clean = patp.replace(/^~/, '').replace(/-/g, '');
    var n = clean.length / 3;
    if (n <= 4) return patp;
    var tail = clean.slice(-12);
    return '~' + tail.slice(0,6) + '-' + tail.slice(6);
  }
  function renderSigil(el, patp) {
    try {
      var p = sigilPatp(patp);
      el.innerHTML = m.sigil({ patp: p, renderer: m.stringRenderer, size: 24, colors: [bg, fg] });
    } catch(e) {}
  }
  document.querySelectorAll('.sigil-wrap[data-patp]').forEach(function(el) {
    var patp = el.dataset.patp;
    // render sigil immediately
    renderSigil(el, patp);
    // then try avatar async
    fetchAvatar(patp, function(url) {
      if (url && /^https?:\/\//.test(url)) {
        var img = document.createElement('img');
        img.src = url;
        img.style.cssText = 'width:24px;height:24px;border-radius:50%;object-fit:cover;';
        img.alt = patp;
        img.onerror = function() { renderSigil(el, patp); };
        el.innerHTML = '';
        el.appendChild(img);
      }
    });
  });
});

// =============================================================================
// Section 5: Settings tab switching
// Original: lines 1640-1668
// =============================================================================

document.querySelectorAll('.settings-tab').forEach(function(tab) {
  tab.addEventListener('click', function() {
    document.querySelectorAll('.settings-tab').forEach(function(t) {
      t.classList.remove('active');
      t.style.borderBottomColor = 'transparent';
      t.style.color = 'var(--muted)';
      t.style.fontWeight = 'normal';
    });
    tab.classList.add('active');
    tab.style.borderBottomColor = 'var(--link)';
    tab.style.color = 'var(--text)';
    tab.style.fontWeight = '600';
    document.querySelectorAll('.settings-tab-panel').forEach(function(p) {
      p.style.display = p.dataset.tab === tab.dataset.tab ? 'block' : 'none';
    });
    window.location.hash = 's-' + tab.dataset.tab;
  });
});
(function() {
  var hash = window.location.hash.slice(1);
  if (hash.startsWith('s-')) {
    var target = hash.slice(2);
    document.querySelectorAll('.settings-tab').forEach(function(t) {
      if (t.dataset.tab === target) t.click();
    });
  }
})();

// Tab link buttons (e.g. "Browse Registry" → switch to Discovery tab)
document.querySelectorAll('.settings-tab-link').forEach(function(link) {
  link.addEventListener('click', function(e) {
    e.preventDefault();
    var target = link.dataset.tab;
    document.querySelectorAll('.settings-tab').forEach(function(t) {
      if (t.dataset.tab === target) t.click();
    });
  });
});

// =============================================================================
// Section 6: Backup restore handler
// Original: lines 1720-1733
// =============================================================================

(function() {
  var form = document.getElementById("restore-form");
  if (!form) return;
  form.addEventListener("submit", function(e) {
    e.preventDefault();
    var f = document.getElementById("backup-file").files[0];
    if (!f) { alert("Please select a backup file"); return; }
    if (!confirm("This will replace ALL current mail data. Are you sure?")) return;
    var r = new XMLHttpRequest();
    r.open("POST", "/mail/restore");
    r.setRequestHeader("Content-Type", "application/json");
    r.onload = function() {
      if (r.status !== 200) { alert("Restore failed: " + (r.responseText || "HTTP " + r.status)); return; }
      window.location.href = "/mail";
    };
    r.onerror = function() { alert("Restore failed"); };
    f.text().then(function(t) { r.send(t); });
  });
})();

// =============================================================================
// Section 7a: Pending payment TTL timers (gateway admin)
// =============================================================================

(function() {
  var timers = document.querySelectorAll('.pp-timer[data-created]');
  if (!timers.length) return;
  function update() {
    timers.forEach(function(el) {
      var m = el.dataset.created.match(/~(\d+)\.(\d+)\.(\d+)\.\.(\d+)\.(\d+)\.(\d+)/);
      if (!m) return;
      var created = new Date(Date.UTC(+m[1], m[2]-1, +m[3], +m[4], +m[5], +m[6])).getTime();
      var rem = (created + 3600000) - Date.now();
      if (rem <= 0) { el.textContent = 'expired'; return; }
      var mins = Math.floor(rem / 60000);
      var secs = Math.floor((rem % 60000) / 1000);
      el.textContent = mins + ':' + (secs < 10 ? '0' : '') + secs;
    });
  }
  update();
  setInterval(update, 1000);
})();

// =============================================================================
// Section 7b: Gateway tabs + ETH pricing
// Original: lines 2245-2300
// =============================================================================

document.querySelectorAll('.gw-tab').forEach(function(tab) {
  tab.addEventListener('click', function() {
    document.querySelectorAll('.gw-tab').forEach(function(t) {
      t.classList.remove('active');
      t.style.borderBottomColor = 'transparent';
      t.style.color = 'var(--muted)';
      t.style.fontWeight = 'normal';
    });
    tab.classList.add('active');
    tab.style.borderBottomColor = 'var(--link)';
    tab.style.color = 'var(--text)';
    tab.style.fontWeight = '600';
    document.querySelectorAll('.gw-tab-panel').forEach(function(p) {
      p.style.display = p.dataset.tab === tab.dataset.tab ? 'block' : 'none';
    });
    window.location.hash = tab.dataset.tab;
  });
});
(function() {
  var hash = window.location.hash.slice(1);
  var target = hash || (window.location.search.includes('invite=') ? 'aliases' : '');
  if (target) {
    document.querySelectorAll('.gw-tab').forEach(function(t) {
      if (t.dataset.tab === target) t.click();
    });
  }
})();
(function() {
  var ethInp = document.getElementById('pay-price-eth-input');
  var weiInp = document.getElementById('pay-price-wei');
  if (!ethInp || !weiInp) return;
  function ethToWeiTruncated(ethStr) {
    var parts = ethStr.split('.');
    var intPart = parseInt(parts[0]) || 0;
    var fracStr = (parts[1] || '').substring(0, 4).padEnd(4, '0');
    var frac = parseInt(fracStr) || 0;
    return (intPart * 1e18) + (frac * 1e14);
  }
  function updatePrices() {
    var wei = ethToWeiTruncated(ethInp.value);
    weiInp.value = Math.round(wei).toString();
    var rows = document.querySelectorAll('#price-table-body tr');
    rows.forEach(function(row) {
      if (row.dataset.free === '1') return;
      var exp = parseInt(row.dataset.exp) || 0;
      var mult = Math.pow(2, exp);
      var price = wei * mult;
      var priceEth = price / 1e18;
      var cell = row.querySelector('.price-cell');
      if (cell) cell.textContent = priceEth.toFixed(4) + ' ETH';
    });
  }
  ethInp.addEventListener('input', updatePrices);
  ethInp.addEventListener('change', updatePrices);
  ethInp.addEventListener('keyup', updatePrices);
  updatePrices();
})();

// =============================================================================
// Section 8: Unified alias form — dynamic price + action switching
// =============================================================================

(function() {
  var form = document.getElementById('alias-form');
  if (!form) return;
  var input = form.querySelector('input[name="alias"]');
  var hint = document.getElementById('alias-price');
  var btn = document.getElementById('alias-submit');
  var sel = document.getElementById('alias-gateway');
  var rulesEl = document.getElementById('alias-rules');
  if (!input || !hint || !btn) return;
  // read config from selected gateway option
  var fml, ml, bp, payOn;
  function loadConfig() {
    var opt = sel && sel.selectedOptions[0];
    fml = (opt && parseInt(opt.dataset.freeMin)) || parseInt(form.dataset.freeMinLen) || 10;
    ml = (opt && parseInt(opt.dataset.min)) || parseInt(form.dataset.minLen) || 5;
    bp = (opt && parseInt(opt.dataset.base)) || parseInt(form.dataset.basePrice) || 5000000000000000;
    payOn = opt ? opt.dataset.pay === '1' : false;
    if (rulesEl) {
      rulesEl.textContent = payOn
        ? fml + '+ chars = free. ' + ml + ' to ' + (fml - 1) + ' chars = paid (ETH).'
        : fml + '+ chars only. Paid aliases not available on this gateway.';
    }
  }
  loadConfig();
  if (sel) sel.addEventListener('change', function() { loadConfig(); update(); });
  // sanitize input: lowercase, only a-z 0-9 - _
  input.addEventListener('input', function() {
    var pos = input.selectionStart;
    var clean = input.value.toLowerCase().replace(/[^a-z0-9_-]/g, '');
    if (clean !== input.value) {
      input.value = clean;
      input.selectionStart = input.selectionEnd = Math.min(pos, clean.length);
    }
  });
  function update() {
    var len = input.value.length;
    if (len === 0) {
      hint.textContent = '';
      btn.textContent = 'Request';
      form.action = '/mail/request-alias';
      btn.disabled = true;
      return;
    }
    btn.disabled = false;
    if (len < ml) {
      hint.textContent = 'Too short';
      hint.style.color = 'var(--color-error)';
      btn.textContent = 'Request';
      btn.disabled = true;
      return;
    }
    if (len >= fml) {
      hint.textContent = 'Free';
      hint.style.color = 'var(--color-success)';
      btn.textContent = 'Request Free Alias';
      form.action = '/mail/request-alias';
      return;
    }
    if (!payOn) {
      hint.textContent = 'Too short (min ' + fml + ' chars on this gateway)';
      hint.style.color = 'var(--color-error)';
      btn.disabled = true;
      return;
    }
    var priceEth = (bp * Math.pow(2, fml - len - 1)) / 1e18;
    hint.textContent = '~' + priceEth.toFixed(4) + ' ETH';
    hint.style.color = 'var(--color-warning)';
    btn.textContent = 'Buy Alias';
    form.action = '/mail/request-paid-alias';
  }
  input.addEventListener('input', update);
  update();
})();

// =============================================================================
// Section 9: Payment waiting state — poll until gateway responds
// =============================================================================

(function() {
  var waiting = document.getElementById('payment-waiting');
  if (!waiting) return;
  var started = Date.now();
  var interval = setInterval(function() {
    // timeout after 15 seconds
    if (Date.now() - started > 15000) {
      clearInterval(interval);
      waiting.innerHTML = '<div class="compose-form" style="text-align:center">' +
        '<h2>Request failed</h2>' +
        '<p style="color:var(--muted);margin:12px 0">Gateway did not respond. The alias may be taken or the gateway may be unavailable.</p>' +
        '<a href="/mail/settings#s-aliases" class="btn" style="padding:8px 20px">Back to Settings</a></div>';
      return;
    }
    fetch('/mail/api/payment-status', {credentials: 'same-origin'})
      .then(function(r) { return r.json(); })
      .then(function(data) {
        if (data.status === 'waiting') {
          window.location.href = '/mail/buy-alias';
        }
      }).catch(function() {});
  }, 2000);
})();

// =============================================================================
// Section 10: Payment page (QR, timer, polling) — /mail/buy-alias
// =============================================================================

(function() {
  var page = document.getElementById('payment-page');
  if (!page) return;

  var wallet = page.dataset.wallet;
  var amountWei = page.dataset.amountWei;
  var createdDa = page.dataset.created;

  // QR code via Google Charts (EIP-681 URI)
  var uri = 'ethereum:' + wallet + '?value=' + amountWei;
  var qrImg = document.getElementById('qr-img');
  if (qrImg) {
    qrImg.src = 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=' + encodeURIComponent(uri);
  }

  // Parse @da timestamp to milliseconds
  var m = createdDa.match(/~(\d+)\.(\d+)\.(\d+)\.\.(\d+)\.(\d+)\.(\d+)/);
  var created = m ? new Date(Date.UTC(+m[1], m[2]-1, +m[3], +m[4], +m[5], +m[6])).getTime() : Date.now();
  var expiry = created + 3600000; // 1 hour

  // Countdown timer
  var timerEl = document.getElementById('payment-timer');
  var timerInterval = setInterval(function() {
    var rem = expiry - Date.now();
    if (rem <= 0) {
      if (timerEl) timerEl.textContent = 'Payment expired. Request a new one.';
      clearInterval(timerInterval);
      return;
    }
    var mins = Math.floor(rem / 60000);
    var secs = Math.floor((rem % 60000) / 1000);
    if (timerEl) timerEl.textContent = 'Expires in: ' + mins + ':' + (secs < 10 ? '0' : '') + secs;
  }, 1000);

  // Poll payment status (check if gateway confirmed)
  var statusEl = document.getElementById('payment-status');
  var pollInterval = setInterval(function() {
    fetch('/mail/api/payment-status', {credentials: 'same-origin'})
      .then(function(r) { return r.json(); })
      .then(function(data) {
        if (data.status === 'none') {
          clearInterval(pollInterval);
          clearInterval(timerInterval);
          page.innerHTML = '<div style="text-align:center;padding:40px 0">' +
            '<div style="font-size:48px;margin-bottom:16px;color:var(--color-success)">&#10003;</div>' +
            '<h2 style="margin-bottom:8px">Payment confirmed!</h2>' +
            '<p style="font-size:16px;color:var(--muted);margin-bottom:24px">Your new alias is now available in Settings &gt; Aliases.</p>' +
            '<a href="/mail/settings#s-aliases" class="btn" style="padding:10px 28px;font-size:15px">Go to Settings</a>' +
            '</div>';
        }
      }).catch(function() {});
  }, 5000);

})();

// =============================================================================
// Section 10: Compose form validation + Send button reset on back
// =============================================================================

(function() {
  var btn = document.getElementById('send-btn');
  if (!btn) return;
  var form = btn.form;
  if (!form) return;
  var errEl = document.getElementById('send-error');

  // Reset button on pageshow (back/forward navigation)
  window.addEventListener('pageshow', function() {
    btn.disabled = false;
    btn.textContent = 'Send';
  });

  form.addEventListener('submit', function(e) {
    var to = form.querySelector('[name="to"]');
    var subject = form.querySelector('[name="subject"]');
    var errors = [];

    if (!to || !to.value.trim()) {
      errors.push('Recipient (To) is required');
    } else {
      var v = to.value.trim();
      var isShip = /^~[a-z][-a-z]*$/.test(v);
      var isEmail = /^[^@ ]+@[^@ ]+\.[^@ ]+$/.test(v);
      if (!isShip && !isEmail) {
        errors.push('Enter a valid ~ship or email address');
      }
    }
    if (!subject || !subject.value.trim()) {
      errors.push('Subject is required');
    }

    if (errors.length > 0) {
      e.preventDefault();
      if (errEl) {
        errEl.textContent = errors.join('. ');
        errEl.style.display = 'block';
      }
      return;
    }

    // Valid — disable button, clear draft, submit
    if (errEl) errEl.style.display = 'none';
    btn.disabled = true;
    btn.textContent = 'Sending...';
    localStorage.removeItem('mail-draft');
  });
})();
