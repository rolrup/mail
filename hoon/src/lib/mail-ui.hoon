/-  *mail-client
/-  *mail-gateway
|%
++  build-version  "501"
++  full-version   "v0.5.0-501"
::  wei-to-eth-display: convert wei to ETH string with 9 decimals
::  format: 0.xxxxyyyyy (4 price digits + 5 random digits)
::
++  wei-to-eth-display
  |=  w=@ud
  ^-  tape
  =/  eth-part=@ud  (div w 1.000.000.000.000.000.000)
  =/  rem=@ud  (mod w 1.000.000.000.000.000.000)
  ::  9 decimal places: rem / 10^9
  =/  nano=@ud  (div rem 1.000.000.000)
  =/  int-str=tape  (a-co:co eth-part)
  =/  frac-str=tape  (a-co:co nano)
  =/  pad=@ud  (sub 9 (min 9 (lent frac-str)))
  =/  padded=tape  (weld (reap pad '0') frac-str)
  (weld int-str (weld "." padded))
::  wei-to-eth-price: convert wei to ETH string with 4 decimals
::  for base price display (truncated to 0.0001 precision)
::
++  wei-to-eth-price
  |=  w=@ud
  ^-  tape
  =/  eth-part=@ud  (div w 1.000.000.000.000.000.000)
  =/  rem=@ud  (mod w 1.000.000.000.000.000.000)
  =/  deci4=@ud  (div rem 100.000.000.000.000)
  =/  int-str=tape  (a-co:co eth-part)
  =/  frac-str=tape  (a-co:co deci4)
  =/  pad=@ud  (sub 4 (min 4 (lent frac-str)))
  =/  padded=tape  (weld (reap pad '0') frac-str)
  (weld int-str (weld "." padded))
::  format-contact: render contact as tape
::
++  format-contact
  |=  c=contact
  ^-  tape
  ?-  -.c
    %urbit  (scow %p p.c)
    %ext    (trip p.c)
  ==
::  join-contacts: render list of contacts as comma-separated tape
::
++  join-contacts
  |=  cs=(list contact)
  ^-  tape
  ?~  cs  ""
  =/  first=tape  (format-contact i.cs)
  |-
  ?~  t.cs  first
  $(first (weld first (weld ", " (format-contact i.t.cs))), t.cs t.t.cs)
::  format-contact-short: truncated contact for table columns
::  emails: "longuser...@domain.com", @p: "~sampel...rolrup"
::
++  format-contact-short
  |=  [c=contact max=@ud]
  ^-  tape
  =/  full=tape  (format-contact c)
  ?:  (lte (lent full) max)  full
  ?-  -.c
      %ext
    =/  txt=tape  (trip p.c)
    =/  at=(unit @ud)
      =/  i=@ud  0
      |-
      ?:  (gte i (lent txt))  ~
      ?:  =('@' (snag i txt))  `i
      $(i +(i))
    ?~  at  (weld (scag (sub max 3) full) "...")
    =/  domain=tape  (slag u.at txt)
    =/  dom-len=@ud  (lent domain)
    =/  avail=@ud  ?:((gth max (add dom-len 4)) (sub max (add dom-len 3)) 2)
    :(weld (scag avail (scag u.at txt)) "..." domain)
      %urbit
    =/  pre=tape   (scag 7 full)
    =/  suf=tape   (slag (sub (lent full) 7) full)
    :(weld pre "..." suf)
  ==
::  format-date: render @da as short date tape
::
++  format-date
  |=  d=@da
  ^-  tape
  (scag 18 (scow %da d))
::  format-labels: render labels as tape
::
++  format-labels
  |=  lab=(set @tas)
  ^-  tape
  ?:  =(~ lab)  ""
  =/  items=(list @tas)  ~(tap in lab)
  =/  out=tape  ""
  |-
  ?~  items  out
  =/  next=tape  (trip i.items)
  ?:  =(~ out)
    $(items t.items, out next)
  $(items t.items, out (weld out (weld ", " next)))
::  get-avatar: scry %contacts for ship avatar URL, ~ if not found
::
++  get-avatar
  |=  [ship=@p now=@da]
  ^-  (unit @t)
  =/  contact-json=(unit json)
    %-  mole  |.
    .^(json %gx /=contacts/(scot %da now)/contact/(scot %p ship)/json)
  ?~  contact-json  ~
  ?.  ?=([%o *] u.contact-json)  ~
  =/  av  (~(get by p.u.contact-json) 'avatar')
  ?~  av  ~
  ?.  ?=([%s *] u.av)  ~
  ?:  =('' p.u.av)  ~
  `p.u.av
::  render-label-badges: render labels as styled badges
::
++  render-label-badges
  |=  lab=(set @tas)
  ^-  (list manx)
  ?:  =(~ lab)  ~
  =/  visible=(list @tas)
    %+  skim  ~(tap in lab)
    |=  l=@tas
    !=("sendas:" (scag 7 (trip l)))
  %+  turn  visible
  |=  l=@tas
  ;span(class "label-badge"): {(trip l)}
::  render-body: simple text wrapper, markdown handled by JS
::
++  render-body
  |=  body=tape
  ^-  manx
  ;div: {body}
::  url-enc: simple percent-encode for query params
::
++  url-enc
  |=  t=tape
  ^-  tape
  ?~  t  ~
  ?:  =('@' i.t)  (weld "%40" $(t t.t))
  ?:  =(' ' i.t)  (weld "%20" $(t t.t))
  ?:  =('+' i.t)  (weld "%2B" $(t t.t))
  ?:  =('&' i.t)  (weld "%26" $(t t.t))
  ?:  =('=' i.t)  (weld "%3D" $(t t.t))
  ?:  =('#' i.t)  (weld "%23" $(t t.t))
  [i.t $(t t.t)]
::  render-nav: navigation bar
::
++  render-nav
  |=  [page=@tas unread=@ud our=@p is-gw=? pending-gw=@ud]
  ^-  manx
  ;nav
    ;div(class "nav-inner")
      ;a(href "/mail", class "nav-logo"): ~mail
      ;div(class "nav-links")
        ;a(href "/mail", class ?:(=(%inbox page) "active" ""))
          ;span: Inbox
          ;*  ?.  (gth unread 0)  ~
              :~  ;span(class "badge"): {(a-co:co unread)}
              ==
        ==
        ;a(href "/mail/sent", class ?:(=(%sent page) "active" "")): Sent
        ;a(href "/mail/compose", class ?:(=(%compose page) "active" "")): Compose
        ;a(href "/mail/settings", class ?:(=(%settings page) "active" "")): Settings
        ;*  ?.  is-gw  ~
            :~  ;a(href "/mail/gateway", class ?:(=(%gateway page) "active" ""))
                  ;span: Gateway
                  ;*  ?.  (gth pending-gw 0)  ~
                      :~  ;span(class "badge"): {(a-co:co pending-gw)}
                      ==
                ==
            ==
        ;a(href "/mail/help", class ?:(=(%help page) "active" "")): Help
      ==
      ;div(class "nav-right")
        ;span(class "ship-name", id "ship-name", data-copy (scow %p our)): {(scow %p our)}
        ;button(class "theme-toggle", id "theme-toggle", title "Toggle theme");
      ==
    ==
  ==
::  page-layout: full HTML page wrapper
::
++  page-layout
  |=  [title=@t page=@tas unread=@ud our=@p is-gw=? pending-gw=@ud body=manx]
  ^-  manx
  ;html
    ;head
      ;meta(charset "UTF-8");
      ;meta(name "viewport", content "width=device-width, initial-scale=1");
      ;link(rel "manifest", href "/mail/manifest.json");
      ;meta(name "mobile-web-app-capable", content "yes");
      ;meta(name "apple-mobile-web-app-status-bar-style", content "black-translucent");
      ;meta(name "apple-mobile-web-app-title", content "Urbit Mail");
      ;meta(name "theme-color", content "#1a1d23");
      ;link(rel "apple-touch-icon", href "/mail/apple-icon");
      ;link(rel "icon", type "image/png", sizes "32x32", href "/mail/favicon-32.png");
      ;link(rel "icon", type "image/png", sizes "192x192", href "/mail/icon-192.png");
      ;link(rel "modulepreload", href "https://esm.sh/urbit-sigil-js@1.3.13?bundle", integrity "sha384-ispNd1bBmgcLfIYCXGPFfy7skrNZeTmuEPO2gPa+kenZNwuO4ubjllZ3E8f7wWRg", crossorigin "anonymous");
      ;title: {?:(=(0 unread) "" "({(a-co:co unread)}) ")}{(trip title)} · {(scow %p our)} · ~mail
      ;script
        ; (function() {
        ;   var t = localStorage.getItem('theme');
        ;   if (t === 'dark' || (!t && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
        ;     document.documentElement.setAttribute('data-theme', 'dark');
        ;   }
        ; })();
      ==
      ;style
        ; :root { --bg: #f5f5f5; --text: #333; --card: #fff; --nav-bg: #333; --border: #eee; --th-bg: #eaeaea; --th-text: #555; --hover: #f0f7ff; --unread-bg: #dce8f5; --link: #2980b9; --link-hover: #1a6fa0; --muted: #999; --label-clr: #666; --input-bg: #fff; --input-border: #ddd; --copy-bg: #e0e0e0; --copy-text: #555; --toast-bg: #333; --toast-text: #fff; --info-bg: #e8f4fd; --img-link-bg: #f0f4f8; --img-link-border: #d0d8e0; --img-toggle-bg: #e0e0e0; --del-hover-bg: #ffeaea; --sidebar-link: #333; --badge-text: #fff; --nav-link: #ccc; --nav-active: #fff; --unread-dot: #333; --btn-danger: #e74c3c; --btn-danger-hover: #c0392b; --btn-secondary: #95a5a6; --btn-secondary-hover: #7f8c8d; --color-error: #e74c3c; --color-success: #27ae60; --color-warning: #f39c12; --color-success-hover: #219a52; --color-error-hover: #c0392b; }
        ; [data-theme="dark"] { --bg: #0f0f1a; --text: #d8d8e8; --card: #1a1a2e; --nav-bg: #0a0a1a; --border: #2a2a4a; --th-bg: #252545; --th-text: #9898bb; --hover: #1a2a4a; --unread-bg: #1a2550; --link: #4a90b8; --link-hover: #6aaccf; --muted: #6a6a8a; --label-clr: #8888aa; --input-bg: #16213e; --input-border: #2a2a4a; --copy-bg: #2a2a4a; --copy-text: #aaa; --toast-bg: #2a2a4a; --toast-text: #e0e0e0; --info-bg: #16213e; --img-link-bg: #16213e; --img-link-border: #2a2a4a; --img-toggle-bg: #2a2a4a; --del-hover-bg: #3a1a1a; --sidebar-link: #d8d8e8; --badge-text: #fff; --nav-link: #8888aa; --nav-active: #e0e0e0; --unread-dot: #e0e0e0; --btn-danger: #b83a2e; --btn-danger-hover: #983028; --btn-secondary: #5a6a7a; --btn-secondary-hover: #4a5a6a; --color-error: #c0392b; --color-success: #219a52; --color-warning: #d4860e; --color-success-hover: #1a7a42; --color-error-hover: #a02a20; }
        ; * { margin: 0; padding: 0; box-sizing: border-box; }
        ; body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: var(--bg); color: var(--text); }
        ; .container { max-width: 1250px; margin: 0 auto; padding: 20px; }
        ; nav { background: var(--nav-bg); padding: 0; }
        ; .nav-inner { max-width: 1250px; margin: 0 auto; padding: 10px 20px; display: flex; align-items: center; }
        ; .nav-logo { color: #00e5ff !important; font-size: 22px; font-weight: 700; text-decoration: none !important; margin-right: 0; text-shadow: 0 0 10px rgba(0,229,255,0.5), 0 0 20px rgba(0,229,255,0.25); border-bottom: none !important; width: 180px; flex-shrink: 0; }
        ; .nav-logo:hover { border-bottom: none !important; text-shadow: 0 0 14px rgba(0,229,255,0.7), 0 0 28px rgba(0,229,255,0.4); }
        ; .nav-links { display: flex; align-items: center; }
        ; .nav-right { margin-left: auto; display: flex; align-items: center; gap: 10px; }
        ; .ship-name { color: var(--nav-active); font-size: 15px; font-weight: 600; letter-spacing: 0.3px; cursor: pointer; }
        ; .ship-name:hover { opacity: 0.8; }
        ; .theme-toggle { background: none; border: 1px solid var(--nav-link); color: var(--nav-link); cursor: pointer; font-size: 16px; padding: 3px 8px; border-radius: 4px; line-height: 1; }
        ; .theme-toggle:hover { color: var(--nav-active); border-color: var(--nav-active); }
        ; nav a { color: var(--nav-link); text-decoration: none; margin-right: 20px; padding: 8px 0; display: inline-block; }
        ; nav a:hover { color: var(--nav-active); border-bottom: 3px solid var(--nav-active); }
        ; nav a.active { color: var(--nav-active); font-weight: bold; border-bottom: 3px solid var(--color-error); }
        ; nav a.active:hover { border-bottom: 3px solid var(--color-error); }
        ; .badge { background: var(--color-error); color: #fff; padding: 1px 7px; border-radius: 10px; font-size: 12px; margin-left: 4px; }
        ; table { width: 100%; border-collapse: collapse; background: var(--card); border-radius: 12px; overflow: hidden; }
        ; th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid var(--border); }
        ; th { background: var(--th-bg); font-weight: 600; font-size: 13px; color: var(--th-text); }
        ; tr.unread { background: var(--unread-bg); }
        ; tr:not(.unread):hover { background: var(--hover); }
        ; tr.unread:hover { background: var(--hover); }
        ; tr.unread td { font-weight: 700; color: var(--text); }
        ; tr:not(.unread) td { color: var(--muted); }
        ; a { color: var(--link); text-decoration: none; }
        ; a:hover { text-decoration: none; }
        ; .container a:hover { text-decoration: underline; }
        ; .btn { display: inline-block; padding: 8px 16px; background: var(--link); color: #fff; border: none; cursor: pointer; text-decoration: none; margin-right: 8px; border-radius: 6px; font-size: 14px; }
        ; .btn:hover { background: var(--link-hover); }
        ; .btn-danger { background: var(--btn-danger); }
        ; .btn-danger:hover { background: var(--btn-danger-hover); }
        ; .btn-secondary { background: var(--btn-secondary); }
        ; .btn-secondary:hover { background: var(--btn-secondary-hover); }
        ; .message-view { background: var(--card); padding: 20px; border-radius: 12px; }
        ; .message-header { border-bottom: 1px solid var(--border); padding-bottom: 15px; margin-bottom: 15px; }
        ; .message-header p { margin: 5px 0; }
        ; .message-header .label { display: inline-block; width: 70px; color: var(--label-clr); }
        ; .message-body { line-height: 1.6; padding: 10px 0; }
        ; .message-actions { padding: 15px 0; display: flex; flex-wrap: wrap; gap: 6px; align-items: center; }
        ; .message-actions.top { border-top: none; border-bottom: 1px solid var(--border); margin-bottom: 15px; padding-top: 0; }
        ; .message-actions.bottom { border-top: 1px solid var(--border); margin-top: 20px; }
        ; .message-actions a.btn:hover { text-decoration: none; }
        ; .compose-form { background: var(--card); padding: 20px; border-radius: 12px; }
        ; .compose-form label { display: block; margin-bottom: 4px; font-weight: 600; color: var(--th-text); }
        ; .compose-form input, .compose-form textarea { width: 100%; padding: 8px 10px; margin-bottom: 16px; border: 1px solid var(--input-border); border-radius: 3px; font-size: 14px; font-family: inherit; background: var(--input-bg); color: var(--text); }
        ; select { background: var(--input-bg); color: var(--text); border: 1px solid var(--input-border); border-radius: 3px; }
        ; .compose-form textarea { height: 200px; resize: vertical; }
        ; .compose-form .help { font-size: 12px; color: var(--muted); margin-top: -12px; margin-bottom: 16px; }
        ; .empty { text-align: center; padding: 40px; color: var(--muted); }
        ; h2 { margin-bottom: 15px; }
        ; .labels-cell { display: flex; flex-wrap: wrap; gap: 3px; }
        ; .label-badge { display: inline-flex; align-items: center; gap: 4px; background: #3498db; color: #fff; padding: 4px 12px; border-radius: 12px; font-size: 13px; white-space: nowrap; }
        ; .label-badge .remove-x { background: rgba(255,255,255,0.3); border: none; color: #fff; cursor: pointer; font-size: 12px; line-height: 1; padding: 0 4px; border-radius: 50%; margin-left: 2px; }
        ; .label-badge .remove-x:hover { background: rgba(255,255,255,0.5); }
        ; .inbox-layout { display: flex; gap: 15px; align-items: flex-start; }
        ; .inbox-main { flex: 1; min-width: 0; overflow-x: auto; }
        ; .label-sidebar { background: var(--card); padding: 15px; border-radius: 12px; width: 160px; flex-shrink: 0; position: sticky; top: 20px; }
        ; @media (max-width: 768px) { .inbox-layout { flex-direction: column; } .label-sidebar { width: 100%; position: static; } }
        ; .label-details summary { font-weight: 700; cursor: pointer; list-style: none; display: flex; align-items: center; justify-content: space-between; }
        ; .label-details summary::-webkit-details-marker { display: none; }
        ; .label-details summary::after { content: '\25B2'; font-size: 10px; opacity: 0.5; transition: transform 0.2s; }
        ; .label-details:not([open]) summary::after { content: '\25BC'; }
        ; .label-sidebar a { display: block; padding: 5px 0; color: var(--sidebar-link); }
        ; .label-sidebar a:hover { color: var(--link); }
        ; .label-sidebar a.active-label { font-weight: bold; color: var(--link); }
        ; .label-sidebar .label-count { color: var(--muted); font-size: 12px; margin-left: 4px; }
        ; .label-dot { display: inline-block; width: 8px; height: 8px; border-radius: 50%; margin-right: 6px; vertical-align: middle; }
        ; .label-section { margin-top: 15px; padding-top: 10px; border-top: 1px solid var(--border); }
        ; .label-form { display: inline-flex; gap: 4px; align-items: center; }
        ; .label-form input { padding: 4px 8px; border: 1px solid var(--input-border); border-radius: 3px; font-size: 12px; width: 120px; margin: 0; background: var(--input-bg); color: var(--text); }
        ; .label-form button { padding: 4px 10px; font-size: 12px; border-radius: 3px; border: none; cursor: pointer; background: var(--link); color: #fff; }
        ; .remove-label { color: var(--color-error); text-decoration: none; font-size: 10px; margin-left: 2px; cursor: pointer; border: none; background: none; padding: 0; }
        ; .copy-btn { background: var(--copy-bg); border: none; color: var(--copy-text); cursor: pointer; font-size: 11px; padding: 2px 8px; border-radius: 3px; margin-left: 6px; vertical-align: middle; }
        ; .copy-btn:hover { opacity: 0.8; }
        ; .toast { position: fixed; top: 60px; left: 50%; transform: translateX(-50%); background: var(--toast-bg); color: var(--toast-text); padding: 10px 24px; border-radius: 6px; font-size: 14px; z-index: 9999; opacity: 0; transition: opacity 0.3s; pointer-events: none; }
        ; .toast.show { opacity: 1; }
        ; @keyframes spin { to { transform: rotate(360deg); } }
        ; .msg-summary { cursor: pointer; font-size: 13px; color: var(--muted); padding: 4px 0; }
        ; @media (min-width: 601px) { .msg-summary { display: none; } .msg-details { display: contents; } }
        ; .message-body a { color: var(--link); text-decoration: underline; }
        ; .message-body ul, .message-body ol { padding-left: 24px; margin: 4px 0; }
        ; .message-body li { margin: 2px 0; }
        ; .img-wrap { display: block; margin: 8px 0; }
        ; .img-wrap img { max-width: 320px; max-height: 320px; border-radius: 4px; cursor: pointer; display: block; }
        ; .img-placeholder { color: var(--muted); font-size: 13px; font-style: italic; }
        ; .img-link { display: inline-block; background: var(--img-link-bg); border: 1px solid var(--img-link-border); border-radius: 4px; padding: 4px 10px; margin: 2px 0; color: var(--link); text-decoration: none; font-size: 13px; }
        ; .img-link:hover { opacity: 0.8; text-decoration: underline; }
        ; .img-toggle { background: var(--img-toggle-bg); border: none; color: var(--copy-text); cursor: pointer; font-size: 12px; padding: 3px 10px; border-radius: 3px; margin-bottom: 8px; }
        ; .img-toggle:hover { opacity: 0.8; }
        ; .img-overlay { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.85); z-index: 10000; justify-content: center; align-items: center; cursor: pointer; }
        ; .img-overlay.show { display: flex; }
        ; .img-overlay img { max-width: 90%; max-height: 90%; border-radius: 6px; }
        ; tr[data-href] { cursor: pointer; }
        ; .via { font-size: 11px; color: var(--muted); margin-left: 6px; }
        ; .pagination { display: flex; justify-content: center; align-items: center; gap: 4px; padding: 15px 0; }
        ; .page-num { display: inline-block; padding: 5px 11px; border-radius: 6px; color: var(--link); text-decoration: none; font-size: 14px; }
        ; .page-num:hover { background: var(--info-bg); text-decoration: none; }
        ; .page-num.current { font-weight: bold; background: var(--link); color: #fff; pointer-events: none; }
        ; .page-dots { color: var(--muted); padding: 0 4px; font-size: 14px; }
        ; .page-nav { color: var(--link); text-decoration: none; padding: 5px 8px; font-size: 14px; }
        ; .page-nav:hover { text-decoration: underline; }
        ; .mobile-select-all { display: none; }
        ; .mobile-cards { display: none; }
        ; .mobile-cards { overflow: hidden; border-radius: 12px; background: var(--card); width: 100%; box-sizing: border-box; }
        ; .mobile-card { display: flex; align-items: center; gap: 6px; padding: 8px 10px; border-bottom: 1px solid var(--border); background: var(--card); cursor: pointer; text-decoration: none; color: var(--text); overflow: hidden; width: 100%; box-sizing: border-box; }
        ; .mobile-card:hover { background: var(--info-bg); }
        ; .mobile-card.unread { background: rgba(74,144,226,0.08); }
        ; .mobile-card.unread .mc-from { font-weight: 700; }
        ; .mobile-card.unread .mc-subject { font-weight: 600; }
        ; .mc-body { flex: 1; min-width: 0; overflow: hidden; }
        ; .mc-from { font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        ; .mc-subject { font-size: 13px; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; display: block; max-width: calc(100vw - 140px); }
        ; .mc-labels { display: flex; gap: 4px; flex-wrap: wrap; margin-top: 2px; }
        ; .mc-labels .label-badge { font-size: 10px; padding: 1px 6px; }
        ; .mc-check { width: 18px; height: 18px; flex-shrink: 0; accent-color: var(--link); cursor: pointer; }
        ; .mc-date { font-size: 10px; color: var(--muted); flex-shrink: 0; text-align: right; white-space: normal; max-width: 70px; }
        ; .mc-status { font-size: 11px; }
        ; .col-narrow { width: 28px; padding: 10px 4px !important; text-align: center; }
        ; .col-status { width: 80px; }
        ; .col-to { width: 180px; }
        ; .col-date { width: 130px; }
        ; .sigil-wrap { display: inline-block; width: 24px; height: 24px; border-radius: 4px; overflow: hidden; background: var(--th-bg); vertical-align: middle; }
        ; .sigil-wrap svg { display: block; width: 24px; height: 24px; }
        ; .sigil-wrap img { display: block; width: 100%; height: 100%; object-fit: cover; border-radius: 50%; }
        ; .sigil-inline { display: inline-block; vertical-align: middle; margin-right: 4px; width: 20px; height: 20px; }
        ; .sigil-inline svg { width: 20px; height: 20px; }
        ; .sigil-inline img { width: 100%; height: 100%; object-fit: cover; border-radius: 50%; }
        ; .ext-icon { display: inline-flex; align-items: center; justify-content: center; width: 24px; height: 24px; border-radius: 4px; background: var(--th-bg); vertical-align: middle; font-size: 18px; font-weight: bold; color: var(--color-success); line-height: 1; }
        ; .ext-icon-sm { display: inline-flex; align-items: center; justify-content: center; width: 24px; height: 24px; border-radius: 4px; background: var(--th-bg); vertical-align: middle; font-size: 24px; font-weight: bold; color: var(--color-success); margin-right: 4px; line-height: 1; }
        ; .header-line { display: flex; align-items: center; flex-wrap: wrap; gap: 2px; }
        ; .cc-item { display: inline-flex; align-items: center; gap: 2px; }
        ; .cc-item + .cc-item::before { content: ','; margin-right: 4px; }
        ; .md-heading { margin: 12px 0 4px; color: var(--text); font-weight: 600; }
        ; h2.md-heading { font-size: 20px; } h3.md-heading { font-size: 17px; } h4.md-heading { font-size: 15px; } h5.md-heading { font-size: 14px; }
        ; .md-quote { border-left: 3px solid var(--link); margin: 8px 0; padding: 6px 14px; color: var(--th-text); background: var(--info-bg); border-radius: 0 6px 6px 0; }
        ; .message-source { white-space: pre-wrap; font-family: monospace; font-size: 12px; background: var(--th-bg); color: var(--th-text); padding: 12px; border-radius: 6px; margin-top: 8px; border: 1px solid var(--border); max-height: 500px; overflow: auto; }
        ; .compose-select { width: 100%; padding: 8px 10px; margin-bottom: 16px; border: 1px solid var(--input-border); border-radius: 3px; font-size: 14px; font-family: inherit; background: var(--input-bg); color: var(--text); }
        ; .cc-toggle { font-size: 13px; color: var(--link); margin-bottom: 8px; display: inline-block; }
        ; .cc-fields { display: none; }
        ; .btn-source { font-size: 11px; padding: 4px 10px; background: var(--copy-bg); color: var(--copy-text); border: none; cursor: pointer; border-radius: 4px; margin-left: 8px; }
        ; .btn-source:hover { opacity: 0.8; }
        ; .col-check { width: 30px; padding: 8px 4px 8px 10px !important; }
        ; .col-check input { width: 16px; height: 16px; cursor: pointer; accent-color: var(--link); }
        ; #batch-bar { display: none; position: fixed; bottom: 0; left: 0; right: 0; background: var(--nav-bg); padding: 10px 20px; z-index: 100; justify-content: center; align-items: center; gap: 12px; box-shadow: 0 -2px 8px rgba(0,0,0,0.2); }
        ; #batch-bar.visible { display: flex; }
        ; #batch-bar span { color: var(--nav-active); font-size: 14px; font-weight: 600; }
        ; #batch-bar button { padding: 6px 14px; border: none; border-radius: 6px; cursor: pointer; font-size: 13px; color: #fff; }
        ; #batch-bar .batch-read { background: var(--link); }
        ; #batch-bar .batch-unread { background: var(--btn-secondary); }
        ; #batch-bar .batch-delete { background: var(--btn-danger); }
        ; #batch-bar button:hover { opacity: 0.85; }
        ; .row-delete { opacity: 0; transition: opacity 0.15s; }
        ; tr:hover .row-delete { opacity: 1; }
        ; .row-delete button { background: none; border: none; color: var(--muted); cursor: pointer; font-size: 16px; padding: 2px 6px; border-radius: 4px; line-height: 1; }
        ; .row-delete button:hover { color: var(--color-error); background: var(--del-hover-bg); }
        ; @media (hover: none) { .row-delete { opacity: 0.4; } }
        ; .sortable { cursor: pointer; user-select: none; }
        ; .sortable:hover { color: var(--link); }
        ; .sortable::after { content: ' \2195'; font-size: 11px; opacity: 0.5; }
        ; .sortable.asc::after { content: ' \2191'; opacity: 1; }
        ; .sortable.desc::after { content: ' \2193'; opacity: 1; }
        ; .addr-search { color: var(--text); text-decoration: none; }
        ; .addr-search:hover { color: var(--link); text-decoration: underline; }
        ; .search-form { display: flex; gap: 8px; align-items: center; margin-bottom: 12px; }
        ; .search-form input[type="text"] { padding: 8px 12px; border: 1px solid var(--input-border); border-radius: 6px; font-size: 14px; flex: 1; max-width: 400px; background: var(--input-bg); color: var(--text); }
        ; .search-form input[type="text"]:focus { outline: 2px solid var(--link); outline-offset: -2px; border-color: var(--link); }
        ; .search-clear { font-size: 13px; color: var(--color-error); }
        ; .status-badge { padding: 2px 8px; border-radius: 10px; font-size: 0.8em; font-weight: 600; }
        ; .status-pending { background: var(--color-warning); color: #000; }
        ; .status-approved { background: var(--color-success); color: #fff; }
        ; .status-rejected { background: var(--color-error); color: #fff; }
        ; .gateway-table { min-width: 600px; }
        ; .gateway-table th, .gateway-table td { padding: 10px 12px; white-space: nowrap; }
        ; .gateway-table td:first-child { white-space: normal; word-break: break-all; min-width: 120px; }
        ; .paid-row { background: rgba(243,156,18,0.08); }
        ; .paid-row:hover { background: rgba(243,156,18,0.15); }
        ; .gw-filter { display: inline-block; padding: 6px 16px; border-radius: 6px; font-size: 13px; line-height: 1.4; font-weight: 500; text-decoration: none; border: 1px solid var(--input-border); background: var(--input-bg); color: var(--text); cursor: pointer; box-sizing: border-box; }
        ; .gw-filter:hover { border-color: var(--link); color: var(--link); }
        ; .gw-filter.active { background: var(--link); color: #fff; border-color: var(--link); }
        ; .compose-form .gw-search, .gw-search { padding: 6px 10px; border: 1px solid var(--input-border); border-radius: 6px; font-size: 13px; line-height: 1.4; width: 220px; background: var(--input-bg); color: var(--text); box-sizing: border-box; margin: 0; }
        ; .gw-search:focus { outline: 2px solid var(--link); outline-offset: -2px; border-color: var(--link); }
        ; input:focus, textarea:focus, select:focus, button:focus, a.btn:focus { outline: 2px solid var(--link); outline-offset: -2px; }
        ; .btn-approve { background: var(--color-success); color: #fff; border: none; cursor: pointer; padding: 4px 12px; border-radius: 4px; font-size: 13px; }
        ; .btn-approve:hover { background: var(--color-success-hover); }
        ; .btn-reject { background: var(--color-error); color: #fff; border: none; cursor: pointer; padding: 4px 12px; border-radius: 4px; font-size: 13px; }
        ; .btn-reject:hover { background: var(--color-error-hover); }
        ; .donate-addr { background: var(--input-bg); padding: 8px 12px; border-radius: 6px; font-size: 13px; word-break: break-all; border: 1px solid var(--input-border); }
        ; .help-page { font-size: 15px; line-height: 1.7; }
        ; .help-page h3 { margin-top: 24px; margin-bottom: 8px; font-size: 18px; color: var(--link); border-bottom: 1px solid var(--border); padding-bottom: 6px; }
        ; .help-page p { margin: 8px 0; color: var(--text); }
        ; .help-page ol, .help-page ul { padding-left: 24px; margin: 8px 0; }
        ; .help-page li { margin: 4px 0; }
        ; .help-page code { background: var(--input-bg); padding: 2px 8px; border-radius: 4px; font-size: 14px; }
        ::  tablet breakpoint
        ; @media (max-width: 768px) {
        ;   .nav-logo { width: auto; margin-right: 20px; }
        ;   .col-labels { display: none; }
        ;   .gw-search { width: 160px; }
        ; }
        ::  mobile breakpoint
        ; @media (max-width: 480px) {
        ;   .nav-inner { flex-wrap: wrap; padding: 8px 12px; }
        ;   .nav-logo { width: auto; margin-right: auto; font-size: 18px; }
        ;   .nav-links { order: 3; width: 100%; overflow-x: auto; -webkit-overflow-scrolling: touch; gap: 4px; padding-top: 6px; border-top: 1px solid rgba(255,255,255,0.1); }
        ;   nav a { margin-right: 12px; font-size: 13px; white-space: nowrap; }
        ;   .nav-right { order: 2; }
        ;   .ship-name { font-size: 12px; max-width: 120px; overflow: hidden; text-overflow: ellipsis; }
        ;   .container { padding: 10px; padding-top: env(safe-area-inset-top, 10px); overflow-x: hidden; max-width: 100vw; box-sizing: border-box; }
        ;   .inbox-main { overflow-x: hidden; width: 100%; }
        ;   body { overflow-x: hidden; }
        ;   .inbox-table, .sent-table { width: 0; height: 0; overflow: hidden; }
        ;   .search-form { flex-wrap: wrap; max-width: 100%; }
        ;   .search-form input[type="text"] { max-width: none; width: 100%; box-sizing: border-box; flex: 1; min-width: 0; }
        ;   table:not(.gateway-table) { width: 100%; }
        ;   table:not(.gateway-table) th, table:not(.gateway-table) td { padding: 8px 6px; font-size: 13px; }
        ;   .gateway-table th, .gateway-table td { padding: 6px 8px; font-size: 12px; }
        ;   .col-narrow { display: none; }
        ;   .col-labels { display: none; }
        ;   .col-status { width: auto; }
        ;   .col-to { width: auto; }
        ;   .col-date { width: auto; font-size: 11px; }
        ;   .inbox-table, .sent-table { display: none; }
        ;   .mobile-select-all { display: block; padding: 8px 12px; }
        ;   .mobile-cards { display: block !important; }
        ;   .compose-form { padding: 12px; }
        ;   .compose-form textarea { height: 150px; }
        ;   .gw-search { width: 100%; }
        ;   .gw-filter { padding: 5px 10px; font-size: 12px; }
        ;   .btn-approve, .btn-reject { padding: 4px 8px; font-size: 12px; }
        ;   .alias-domain { display: none; }
        ; }
        ; @media (max-width: 600px) { .alias-cfg-grid { grid-template-columns: 1fr !important; } }
      ==
    ==
    ;body(data-page (trip page))
      ;+  (render-nav page unread our is-gw pending-gw)
      ;div(class "container")
        ;+  body
      ==
      ;div(style "text-align: center; padding: 8px; font-size: 11px; color: var(--muted); opacity: 0.5;")
        ;span: {full-version}
        ;span(style "margin-left: 8px;"): ·
        ;a(href "/mail/compose?to=~poster-midnev&subject=Feedback&labels=mail,feedback", style "margin-left: 8px; color: var(--muted);"): Send Feedback
      ==
      ;div(id "toast", class "toast"): Copied!
      ;div(id "batch-bar")
        ;span(id "batch-count"): 0 selected
        ;button(class "batch-read", onclick "batchAction('batch-mark-read')"): Mark Read
        ;button(class "batch-unread", onclick "batchAction('batch-mark-unread')"): Mark Unread
        ;button(class "batch-delete", onclick "batchAction('batch-delete')"): Delete
      ==
      ;div(id "img-overlay", class "img-overlay")
        ;img(id "img-overlay-img", src "data:,");
      ==
      ;script(src "/mail/app.js?v={build-version}", defer "defer")
        ;
      ==
    ==
  ==
::  render-pagination: page navigation with numbered links
::
++  render-pagination
  |=  [page=@ud total-pages=@ud base-url=tape hash=tape]
  ^-  manx
  ?:  (lte total-pages 1)
    ;div;
  |^
  =/  sep=tape  ?:(=(~ (find "?" base-url)) "?" "&")
  ::  build set of pages to show: first 3, last, current + neighbors
  =/  show=(set @ud)
    ?:  (lte total-pages 5)
      (silt (gulf 1 total-pages))
    =/  s=(set @ud)  (silt ~[1 2 3 total-pages page])
    =?  s  (gth page 1)  (~(put in s) (dec page))
    =?  s  (lth page total-pages)  (~(put in s) +(page))
    s
  =/  pages=(list @ud)
    %+  sort
      %+  skim  ~(tap in show)
      |=(n=@ud ?&((gte n 1) (lte n total-pages)))
    lth
  ::  build items: page links with dots for gaps
  =/  items=(list manx)  ~
  =/  prev=@ud  0
  =.  items
    |-
    ?~  pages  (flop items)
    =/  n=@ud  i.pages
    =?  items  (gth n +(prev))
      :-  ;span(class "page-dots"): ...
      items
    $(pages t.pages, prev n, items [(page-el n sep) items])
  ::  wrap: Prev + page numbers + Next
  ;div(class "pagination")
    ;*  :(weld prev-link items next-link)
  ==
  ::
  ++  page-el
    |=  [n=@ud sep=tape]
    ^-  manx
    ?:  =(n page)
      ;span(class "page-num current"): {(a-co:co n)}
    ;a(href "{base-url}{sep}page={(a-co:co n)}{hash}", class "page-num"): {(a-co:co n)}
  ::
  ++  prev-link
    ^-  (list manx)
    ?.  (gth page 1)  ~
    =/  sep=tape  ?:(=(~ (find "?" base-url)) "?" "&")
    :~  ;a(href "{base-url}{sep}page={(a-co:co (dec page))}{hash}", class "page-nav"): < Prev
    ==
  ::
  ++  next-link
    ^-  (list manx)
    ?.  (lth page total-pages)  ~
    =/  sep=tape  ?:(=(~ (find "?" base-url)) "?" "&")
    :~  ;a(href "{base-url}{sep}page={(a-co:co (add page 1))}{hash}", class "page-nav"): Next >
    ==
  --
::  render-label-sidebar: sidebar with label list and counts
::
++  render-label-sidebar
  |=  [labels=(set @tas) =inbox current=(unit @tas)]
  ^-  manx
  =/  label-list=(list @tas)
    %+  sort  ~(tap in labels)
    |=  [a=@tas b=@tas]
    (aor a b)
  ?~  label-list
    ;div;
  ;div(class "label-sidebar")
    ;details(class "label-details", open "")
      ;summary: Labels
      ;a(href "/mail", class ?~(current "active-label" ""))
        ;span: All
      ==
      ;*  %+  turn  label-list
          |=  l=@tas
          =/  count=@ud
            %-  ~(rep by inbox)
            |=  [[id=@uv env=envelope] acc=@ud]
            ?:((~(has in labels.env) l) +(acc) acc)
          =/  active  ?~(current %.n =(u.current l))
          ;a(href "/mail?label={(trip l)}", class ?:(active "active-label" ""))
            ;span(class "label-dot", data-label (trip l));
            ;span: {(trip l)}
            ;span(class "label-count"): ({(a-co:co count)})
          ==
    ==
  ==
::  render-welcome: first-run onboarding block
::
++  render-welcome
  |=  [our=@p gw-st=?(%pending %approved %rejected) addr=(unit @t)]
  ^-  manx
  =/  ship-name=tape  (scow %p our)
  =/  is-comet=?  (gte (met 3 (scot %p our)) 55)
  ;div(class "compose-form", style "max-width: 600px; margin: 0 auto;")
    ;*  ?.  is-comet  ~
        :~  ;div(style "background: var(--color-error); color: #fff; padding: 12px; border-radius: 6px; margin-bottom: 16px;")
              ;p(style "font-weight: 600; margin: 0 0 4px 0;"): Comet Limitations
              ;p(style "margin: 0 0 6px 0; font-size: 13px;"): Comets are anonymous identities with restricted mail functionality:
              ;ul(style "margin: 0; padding-left: 20px; font-size: 13px;")
                ;li: Cannot send messages (no outgoing mail)
                ;li: Cannot access gateways (no external email)
                ;li: Cannot register or purchase aliases
                ;li: Cannot run a gateway
                ;li: Can only receive internal Urbit mail from other ships
              ==
              ;p(style "margin: 6px 0 0 0; font-size: 13px;"): Get a planet to unlock full email functionality.
            ==
        ==
    ;h2(style "margin-bottom: 16px;"): Welcome to Urbit Mail
    ;p(style "font-size: 15px; line-height: 1.7; margin-bottom: 20px; color: var(--text);"): Your ship {ship-name} is ready. Sovereign email — no subscriptions, no ads, no tracking. You own everything.
    ;div(style "background: var(--info-bg); border-radius: 8px; padding: 16px; margin-bottom: 20px;")
      ;div(style "display: flex; align-items: center; gap: 8px; margin-bottom: 8px;")
        ;span(style "font-weight: 600; color: {?:(?=(%approved gw-st) "var(--color-success)" ?:(?=(%pending gw-st) "var(--color-warning)" "var(--color-error)"))}"): {?:(?=(%approved gw-st) "[OK]" ?:(?=(%pending gw-st) "[...]" "[!]"))} Gateway {?:(?=(%approved gw-st) "connected" ?:(?=(%pending gw-st) "connecting..." "rejected"))}
      ==
      ;*  ?~  addr
          :~  ;p(style "font-size: 13px; color: var(--muted);"): Waiting for gateway approval. Your email address will appear here once ready.
          ==
      :~  ;div(style "margin-top: 4px;")
            ;p(style "font-size: 13px; color: var(--muted); margin-bottom: 4px;"): Your email address:
            ;div(style "display: flex; align-items: center; gap: 8px;")
              ;code(style "font-size: 16px; font-weight: 600; padding: 6px 12px; background: var(--input-bg); border: 1px solid var(--input-border); border-radius: 4px;"): {(trip u.addr)}
              ;button(class "copy-btn", data-copy (trip u.addr), style "padding: 4px 10px; font-size: 12px;"): Copy
            ==
          ==
      ==
    ==
    ;h3(style "margin-bottom: 12px; font-size: 15px; color: var(--muted);"): What you can do
    ;div(style "display: flex; flex-direction: column; gap: 12px; margin-bottom: 24px;")
      ;div(style "padding: 12px; background: var(--card); border: 1px solid var(--border); border-radius: 6px;")
        ;p(style "font-weight: 600; margin-bottom: 4px;"): Send mail to any Urbit ship
        ;p(style "font-size: 13px; color: var(--muted);"): Works immediately via Ames. No gateway needed.
      ==
      ;div(style "padding: 12px; background: var(--card); border: 1px solid var(--border); border-radius: 6px;")
        ;p(style "font-weight: 600; margin-bottom: 4px;"): Send and receive email
        ;p(style "font-size: 13px; color: var(--muted);"): Communicate with Gmail, Protonmail, and any email address through your gateway. Outbound email (to external addresses) is limited to 10 messages/hour. Ship-to-ship mail is unlimited.
      ==
      ;div(style "padding: 12px; background: var(--card); border: 1px solid var(--border); border-radius: 6px;")
        ;p(style "font-weight: 600; margin-bottom: 4px;"): Get a short alias
        ;p(style "font-size: 13px; color: var(--muted);"): Use alex@domain instead of your full ship name.
      ==
      ;div(style "padding: 12px; background: var(--card); border: 1px solid var(--border); border-radius: 6px;")
        ;p(style "font-weight: 600; margin-bottom: 4px;"): Auto-forward mail
        ;p(style "font-size: 13px; color: var(--muted);"): Forward incoming mail to other ships or email addresses.
      ==
    ==
    ;div(style "display: flex; gap: 10px; flex-wrap: wrap;")
      ;a(href "/mail/compose", class "btn", style "padding: 8px 20px;"): Compose First Email
      ;a(href "/mail/settings", class "btn btn-secondary", style "padding: 8px 20px;"): Settings
      ;a(href "/mail/help", class "btn btn-secondary", style "padding: 8px 20px;"): Help
    ==
    ;p(style "margin-top: 20px; font-size: 12px; color: var(--muted);"): This page disappears once you send or receive your first email.
  ==
::  render-inbox: inbox message list
::
++  render-inbox
  |=  [=inbox all-inbox=(map @uv envelope) labels=(set @tas) current=(unit @tas) search=(unit @t) page=@ud per-page=@ud]
  ^-  manx
  =/  msgs=(list [id=@uv env=envelope])  ~(tap by inbox)
  =/  sorted=(list [id=@uv env=envelope])
    %+  sort  msgs
    |=  [[* a=envelope] [* b=envelope]]
    (gth sent-at.msg.a sent-at.msg.b)
  =/  total=@ud  (lent sorted)
  =/  total-pages=@ud
    ?:  =(0 total)  1
    (add (div total per-page) ?:((gth (mod total per-page) 0) 1 0))
  =/  offset=@ud  (mul (dec page) per-page)
  =/  paged=(list [id=@uv env=envelope])  (scag per-page (slag offset sorted))
  =/  base-url=tape
    ?~  current
      ?~  search  "/mail"
      "/mail?q={(url-enc (trip u.search))}"
    ?~  search
      "/mail?label={(trip u.current)}"
    "/mail?label={(trip u.current)}&q={(url-enc (trip u.search))}"
  =/  clear-url=tape
    ?~  current  "/mail"
    "/mail?label={(trip u.current)}"
  ?~  sorted
    ;div(class "inbox-layout")
      ;+  (render-label-sidebar labels all-inbox current)
      ;div(class "inbox-main")
        ;form(method "get", action "/mail", class "search-form")
          ;*  ?~  current  ~
              :~  ;input(type "hidden", name "label", value (trip u.current));
              ==
          ;input(type "text", name "q", placeholder "Search inbox...", value ?~(search "" (trip u.search)));
          ;button(type "submit", class "btn"): Search
        ==
        ;div(class "empty")
          ;p: {?~(search "No messages in inbox." "No results found.")}
          ;*  ?~  search
              :~  ;p
                    ;a(href "/mail/compose"): Compose a new message
                  ==
              ==
          :~  ;a(href clear-url, style "font-size: 13px; color: var(--color-error);"): Clear search
          ==
        ==
      ==
    ==
  ;div(class "inbox-layout")
    ;+  (render-label-sidebar labels all-inbox current)
    ;div(class "inbox-main")
      ;form(method "get", action "/mail", class "search-form")
        ;*  ?~  current  ~
            :~  ;input(type "hidden", name "label", value (trip u.current));
            ==
        ;input(type "text", name "q", placeholder "Search inbox...", value ?~(search "" (trip u.search)));
        ;button(type "submit", class "btn"): Search
        ;*  ?~  search  ~
            :~  ;a(href clear-url, class "search-clear"): Clear
            ==
      ==
      ;*  ?.  ?=(^ current)  ~
          :~  ;div(style "display: flex; align-items: center; gap: 8px; margin-bottom: 12px; padding: 8px 12px; background: var(--info-bg); border-radius: 8px; font-size: 13px; color: var(--th-text);")
                ;span: Filtering by:
                ;span(class "label-badge"): {(trip u.current)}
                ;a(href "/mail", style "margin-left: auto; font-size: 12px; color: var(--color-error);"): clear
              ==
          ==
      ::  mobile card view
      ;div(class "mobile-select-all")
        ;label(style "display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--muted); cursor: pointer;")
          ;input(type "checkbox", class "select-all-mobile", style "width: 16px; height: 16px; accent-color: var(--link);");
          ; Select all
        ==
      ==
      ;div(class "mobile-cards")
        ;*  %+  turn  paged
            |=  [id=@uv env=envelope]
            ;div(class "mobile-card {?:(=(status.env %unread) "unread" "")}")
              ;input(type "checkbox", class "msg-check mc-check", value (trip (scot %uv id)));
              ;a(href "/mail/read?id={(trip (scot %uv id))}", style "display: flex; flex: 1; min-width: 0; gap: 8px; text-decoration: none; color: inherit; align-items: center;")
                ;div(class "mc-body")
                  ;div(class "mc-from"): {(format-contact-short from.msg.env 24)}
                  ;div(class "mc-subject"): {(trip subject.msg.env)}
                  ;*  ?:  =(~ labels.env)  ~
                      :~  ;div(class "mc-labels")
                            ;*  (render-label-badges labels.env)
                          ==
                      ==
                ==
                ;span(class "mc-date date", data-da (scow %da sent-at.msg.env)): {(format-date sent-at.msg.env)}
              ==
            ==
      ==
      ::  desktop table view
      ;table(class "inbox-table")
      ;thead
        ;tr
          ;th(class "col-check")
            ;input(type "checkbox", id "select-all", title "Select all");
          ==
          ;th(class "col-narrow");
          ;th(class "col-to"): From
          ;th: Subject
          ;th(class "col-labels"): Labels
          ;th(class "col-date sortable", data-sort "date"): Date
          ;th(style "width: 40px;");
        ==
      ==
      ;tbody
        ;*  %+  turn  paged
            |=  [id=@uv env=envelope]
            =/  cls  ?:(=(status.env %unread) "unread" "")
            ;tr(class cls, data-href "/mail/read?id={(trip (scot %uv id))}")
              ;td(class "col-check")
                ;input(type "checkbox", class "msg-check", value (trip (scot %uv id)));
              ==
              ;td(class "col-narrow")
                ;*  ?:  ?=([%urbit *] from.msg.env)
                      :~  ;span(class "sigil-wrap", data-patp (scow %p p.from.msg.env));
                      ==
                    :~  ;span(class "ext-icon-sm"): @
                    ==
              ==
              ;td(title (format-contact from.msg.env))
                ;a(class "addr-search", href "/mail?q={(url-enc (format-contact from.msg.env))}", title "Find all mail from this address"): {(format-contact-short from.msg.env 28)}
              ==
              ;td
                ;a(href "/mail/read?id={(trip (scot %uv id))}"): {(trip subject.msg.env)}
              ==
              ;td(class "col-labels")
                ;div(class "labels-cell")
                  ;*  (render-label-badges labels.env)
                ==
              ==
              ;td
                ;span(class "date", data-da (scow %da sent-at.msg.env)): {(format-date sent-at.msg.env)}
              ==
              ;td(class "row-delete")
                ;form(method "post", action "/mail/delete", style "display:inline", onsubmit "return confirm('Delete this message?')")
                  ;input(type "hidden", name "id", value (trip (scot %uv id)));
                  ;button(type "submit", title "Delete"): x
                ==
              ==
            ==
      ==
    ==
    ;+  (render-pagination page total-pages base-url "")
    ==
  ==
::  render-sent: sent message list
::
++  render-sent
  |=  [=sent search=(unit @t) page=@ud per-page=@ud now=@da]
  ^-  manx
  =/  msgs=(list [id=@uv env=envelope])  ~(tap by sent)
  =/  sorted=(list [id=@uv env=envelope])
    %+  sort  msgs
    |=  [[* a=envelope] [* b=envelope]]
    (gth sent-at.msg.a sent-at.msg.b)
  =/  total=@ud  (lent sorted)
  =/  total-pages=@ud
    ?:  =(0 total)  1
    (add (div total per-page) ?:((gth (mod total per-page) 0) 1 0))
  =/  offset=@ud  (mul (dec page) per-page)
  =/  paged=(list [id=@uv env=envelope])  (scag per-page (slag offset sorted))
  =/  base-url=tape
    ?~  search  "/mail/sent"
    "/mail/sent?q={(url-enc (trip u.search))}"
  ?~  sorted
    ;div
      ;form(method "get", action "/mail/sent", class "search-form")
        ;input(type "text", name "q", placeholder "Search sent...", value ?~(search "" (trip u.search)));
        ;button(type "submit", class "btn"): Search
      ==
      ;div(class "empty")
        ;p: {?~(search "No sent messages." "No results found.")}
        ;*  ?~  search  ~
            :~  ;a(href "/mail/sent", style "font-size: 13px; color: var(--color-error);"): Clear search
            ==
      ==
    ==
  ;div
    ;form(method "get", action "/mail/sent", class "search-form")
      ;input(type "text", name "q", placeholder "Search sent...", value ?~(search "" (trip u.search)));
      ;button(type "submit", class "btn"): Search
      ;*  ?~  search  ~
          :~  ;a(href "/mail/sent", class "search-clear"): Clear
          ==
    ==
    ::  mobile card view
    ;div(class "mobile-select-all")
      ;label(style "display: flex; align-items: center; gap: 8px; font-size: 13px; color: var(--muted); cursor: pointer;")
        ;input(type "checkbox", class "select-all-mobile", style "width: 16px; height: 16px; accent-color: var(--link);");
        ; Select all
      ==
    ==
    ;div(class "mobile-cards")
      ;*  %+  turn  paged
          |=  [id=@uv env=envelope]
          ;div(class "mobile-card")
            ;input(type "checkbox", class "msg-check mc-check", value (trip (scot %uv id)));
            ;a(href "/mail/read?id={(trip (scot %uv id))}", style "display: flex; flex: 1; min-width: 0; gap: 8px; text-decoration: none; color: inherit; align-items: center;")
              ;div(class "mc-body")
                ;div(class "mc-from"): {(format-contact-short to.msg.env 24)}
                ;div(class "mc-subject"): {(trip subject.msg.env)}
                ;*  ?:  =(~ labels.env)  ~
                    :~  ;div(class "mc-labels")
                          ;*  (render-label-badges labels.env)
                        ==
                    ==
              ==
              ;div(style "text-align: right; flex-shrink: 0;")
                ;span(class "mc-date date", data-da (scow %da sent-at.msg.env)): {(format-date sent-at.msg.env)}
                ;div(class "mc-status", style "color: {?:(?=(%sending status.env) "var(--color-warning)" ?:(?=(%failed status.env) "var(--color-error)" "var(--muted)"))}"): {(trip status.env)}
              ==
            ==
          ==
    ==
    ::  desktop table view
    ;table(class "sent-table")
      ;thead
        ;tr
          ;th(class "col-check")
            ;input(type "checkbox", id "select-all", title "Select all");
          ==
          ;th(class "col-status"): Status
          ;th(class "col-narrow");
          ;th(class "col-to"): To
          ;th: Subject
          ;th(class "col-labels"): Labels
          ;th(class "col-date sortable", data-sort "date"): Date
          ;th(style "width: 40px;");
        ==
      ==
      ;tbody
        ;*  %+  turn  paged
            |=  [id=@uv env=envelope]
            ;tr(data-href "/mail/read?id={(trip (scot %uv id))}")
              ;td(class "col-check")
                ;input(type "checkbox", class "msg-check", value (trip (scot %uv id)));
              ==
              ;+  ?:  ?=(%sending status.env)
                  =/  elapsed=@dr  (sub now sent-at.msg.env)
                  =/  mins=@ud  (div (div elapsed ~s1) 60)
                  ;td(style "color: var(--color-warning)"): sending{?:((gth mins 0) " ({(a-co:co mins)}m)" "")}
                  ?:  ?=(%failed status.env)
                  ;td(style "color: var(--color-error); font-weight: 600"): failed
                  ;td: {(trip status.env)}
              ;td(class "col-narrow")
                ;*  ?:  ?=([%urbit *] to.msg.env)
                      :~  ;span(class "sigil-wrap sigil-inline", data-patp (scow %p p.to.msg.env));
                      ==
                    :~  ;span(class "ext-icon-sm"): @
                    ==
              ==
              ;td(title (format-contact to.msg.env))
                ;span: {(format-contact-short to.msg.env 28)}
              ==
              ;td
                ;a(href "/mail/read?id={(trip (scot %uv id))}"): {(trip subject.msg.env)}
              ==
              ;td(class "col-labels")
                ;div(class "labels-cell")
                  ;*  (render-label-badges labels.env)
                ==
              ==
              ;td
                ;span(class "date", data-da (scow %da sent-at.msg.env)): {(format-date sent-at.msg.env)}
              ==
              ;td(class "row-delete")
                ;form(method "post", action "/mail/delete", style "display:inline", onsubmit "return confirm('Delete this message?')")
                  ;input(type "hidden", name "id", value (trip (scot %uv id)));
                  ;button(type "submit", title "Delete"): x
                ==
              ==
            ==
      ==
    ==
    ;+  (render-pagination page total-pages base-url "")
  ==
::  render-message: single message view
::
++  render-message
  |=  env=envelope
  ^-  manx
  |^
  =/  id-text  (trip (scot %uv id.msg.env))
  ;div(class "message-view")
    ;+  (render-actions id-text %top)
    ;div(class "message-header")
      ;h2: {(trip subject.msg.env)}
      ::  mobile: collapsible details (summary always visible)
      ;details(class "msg-details", open "")
        ;summary(class "msg-summary")
          ;span: From: {(format-contact from.msg.env)} · {(format-date sent-at.msg.env)}
        ==
      ;p(class "header-line")
        ;span(class "label"): From:
        ;*  ?.  ?=([%urbit *] from.msg.env)  ~
            :~  ;span(class "sigil-wrap sigil-inline", data-patp (scow %p p.from.msg.env));
            ==
        ;span: {(format-contact from.msg.env)}
        ;button(class "copy-btn", data-copy (format-contact from.msg.env)): copy
      ==
      ;p(class "header-line")
        ;span(class "label"): To:
        ;*  ?.  ?=([%urbit *] to.msg.env)  ~
            :~  ;span(class "sigil-wrap sigil-inline", data-patp (scow %p p.to.msg.env));
            ==
        ;span: {(format-contact to.msg.env)}
        ;button(class "copy-btn", data-copy (format-contact to.msg.env)): copy
        ;*  ?:  =('' recv-addr.env)  ~
            :~  ;span(class "via"): via {(trip recv-addr.env)}
                ;button(class "copy-btn", data-copy (trip recv-addr.env)): copy
            ==
      ==
      ;*  ?~  reply-to.msg.env  ~
          =/  rt  u.reply-to.msg.env
          ?:  =(rt from.msg.env)  ~
          :~  ;p(class "header-line")
                ;span(class "label"): Reply-To:
                ;*  ?.  ?=([%urbit *] rt)  ~
                    :~  ;span(class "sigil-wrap sigil-inline", data-patp (scow %p p.rt));
                    ==
                ;span: {(format-contact rt)}
                ;button(class "copy-btn", data-copy (format-contact rt)): copy
              ==
          ==
      ;*  ?:  =(~ cc.msg.env)  ~
          :~  ;p(class "header-line")
                ;span(class "label"): CC:
                ;*  %+  turn  cc.msg.env
                    |=  c=contact
                    ;span(class "cc-item")
                      ;*  ?.  ?=([%urbit *] c)  ~
                          :~  ;span(class "sigil-wrap sigil-inline", data-patp (scow %p p.c));
                          ==
                      ;span: {(format-contact c)}
                    ==
              ==
          ==
      ;*  ?:  =(~ route.msg.env)  ~
          =/  route-text=tape  (join-ships route.msg.env)
          =/  hops=@ud  (lent route.msg.env)
          ?:  (lte hops 2)
            :~  ;p(style "margin: 4px 0;")
                  ;span(class "label"): Relayed via:
                  ;span(style "color: var(--muted); font-size: 0.9em;"): {route-text}
                ==
            ==
          :~  ;details(style "margin: 4px 0;")
                ;summary(style "cursor: pointer; color: var(--muted); font-size: 0.9em;"): Relayed via {(a-co:co hops)} ships
                ;p(style "font-size: 0.85em; color: var(--muted); margin: 4px 0 0 12px;"): {route-text}
              ==
          ==
      ;p
        ;span(class "label"): Date:
        ;span(class "date", data-da (scow %da sent-at.msg.env)): {(format-date sent-at.msg.env)}
      ==
      ;p
        ;span(class "label"): Status:
        ;span: {(trip status.env)}
      ==
      ;div(class "label-section")
        ;span(class "label"): Labels:
        ;*  ?:  =(~ labels.env)
              :~  ;span(style "color: var(--muted);"): none
              ==
            %+  turn  ~(tap in labels.env)
            |=  l=@tas
            ;form(method "post", action "/mail/remove-label", style "display:inline")
              ;input(type "hidden", name "id", value id-text);
              ;input(type "hidden", name "label", value (trip l));
              ;span(class "label-badge")
                ;span: {(trip l)}
                ;button(type "submit", class "remove-x"): x
              ==
            ==
        ;form(method "post", action "/mail/add-label", class "label-form", style "margin-top: 6px;")
          ;input(type "hidden", name "id", value id-text);
          ;input(type "text", name "label", placeholder "add label...", required "");
          ;button(type "submit"): +
        ==
      ==
      ==
    ==
    ;div(class "message-body")
      ;+  (render-body (trip body.msg.env))
    ==
    ;pre(class "message-source", style "display:none"): {(trip body.msg.env)}
    ;+  (render-actions id-text %bottom)
  ==
  ++  render-actions
    |=  [id-text=tape pos=?(%top %bottom)]
    ^-  manx
    ;div(class "message-actions {?:(=(%top pos) "top" "bottom")}")
      ;a(href ?:(=(folder.env %sent) "/mail/sent" "/mail"), class "btn btn-secondary"): Back
      ;a(href "/mail/compose?reply={(trip (scot %uv id.msg.env))}", class "btn"): Reply
      ;*  ?:  =(~ cc.msg.env)  ~
          :~  ;a(href "/mail/compose?replyall={(trip (scot %uv id.msg.env))}", class "btn"): Reply All
          ==
      ;a(href "/mail/compose?forward={(trip (scot %uv id.msg.env))}", class "btn btn-secondary"): Forward
      ;*  ?.  ?&(=(folder.env %sent) =(%failed status.env))  ~
          :~  ;form(method "post", action "/mail/resend", style "display:inline")
                ;input(type "hidden", name "id", value id-text);
                ;button(type "submit", class "btn", style "background: var(--color-success); color: #fff;"): Resend
              ==
          ==
      ;*  ?:  =(folder.env %sent)  ~
          ?:  =(status.env %unread)
            :~  ;form(method "post", action "/mail/mark-read", style "display:inline")
                  ;input(type "hidden", name "id", value id-text);
                  ;button(type "submit", class "btn btn-secondary"): Mark Read
                ==
            ==
          :~  ;form(method "post", action "/mail/mark-unread", style "display:inline")
                ;input(type "hidden", name "id", value id-text);
                ;button(type "submit", class "btn btn-secondary"): Mark Unread
              ==
          ==
      ;form(method "post", action "/mail/delete", style "display:inline", onsubmit "return confirm('Delete this message?')")
        ;input(type "hidden", name "id", value id-text);
        ;button(type "submit", class "btn btn-danger"): Delete
      ==
    ==
  ++  join-ships
    |=  ships=(list @p)
    ^-  tape
    ?~  ships  ~
    ?~  t.ships  (trip (scot %p i.ships))
    (weld (trip (scot %p i.ships)) (weld " > " $(ships t.ships)))
  --
::  render-compose: compose message form
::
++  render-compose
  |=  $:  to=tape  subject=tape  body=tape  cc=tape
          labels=(list @tas)  mode=@tas
          our=@p  doms=(map @p @t)  sel-gw=(unit @p)
          aliases=(map @p (list [@t ?]))
          sel-alias=(unit @t)
      ==
  ^-  manx
  =/  ship-name=tape  (slag 1 (scow %p our))
  =/  dom-list=(list [gw=@p dom=@t])
    %+  skim  ~(tap by doms)
    |=  [g=@p d=@t]
    !=('' d)
  =/  alias-opts=(list [gw=@p a=@t dom=@t])
    %-  zing
    %+  turn  dom-list
    |=  [g=@p d=@t]
    =/  als=(list [@t ?])  (fall (~(get by aliases) g) *(list [@t ?]))
    =/  active-als=(list @t)  (murn als |=([n=@t ac=?] ?:(ac `n ~)))
    ^-  (list [gw=@p a=@t dom=@t])
    (turn active-als |=(a=@t [g a d]))
  ::  if sel-alias set but not in opts, add it
  =?  alias-opts  ?=(^ sel-alias)
    =/  already=?  (lien alias-opts |=([* a=@t *] =(a u.sel-alias)))
    ?.  already
      ::  find gateway and domain for this alias
      =/  gw=@p  (fall sel-gw ~zod)
      =/  d=@t
        =/  found=(unit @t)  (~(get by doms) gw)
        ?^  found  u.found
        ::  fallback: search all domains
        =/  all=(list [g=@p d=@t])  ~(tap by doms)
        ?~  all  ''
        d.i.all
      ?:  =('' d)  alias-opts
      (snoc alias-opts [gw u.sel-alias d])
    alias-opts
  ::  also ensure dom-list has at least the sel-gw domain
  =?  dom-list  &(?=(^ sel-gw) =(~ dom-list))
    =/  d=(unit @t)  (~(get by doms) u.sel-gw)
    ?~  d  ~
    ?:(=('' u.d) ~ ~[[u.sel-gw u.d]])
  =/  has-choices=?  ?|((gte (lent dom-list) 2) !=(~ alias-opts) ?=(^ sel-alias))
  ;div(class "compose-form")
    ;h2: {?:(=(mode %reply) "Reply" ?:(=(mode %replyall) "Reply All" ?:(=(mode %forward) "Forward" "Compose Message")))}
    ;form(method "post", action "/mail/send")
      ;*  ?.  has-choices  ~
          :~  ;label(for "from-gateway"): From:
          ==
      ;*  ?.  has-choices
            ::  0 or 1 domain, no aliases — no dropdown
            ?~  dom-list  ~
            =/  addr=tape  (weld ship-name (weld "@" (trip dom.i.dom-list)))
            :~  ;input(type "hidden", name "from-gateway", value (scow %p gw.i.dom-list));
                ;p(class "help"): Sending as {addr}
            ==
          ::  multiple options — dropdown with ship addresses + aliases
          :~  ;select(name "from-gateway", id "from-gateway", class "compose-select")
                ;*  %+  weld
                    ::  ship addresses
                    ^-  (list manx)
                    %+  turn  dom-list
                    |=  [g=@p d=@t]
                    =/  addr=tape  (weld ship-name (weld "@" (trip d)))
                    =/  is-sel=?  ?&(?~(sel-alias %.y %.n) ?~(sel-gw %.n =(g u.sel-gw)))
                    ?:  is-sel
                      ;option(value (scow %p g), selected "selected"): {addr}
                    ;option(value (scow %p g)): {addr}
                    ::  alias addresses
                    ^-  (list manx)
                    %+  turn  alias-opts
                    |=  [g=@p a=@t d=@t]
                    =/  addr=tape  (weld (trip a) (weld "@" (trip d)))
                    =/  is-sel=?  ?&(?=(^ sel-alias) =(a u.sel-alias) ?~(sel-gw %.y =(g u.sel-gw)))
                    ?:  is-sel
                      ;option(value "{(scow %p g)} {(trip a)}", selected "selected"): {addr}
                    ;option(value "{(scow %p g)} {(trip a)}"): {addr}
              ==
          ==
      ;label(for "to"): To:
      ;input(type "text", name "to", id "to", placeholder "~sampel-palnet or user@example.com", required "", value to);
      ;p(class "help"): Enter an Urbit ship name (~ship) or email address
      ;a(id "cc-toggle", href "#", class "cc-toggle"): CC / BCC
      ;div(id "cc-fields", class "cc-fields")
        ;label(for "cc"): CC:
        ;input(type "text", name "cc", id "cc", placeholder "Comma-separated addresses (optional)", value cc);
        ;label(for "bcc"): BCC:
        ;input(type "text", name "bcc", id "bcc", placeholder "Hidden recipients (optional)", value "");
      ==
      ;label(for "subject"): Subject:
      ;input(type "text", name "subject", id "subject", required "", value subject);
      ;*  %+  turn  labels
          |=  l=@tas
          ;input(type "hidden", name "labels", value (trip l));
      ;label(for "label-add-input"): Labels (optional):
      ;div(id "compose-labels", style "display: flex; flex-wrap: wrap; gap: 4px; margin-bottom: 6px;")
        ;*  %+  turn  labels
            |=  l=@tas
            ;span(class "label-badge", data-label (trip l))
              ;span: {(trip l)}
              ;button(type "button", class "remove-x label-remove"): x
            ==
      ==
      ;div(style "display: flex; gap: 4px; align-items: center;")
        ;input(type "text", id "label-add-input", name "labels-text", placeholder "add label...", style "width: 150px; margin: 0; padding: 4px 8px; font-size: 13px;");
        ;button(type "button", id "label-add-btn", class "btn", style "padding: 2px 10px; font-size: 13px;"): +
      ==
      ;div(id "compose-labels-hidden")
        ;*  %+  turn  labels
            |=  l=@tas
            ;input(type "hidden", name "labels", value (trip l));
      ==
      ;label(for "body"): Message:
      ;textarea(name "body", id "body", placeholder "Write your message here..."): {body}
      ;br;
      ;span(id "send-error", style "display:none; color:var(--color-error); font-size:13px; margin-bottom:8px;");
      ;button(type "submit", class "btn", id "send-btn"): Send
      ;a(href "/mail", class "btn btn-secondary"): Cancel
      ;span(id "draft-status", style "font-size: 12px; color: var(--muted); opacity: 0; transition: opacity 0.3s; margin-left: 8px;");
      ;button(type "button", id "clear-draft", class "btn btn-secondary", style "display:none; font-size: 12px; padding: 4px 10px; margin-left: 4px;"): Clear draft
    ==
  ==
::  render-error: error page
::
++  render-error
  |=  [title=tape msg=tape]
  ^-  manx
  ;div(class "message-view")
    ;h2: {title}
    ;p(style "margin: 15px 0; color: var(--color-error);"): {msg}
    ;button(onclick "history.back()", class "btn", style "margin-right: 8px;"): Back
  ==
::  render-404: not found page
::
++  render-404
  ^-  manx
  ;div(class "empty")
    ;h2: Page Not Found
    ;p
      ;a(href "/mail"): Go to Inbox
    ==
  ==
--
