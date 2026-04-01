/-  *mail-client
/-  *mail-gateway
/+  default-agent, dbug, server, mc=mail-client, ui=mail-ui, ui-set=mail-ui-settings, ui-gw=mail-ui-gateway, hkdf
|%
+$  card  card:agent:gall
::  NOTE: when changing state type, also update:
::  - sur/mail-client.hoon (new state type + versioned-state)
::  - lib/mail-client.hoon (state-to-json, json-to-state, restore-from-json)
::  - on-load migration in this file
::  - on-save version tag in this file
+$  state  current-state
--
%-  agent:dbug
=|  state
=*  state  -
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)
::
++  on-init
  ^-  (quip card _this)
  ~&  >  '%mail-client installed'
  ~&  >  '%mail: default gateway set to {<default-gateway>}'
  =/  first-backup=@da  (add now.bowl ~h1)
  =/  is-comet=?  (is-comet:mc our.bowl)
  :_  this(gateway `default-gateway, gateways (silt ~[default-gateway]), mail-domains ~, addr-labels ~, gw-status ?:(is-comet ~ (my ~[[default-gateway %pending]])), is-gw %.n, fwd-rules ~, registry `default-registry, registry-gateways ~, my-aliases ~, pending-payment ~, backup-interval ~h1, next-backup first-backup, custom-icon-url ~)
  =/  base-cards=(list card)
    :~  [%pass /bind %arvo %e %connect [~ /mail] %mail-client]
        [%pass /gateway-info/(scot %p default-gateway) %agent [default-gateway %mail-gateway] %watch /info]
        [%pass /registry/(scot %p default-registry) %agent [default-registry %mail-registry] %watch /registry]
        [%pass /backup-timer %arvo %b %wait first-backup]
    ==
  ::  comets see gateways/registry but don't request access
  ?.  is-comet
    [[%pass /gw-req/(scot %p default-gateway) %agent [default-gateway %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%request-access ~])] base-cards]
  base-cards
::
++  on-save
  ^-  vase
  !>([%20 state])
::
++  on-load
  |=  old-vase=vase
  ^-  (quip card _this)
  ::  unwrap web-pusher state if present
  =/  raw=vase
    =/  wp=(unit [%web-pusher * vase])
      %-  mole  |.
      !<([%web-pusher * vase] old-vase)
    ?~  wp  old-vase
    ~&  >  '%mail: unwrapping web-pusher state'
    +>.u.wp
  =/  parsed=(unit versioned-state)
    %-  mole  |.
    !<(versioned-state raw)
  ?~  parsed
    ~&  >>>  '%mail: state mismatch — attempting recovery'
    ::  strategy 1: restore from %mail-recovery agent backup
    =/  backup-json=(unit @t)
      %-  mole  |.
      .^(@t %gx /(scot %p our.bowl)/mail-recovery/(scot %da now.bowl)/backup-json/noun)
    =/  json-recovered=(unit current-state)
      ?~  backup-json  ~
      ?:  =('' u.backup-json)  ~
      =/  parsed-json  (de:json:html u.backup-json)
      ?~  parsed-json  ~
      ::  extract "mail" key from backup JSON (fallback: "mail-client")
      ?.  ?=([%o *] u.parsed-json)  ~
      =/  client-json
        =/  cj  (~(get by p.u.parsed-json) 'mail')
        ?^  cj  cj
        (~(get by p.u.parsed-json) 'mail-client')
      ?~  client-json  ~
      (restore-from-json:mc (en:json:html u.client-json))
    ?^  json-recovered
      =/  backup-time=(unit @da)
        %-  mole  |.
        .^(@da %gx /(scot %p our.bowl)/mail-recovery/(scot %da now.bowl)/updated/noun)
      ~&  >>>  '%mail: RECOVERED from backup — {<~(wyt by inbox.u.json-recovered)>} inbox, {<~(wyt by sent.u.json-recovered)>} sent'
      =/  nb=@da  (add now.bowl ~h1)
      =.  state  u.json-recovered
      =.  recovered-from  backup-time
      =.  backup-interval  ~h1
      =.  next-backup  nb
      :_  this
      :~  [%pass /bind %arvo %e %connect [~ /mail] %mail-client]
          [%pass /backup-timer %arvo %b %wait nb]
      ==
    ::  strategy 2: extract inbox/sent/trash by position using ;; noun cast
    =/  body  +.q.raw
    =/  rec-inbox=(unit ^inbox)   (mole |.(;;((map @uv envelope) -.body)))
    =/  rec-sent=(unit ^sent)     (mole |.(;;((map @uv envelope) +<.body)))
    =/  rec-trash=(unit ^trash)   (mole |.(;;((map @uv envelope) +>-.body)))
    ?:  ?&(?=(^ rec-inbox) ?=(^ rec-sent) ?=(^ rec-trash))
      ~&  >  '%mail: RECOVERED {<~(wyt by u.rec-inbox)>} inbox, {<~(wyt by u.rec-sent)>} sent, {<~(wyt by u.rec-trash)>} trash'
      =/  nb=@da  (add now.bowl ~h1)
      :_  this(inbox u.rec-inbox, sent u.rec-sent, trash u.rec-trash, gateway `default-gateway, gateways (silt ~[default-gateway]), backup-interval ~h1, next-backup nb)
      :~  [%pass /bind %arvo %e %connect [~ /mail] %mail-client]
          [%pass /gateway-info/(scot %p default-gateway) %agent [default-gateway %mail-gateway] %watch /info]
          [%pass /gw-req/(scot %p default-gateway) %agent [default-gateway %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%request-access ~])]
          [%pass /backup-timer %arvo %b %wait nb]
      ==
    ~&  >>>  '%mail: recovery FAILED — reinitializing with empty state'
    on-init
  ?-  -.u.parsed
      %19
    ~&  >  '%mail: migrating state 19 → 20'
    =/  nb=@da  (add now.bowl ~m1)
    :_  this(inbox inbox.+.u.parsed, sent sent.+.u.parsed, trash trash.+.u.parsed, gateway gateway.+.u.parsed, gateways gateways.+.u.parsed, mail-domains mail-domains.+.u.parsed, addr-labels addr-labels.+.u.parsed, gw-status gw-status.+.u.parsed, is-gw is-gw.+.u.parsed, fwd-rules fwd-rules.+.u.parsed, registry registry.+.u.parsed, registry-gateways registry-gateways.+.u.parsed, my-aliases my-aliases.+.u.parsed, pending-payment pending-payment.+.u.parsed, gw-alias-cfg gw-alias-cfg.+.u.parsed, recovered-from recovered-from.+.u.parsed, backup-interval backup-interval.+.u.parsed, next-backup nb, custom-icon-url ~)
    :~  [%pass /bind %arvo %e %connect [~ /mail] %mail-client]
        [%pass /backup-timer %arvo %b %wait nb]
    ==
    ::
      %20
    =/  nb=@da  next-backup.+.u.parsed
    =/  new-nb=@da  ?:((gth nb now.bowl) nb (add now.bowl backup-interval.+.u.parsed))
    :_  this(state +.u.parsed(next-backup new-nb))
    =/  cards=(list card)
      :~  [%pass /bind %arvo %e %connect [~ /mail] %mail-client]
          [%pass /backup-timer %arvo %b %wait new-nb]
      ==
    ?.  (gth nb now.bowl)  cards
    [[%pass /backup-timer %arvo %b %rest nb] cards]
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+  mark  `this
    ::  %handle-http-request: web UI
    ::
      %handle-http-request
    |^
    =+  !<([req-id=@ta req=inbound-request:eyre] vase)
    =/  url  (parse-request-line:server url.request.req)
    ::  auth gate: allow static assets without login, require auth for everything else
    ::
    ?.  authenticated.req
      =/  public=?
        ?+  site.url  %.n
          [%mail %manifest ~]          %.y
          [%mail %sw ~]                %.y
          [%mail %icon-192 ~]          %.y
          [%mail %icon-512 ~]          %.y
          [%mail %apple-touch-icon ~]  %.y
          [%mail %apple-icon ~]        %.y
          [%mail %favicon-32 ~]        %.y
          [%mail %img %tile ~]         %.y
        ==
      ?:  public
        (handle-get req-id url header-list.request.req)
      :_  this
      %+  give-simple-payload:app:server  req-id
      [[303 ~[['location' '/~/login?redirect=/mail']]] ~]
    ?+  method.request.req  (give-405 req-id)
        %'GET'   (handle-get req-id url header-list.request.req)
        %'POST'  (handle-post req-id url body.request.req)
    ==
    ::
    ::
    ++  unread-count
      ^-  @ud
      %-  ~(rep by inbox)
      |=  [[id=@uv env=envelope] acc=@ud]
      ?:(=(status.env %unread) +(acc) acc)
    ::
    ++  pending-gw-count
      ^-  @ud
      ?.  is-gw  0
      (fall (mole |.(.^(@ud %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/pending-count/noun))) 0)
    ::
    ++  all-labels
      ^-  (set @tas)
      %-  ~(rep by inbox)
      |=  [[id=@uv env=envelope] a=(set @tas)]
      (~(uni in a) labels.env)
    ::
    ++  give-html
      |=  [req-id=@ta page=manx]
      ^-  (quip card _this)
      =/  bod=@t  (crip (en-xml:html page))
      :_  this
      %+  give-simple-payload:app:server  req-id
      :-  [200 ~[['content-type' 'text/html; charset=utf-8'] ['cache-control' 'no-cache']]]
      `(as-octs:mimes:html bod)
    ::
    ++  give-redirect
      |=  [req-id=@ta url=@t]
      ^-  (quip card _this)
      :_  this
      %+  give-simple-payload:app:server  req-id
      :-  [303 ~[['location' url]]]
      ~
    ::  update-env: find envelope in inbox/sent, transform, emit update, redirect
    ::
    ++  update-env
      |=  $:  req-id=@ta
              id=@uv
              transform=$-(envelope envelope)
              make-update=$-(envelope update)
              redir-url=@t
          ==
      ^-  (quip card _this)
      =/  from-inbox  (~(has by inbox) id)
      =/  from-sent   (~(has by sent) id)
      ?.  ?|(from-inbox from-sent)
        (give-error req-id "Message not found")
      =/  env=envelope
        ?:  from-inbox  (~(got by inbox) id)
        (~(got by sent) id)
      =/  new-env=envelope  (transform env)
      =/  upd-card=card
        [%give %fact ~[/updates] %mail-update !>((make-update new-env))]
      =?  inbox  from-inbox  (~(put by inbox) id new-env)
      =?  sent   from-sent   (~(put by sent) id new-env)
      =/  redir  (give-redirect req-id redir-url)
      [(weld ~[upd-card] -.redir) +.redir]
    ::
    ++  give-error
      |=  [req-id=@ta msg=tape]
      ^-  (quip card _this)
      (give-html req-id (page-layout:ui 'Error' %error unread-count our.bowl is-gw pending-gw-count (render-error:ui "Invalid request" msg)))
    ::
    ++  give-404
      |=  req-id=@ta
      ^-  (quip card _this)
      (give-html req-id (page-layout:ui '404' %error unread-count our.bowl is-gw pending-gw-count render-404:ui))
    ::
    ++  give-405
      |=  req-id=@ta
      ^-  (quip card _this)
      :_  this
      %+  give-simple-payload:app:server  req-id
      [[405 ~] `(as-octs:mimes:html 'Method Not Allowed')]
    ::
    ++  find-arg
      |=  [args=(list [key=@t value=@t]) key=@t]
      ^-  (unit @t)
      ?~  args  ~
      ?:  =(key.i.args key)
        `value.i.args
      $(args t.args)
    ::
    ++  serve-icon
      |=  [req-id=@ta name=@ta]
      ^-  (quip card _this)
      =/  icon=(unit @)
        %-  mole  |.
        .^(@ %cx (weld /(scot %p our.bowl)/mail/(scot %da now.bowl)/img ~[name %png]))
      ?~  icon  (give-404 req-id)
      :_  this
      %+  give-simple-payload:app:server  req-id
      :-  [200 ~[['content-type' 'image/png'] ['cache-control' 'public, max-age=86400']]]
      `[(met 3 u.icon) u.icon]
    ::
    ++  serve-svg
      |=  [req-id=@ta name=@ta]
      ^-  (quip card _this)
      =/  svg=(unit @)
        %-  mole  |.
        .^(@ %cx (weld /(scot %p our.bowl)/mail/(scot %da now.bowl)/img ~[name %svg]))
      ?~  svg  (give-404 req-id)
      :_  this
      %+  give-simple-payload:app:server  req-id
      :-  [200 ~[['content-type' 'image/svg+xml'] ['cache-control' 'public, max-age=86400']]]
      `[(met 3 u.svg) u.svg]
    ::
    ++  handle-get
      |=  [req-id=@ta url=request-line:server req-hdrs=(list [key=@t value=@t])]
      ^-  (quip card _this)
      =/  page=@ud
        =/  pg  (find-arg args.url 'page')
        ?~  pg  1
        ?:  =('' u.pg)  1
        (fall (slaw %ud u.pg) 1)
      =/  per-page=@ud  25
      ?+  site.url  (give-404 req-id)
          [%mail %manifest ~]
        =/  icon-src=@t  ?~(custom-icon-url '/mail/icon-192.png' u.custom-icon-url)
        =/  manifest=@t
          %-  en:json:html
          %-  pairs:enjs:format
          :~  ['name' s+'Urbit Mail']
              ['short_name' s+'Mail']
              ['id' s+'/mail']
              ['start_url' s+'/mail']
              ['display' s+'standalone']
              ['background_color' s+'#1a1d23']
              ['theme_color' s+'#1a1d23']
              :-  'icons'
              :-  %a
              =/  icon-512=@t  ?~(custom-icon-url '/mail/icon-512.png' u.custom-icon-url)
              :~  (pairs:enjs:format ~[['src' s+icon-src] ['sizes' s+'192x192'] ['type' s+'image/png']])
                  (pairs:enjs:format ~[['src' s+icon-512] ['sizes' s+'512x512'] ['type' s+'image/png']])
              ==
          ==
        :_  this
        %+  give-simple-payload:app:server  req-id
        :-  [200 ~[['content-type' 'application/manifest+json']]]
        `(as-octs:mimes:html manifest)
        ::
          [%mail %apple-icon ~]
        ?~  custom-icon-url
          (serve-icon req-id %apple-touch-icon)
        :_  this
        %+  give-simple-payload:app:server  req-id
        :-  [302 ~[['location' u.custom-icon-url] ['cache-control' 'no-cache']]]
        ~
          [%mail %icon-192 ~]         (serve-icon req-id %icon-192)
          [%mail %icon-512 ~]         (serve-icon req-id %icon-512)
          [%mail %apple-touch-icon ~]  (serve-icon req-id %apple-touch-icon)
          [%mail %favicon-32 ~]       (serve-icon req-id %favicon-32)
          [%mail %img %tile ~]        (serve-svg req-id %tile)
        ::
          [%mail %sw ~]
        :_  this
        %+  give-simple-payload:app:server  req-id
        :-  [200 ~[['content-type' 'application/javascript'] ['service-worker-allowed' '/mail']]]
        `(as-octs:mimes:html 'self.addEventListener("install",function(e){self.skipWaiting()});self.addEventListener("activate",function(e){e.waitUntil(self.clients.claim())});self.addEventListener("push",function(e){var d={title:"Notification",body:""};try{d=e.data.json()}catch(x){}e.waitUntil(self.registration.showNotification(d.title,{body:d.body||"",icon:d.icon||"",data:{url:d.url||""}}))});self.addEventListener("notificationclick",function(e){e.notification.close();if(e.notification.data&&e.notification.data.url)e.waitUntil(clients.openWindow(e.notification.data.url))});')
        ::  serve main JS bundle from Clay
        ::
          [%mail %app ~]
        =/  js=@  .^(@ %cx /(scot %p our.bowl)/mail/(scot %da now.bowl)/js/mail/js)
        :_  this
        %+  give-simple-payload:app:server  req-id
        :-  [200 ~[['content-type' 'application/javascript; charset=utf-8'] ['cache-control' 'public, max-age=86400']]]
        `[(met 3 js) js]
        ::
          [%mail %api %avatar ~]
        =/  ship-text  (find-arg args.url 'ship')
        =/  json-resp=@t
          ?~  ship-text  '""'
          =/  ship  (slaw %p u.ship-text)
          ?~  ship  '""'
          ::  scry all contacts (safe — returns map), then lookup ship
          =/  all-contacts=(unit json)
            %-  mole  |.
            .^(json %gx /(scot %p our.bowl)/contacts/(scot %da now.bowl)/all/json)
          ?~  all-contacts  '""'
          ?.  ?=([%o *] u.all-contacts)  '""'
          =/  ship-key=@t  (scot %p u.ship)
          =/  contact  (~(get by p.u.all-contacts) ship-key)
          ?~  contact  '""'
          ?.  ?=([%o *] u.contact)  '""'
          =/  a  (~(get by p.u.contact) 'avatar')
          ?~  a  '""'
          ?.  ?=([%s *] u.a)  '""'
          ?:  =('' p.u.a)  '""'
          (en:json:html s+p.u.a)
        :_  this
        %+  give-simple-payload:app:server  req-id
        :-  [200 ~[['content-type' 'application/json'] ['cache-control' 'public, max-age=3600']]]
        `(as-octs:mimes:html json-resp)
        ::
          [%mail %api %status ~]
        =/  total=@ud  ~(wyt by inbox)
        =/  json=@t
          %+  rap  3
          =/  rec-part=@t
            ?~  recovered-from  ''
            (crip (weld ",\"recovered_from\":\"" (weld (scag 19 (scow %da u.recovered-from)) "\"")))
          :~  '{"unread":'
              (crip (a-co:co unread-count))
              ',"total":'
              (crip (a-co:co total))
              ',"pending_gw":'
              (crip (a-co:co pending-gw-count))
              rec-part
              '}'
          ==
        =/  etag=@t  (crip (weld "\"" (weld (a-co:co (mug json)) "\"")))
        ::  check If-None-Match header for conditional response
        =/  inm=(unit @t)
          =/  hdrs  req-hdrs
          |-
          ?~  hdrs  ~
          ?:  =(key.i.hdrs 'if-none-match')  `value.i.hdrs
          $(hdrs t.hdrs)
        ?:  ?&(?=(^ inm) =(u.inm etag))
          :_  this
          %+  give-simple-payload:app:server  req-id
          [[304 ~] ~]
        :_  this
        %+  give-simple-payload:app:server  req-id
        :-  [200 ~[['content-type' 'application/json'] ['cache-control' 'no-cache'] ['etag' etag]]]
        `(as-octs:mimes:html json)
        ::  payment status for JS polling
        ::
          [%mail %api %payment-status ~]
        ::  trigger gateway to check Etherscan for pending payments
        =/  check-cards=(list card)
          ?~  pending-payment  ~
          ?~  gateway  ~
          :~  [%pass /payment-check %agent [u.gateway %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%check-payments ~])]
          ==
        =/  ps-json=@t
          ?~  pending-payment  '{"status":"none"}'
          %+  rap  3
          :~  '{"status":"waiting","alias":"'
              alias.u.pending-payment
              '","amount":"'
              (crip (wei-to-eth-display:ui amount.u.pending-payment))
              '"}'
          ==
        :_  this
        =/  payload
          %+  give-simple-payload:app:server  req-id
          :-  [200 ~[['content-type' 'application/json'] ['cache-control' 'no-cache']]]
          `(as-octs:mimes:html ps-json)
        (weld check-cards payload)
        ::
          [%mail ~]
        =/  label-filter=(unit @tas)
          =/  lf  (find-arg args.url 'label')
          ?~  lf  ~
          `(crip (trip u.lf))
        =/  search-query=(unit @t)
          =/  sq  (find-arg args.url 'q')
          ?~  sq  ~
          ?:  =('' u.sq)  ~
          sq
        ::  start with full inbox, apply filters
        =/  working=^inbox  inbox
        =?  working  ?=(^ label-filter)
          %-  ~(gas by *^inbox)
          %+  skim  ~(tap by working)
          |=  [id=@uv env=envelope]
          (~(has in labels.env) u.label-filter)
        =?  working  ?=(^ search-query)
          =/  q=tape  (cass (url-decode:mc (trip u.search-query)))
          %-  ~(gas by *^inbox)
          %+  skim  ~(tap by working)
          |=  [id=@uv env=envelope]
          ?|  !=(~ (find q (cass (trip subject.msg.env))))
              !=(~ (find q (cass (format-contact:ui from.msg.env))))
              !=(~ (find q (cass (trip body.msg.env))))
          ==
        ::  first-run: show welcome instead of empty inbox
        ?:  ?&  =(~ working)
                =(~ sent)
                ?=(~ label-filter)
                ?=(~ search-query)
            ==
          =/  gw-st=?(%pending %approved %rejected)
            =/  gw-ship  (fall gateway default-gateway)
            (fall (~(get by gw-status) gw-ship) %pending)
          =/  addr=(unit @t)
            =/  gw-ship  (fall gateway default-gateway)
            =/  dom  (fall (~(get by mail-domains) gw-ship) 'urbitmail.net')
            `(crip "{(slag 1 (scow %p our.bowl))}@{(trip dom)}")
          (give-html req-id (page-layout:ui 'Welcome' %inbox unread-count our.bowl is-gw pending-gw-count (render-welcome:ui our.bowl gw-st addr)))
        (give-html req-id (page-layout:ui 'Inbox' %inbox unread-count our.bowl is-gw pending-gw-count (render-inbox:ui working inbox all-labels label-filter search-query page per-page)))
        ::
          [%mail %sent ~]
        =/  search-query=(unit @t)
          =/  sq  (find-arg args.url 'q')
          ?~  sq  ~
          ?:  =('' u.sq)  ~
          sq
        =/  filtered=^sent
          ?.  ?=(^ search-query)  sent
          =/  q=tape  (cass (url-decode:mc (trip u.search-query)))
          %-  ~(gas by *^sent)
          %+  skim  ~(tap by sent)
          |=  [id=@uv env=envelope]
          ?|  !=(~ (find q (cass (trip subject.msg.env))))
              !=(~ (find q (cass (format-contact:ui to.msg.env))))
              !=(~ (find q (cass (trip body.msg.env))))
          ==
        (give-html req-id (page-layout:ui 'Sent' %sent unread-count our.bowl is-gw pending-gw-count (render-sent:ui filtered search-query page per-page now.bowl)))
        ::
          [%mail %compose ~]
        =/  reply-id  (find-arg args.url 'reply')
        =/  replyall-id  (find-arg args.url 'replyall')
        =/  forward-id  (find-arg args.url 'forward')
        ::  lookup message for reply or forward
        =/  ref-id=(unit @uv)
          ?^  reply-id  (slaw %uv u.reply-id)
          ?^  replyall-id  (slaw %uv u.replyall-id)
          ?^  forward-id  (slaw %uv u.forward-id)
          ~
        =/  env=(unit envelope)
          ?~  ref-id  ~
          ?^  res=(~(get by inbox) u.ref-id)  res
          ?^  res=(~(get by sent) u.ref-id)   res
          (~(get by trash) u.ref-id)
        ?:  &(?=(~ reply-id) ?=(~ replyall-id) ?=(~ forward-id))
          ::  blank compose (with optional ?to=, ?subject=, ?labels= prefill)
          =/  pre-to=tape  (fall (bind (find-arg args.url 'to') trip) "")
          =/  pre-subj=tape  (fall (bind (find-arg args.url 'subject') trip) "")
          =/  pre-labels=(list @tas)
            =/  lab  (find-arg args.url 'labels')
            ?~  lab  ~
            %+  murn  (split-on:mc ',' (trip u.lab))
            |=  t=tape
            =/  trimmed=tape  (trim-spaces:mc t)
            ?:(=(~ trimmed) ~ `(crip trimmed))
          (give-html req-id (page-layout:ui 'Compose' %compose unread-count our.bowl is-gw pending-gw-count (render-compose:ui pre-to pre-subj "" "" pre-labels %new our.bowl mail-domains gateway my-aliases ~)))
        ::  reply, reply-all, or forward — build context from envelope
        =/  mode=?(%reply %replyall %forward)
          ?:  ?=(^ reply-id)     %reply
          ?:  ?=(^ replyall-id)  %replyall
          %forward
        ?~  env
          (give-html req-id (page-layout:ui 'Compose' %compose unread-count our.bowl is-gw pending-gw-count (render-compose:ui "" "" "" "" ~ %new our.bowl mail-domains gateway my-aliases ~)))
        =/  ctx  (build-compose-ctx mode u.env ref-id)
        =/  title=@t
          ?-  mode
            %reply     'Reply'
            %replyall  'Reply All'
            %forward   'Forward'
          ==
        (give-html req-id (page-layout:ui title %compose unread-count our.bowl is-gw pending-gw-count (render-compose:ui to.ctx subj.ctx body.ctx cc.ctx labels.ctx mode our.bowl doms.ctx gw.ctx my-aliases alias.ctx)))
        ::
          [%mail %settings ~]
        =/  settings-msg=(unit @t)  (find-arg args.url 'msg')
        (give-html req-id (page-layout:ui 'Settings' %settings unread-count our.bowl is-gw pending-gw-count (render-settings:ui-set our.bowl gateway gateways mail-domains gw-status fwd-rules registry-gateways registry my-aliases pending-payment settings-msg is-gw gw-alias-cfg custom-icon-url)))
        ::
          [%mail %donate ~]
        (give-html req-id (page-layout:ui 'Donate' %donate unread-count our.bowl is-gw pending-gw-count render-donate:ui-set))
        ::
          [%mail %help ~]
        (give-html req-id (page-layout:ui 'Help' %help unread-count our.bowl is-gw pending-gw-count render-help:ui-set))
        ::
          [%mail %backup ~]
        =/  inbox-count=@ud  ~(wyt by inbox)
        =/  sent-count=@ud  ~(wyt by sent)
        =/  trash-count=@ud  ~(wyt by trash)
        =/  auto-backup-time=@da
          =/  t  (mole |.(.^(@da %gx /(scot %p our.bowl)/mail-recovery/(scot %da now.bowl)/updated/noun)))
          (fall t *@da)
        (give-html req-id (page-layout:ui 'Backup' %backup unread-count our.bowl is-gw pending-gw-count (render-backup:ui-set inbox-count sent-count trash-count auto-backup-time backup-interval)))
        ::
          [%mail %buy-alias ~]
        =/  pending-alias=(unit @t)  (find-arg args.url 'pending')
        ::  redirect to settings if no pending payment and no waiting state
        ?:  ?&(?=(~ pending-payment) ?=(~ pending-alias))
          (give-redirect req-id '/mail/settings#s-aliases')
        (give-html req-id (page-layout:ui 'Buy Alias' %buy-alias unread-count our.bowl is-gw pending-gw-count (render-buy-alias:ui-gw gateways mail-domains gateway pending-payment ~ pending-alias)))
        ::
          [%mail %gateway ~]
        ?.  is-gw
          ::  gateway not enabled — show info page
          =/  gw-domain  (fall (mole |.(.^(@t %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/domain/noun))) '')
          =/  msg=(unit @t)  (find-arg args.url 'msg')
          (give-html req-id (page-layout:ui 'Gateway' %gateway unread-count our.bowl is-gw pending-gw-count (render-gateway-info:ui-gw gw-domain msg our.bowl)))
        =/  wl  (fall (mole |.(.^((map @p wl-entry) %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/whitelist/noun))) *(map @p wl-entry))
        =/  aa  (fall (mole |.(.^(? %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/auto-approve/noun))) %.n)
        =/  gw-domain  (fall (mole |.(.^(@t %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/domain/noun))) '')
        =/  gw-filter=(unit @tas)
          =/  f  (find-arg args.url 'filter')
          ?~  f  ~
          ?:  =('' u.f)  ~
          `(crip (trip u.f))
        =/  gw-search=(unit @t)
          =/  q  (find-arg args.url 'q')
          ?~  q  ~
          ?:(=('' u.q) ~ q)
        =/  out-today=@ud  (fall (mole |.(.^(@ud %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/out-today/noun))) 0)
        =/  out-month=@ud  (fall (mole |.(.^(@ud %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/out-month/noun))) 0)
        =/  gw-public=?  (fall (mole |.(.^(? %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/public/noun))) %.n)
        =/  gw-acfg=alias-cfg  (fall (mole |.(.^(alias-cfg %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/alias-config/noun))) *alias-cfg)
        =/  gw-aliases=(map @t alias-entry)  (fall (mole |.(.^((map @t alias-entry) %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/aliases/noun))) *(map @t alias-entry))
        =/  inv=(unit @t)  (find-arg args.url 'invite')
        =/  alias-filter=(unit @tas)
          =/  f  (find-arg args.url 'af')
          ?~  f  ~
          ?:(=('' u.f) ~ `(crip (trip u.f)))
        =/  alias-search=(unit @t)
          =/  q  (find-arg args.url 'aq')
          ?~  q  ~
          ?:(=('' u.q) ~ q)
        =/  alias-page=@ud
          =/  p  (find-arg args.url 'ap')
          ?~  p  1
          (max 1 (fall (slaw %ud u.p) 1))
        =/  gw-payments  (fall (mole |.(.^((map @t [alias=@t ship=@p amount=@ud created=@da]) %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/pending-payments/noun))) *(map @t [alias=@t ship=@p amount=@ud created=@da]))
        (give-html req-id (page-layout:ui 'Gateway' %gateway unread-count our.bowl is-gw pending-gw-count (render-gateway-admin:ui-gw wl aa gw-domain page per-page gw-filter gw-search out-today out-month gw-public gw-acfg gw-aliases inv alias-filter alias-search alias-page gw-payments)))
        ::
          [%mail %read ~]
        =/  id-text  (find-arg args.url 'id')
        ?~  id-text  (give-404 req-id)
        =/  id-parsed=(unit @uv)  (slaw %uv u.id-text)
        ?~  id-parsed  (give-error req-id "Invalid message ID")
        =/  id=@uv  u.id-parsed
        =/  env=(unit envelope)
          ?^  res=(~(get by inbox) id)  res
          ?^  res=(~(get by sent) id)   res
          (~(get by trash) id)
        ?~  env  (give-404 req-id)
        ::  auto mark-read if unread inbox message
        =?  inbox  ?&((~(has by inbox) id) =(status.u.env %unread))
          (~(put by inbox) id u.env(status %read))
        =?  env  =(status.u.env %unread)
          `u.env(status %read)
        (give-html req-id (page-layout:ui 'Message' %read unread-count our.bowl is-gw pending-gw-count (render-message:ui u.env)))
      ==
    ::  gw-from-addr: reverse-lookup gateway from recv-addr domain
    ::
    ++  gw-from-addr
      |=  addr=@t
      ^-  (unit @p)
      ?:  =('' addr)  ~
      =/  atxt=tape  (trip addr)
      =/  at-pos=(unit @ud)
        =/  i=@ud  0
        |-
        ?:  (gte i (lent atxt))  ~
        ?:  =('@' (snag i atxt))  `i
        $(i +(i))
      ?~  at-pos  ~
      =/  dom=tape  (slag +(u.at-pos) atxt)
      =/  dom-cord=@t  (crip dom)
      =/  doms=(list [gw=@p d=@t])  ~(tap by mail-domains)
      |-
      ?~  doms  ~
      ?:  =(dom-cord d.i.doms)
        `gw.i.doms
      $(doms t.doms)
    ::  alias-from-addr: extract alias from recv-addr if not our ship name
    ::
    ++  alias-from-addr
      |=  [addr=@t our=@p]
      ^-  (unit @t)
      ?:  =('' addr)  ~
      =/  atxt=tape  (trip addr)
      =/  at-pos=(unit @ud)
        =/  i=@ud  0
        |-
        ?:  (gte i (lent atxt))  ~
        ?:  =('@' (snag i atxt))  `i
        $(i +(i))
      ?~  at-pos  ~
      =/  local=tape  (scag u.at-pos atxt)
      =/  ship-name=tape  (slag 1 (scow %p our))
      ?:  =(local ship-name)  ~
      `(crip local)
    ::  build-compose-ctx: build pre-filled context for reply/replyall/forward
    ::
    ++  build-compose-ctx
      |=  [mode=?(%reply %replyall %forward) env=envelope ref-id=(unit @uv)]
      ^-  [to=tape subj=tape body=tape cc=tape labels=(list @tas) gw=(unit @p) alias=(unit @t) doms=(map @p @t)]
      ::  shared: labels from addr-labels or envelope
      =/  ctx-labels=(list @tas)
        ?~  ref-id  ~(tap in labels.env)
        =/  al  (~(get by addr-labels) u.ref-id)
        ?^(al u.al ~(tap in labels.env))
      ::  shared: gateway and alias from recv-addr
      =/  ctx-gw=(unit @p)
        =/  addr-gw  (gw-from-addr recv-addr.env)
        ?:  ?=(%forward mode)  addr-gw
        ?^(addr-gw addr-gw gateway)
      =/  ctx-alias=(unit @t)
        ?:  ?=(%forward mode)  ~
        (alias-from-addr recv-addr.env our.bowl)
      ::  shared: augment mail-domains with recv-addr domain
      =/  ctx-doms=(map @p @t)
        ?~  ctx-gw  mail-domains
        ?^  (~(get by mail-domains) u.ctx-gw)  mail-domains
        =/  atxt=tape  (trip recv-addr.env)
        =/  at-pos  (find "@" atxt)
        ?~  at-pos  mail-domains
        =/  dom=@t  (crip (slag +(u.at-pos) atxt))
        ?:(=('' dom) mail-domains (~(put by mail-domains) u.ctx-gw dom))
      ::  mode-specific: to, subject, body, cc
      ::  reply-target: if replying to own sent message, use original recipient
      =/  reply-target=contact
        ?:  =(%sent folder.env)
          to.msg.env
        ?~(reply-to.msg.env from.msg.env u.reply-to.msg.env)
      ?-  mode
          %reply
        =/  to=tape  (format-contact:ui reply-target)
        =/  subj=tape
          =/  s=tape  (trip subject.msg.env)
          ?:  =("Re: " (scag 4 s))  s
          (weld "Re: " s)
        =/  body=tape  (weld "\0a\0a---\0a" (trip body.msg.env))
        [to subj body "" ctx-labels ctx-gw ctx-alias ctx-doms]
          %replyall
        =/  to=tape  (format-contact:ui reply-target)
        =/  subj=tape
          =/  s=tape  (trip subject.msg.env)
          ?:  =("Re: " (scag 4 s))  s
          (weld "Re: " s)
        =/  body=tape  (weld "\0a\0a---\0a" (trip body.msg.env))
        =/  our-contact=contact  [%urbit our.bowl]
        =/  cc-list=(list contact)
          %+  skip
            (weld cc.msg.env ~[to.msg.env])
          |=(c=contact =(c our-contact))
        [to subj body (join-contacts:ui cc-list) ctx-labels ctx-gw ctx-alias ctx-doms]
          %forward
        =/  subj=tape
          =/  s=tape  (trip subject.msg.env)
          ?:  =("Fwd: " (scag 5 s))  s
          (weld "Fwd: " s)
        =/  body=tape
          ;:  weld
            "\0a\0a---------- Forwarded message ----------\0a"
            "From: {(format-contact:ui from.msg.env)}\0a"
            "To: {(format-contact:ui to.msg.env)}\0a"
            ?:  =(~ cc.msg.env)  ""
            "CC: {(join-contacts:ui cc.msg.env)}\0a"
            "Date: {(format-date:ui sent-at.msg.env)}\0a"
            "Subject: {(trip subject.msg.env)}\0a\0a"
            (trip body.msg.env)
          ==
        ["" subj body "" ctx-labels ctx-gw ~ ctx-doms]
      ==
    ::
    ++  handle-gw-post
      |=  [sub-path=(list @t) form=(map @t @t) req-id=@ta]
      ^-  (quip card _this)
      |^
      ::  enable and set-domain allowed before gateway is active
      ?:  ?=([%enable ~] sub-path)
        ?:  (is-comet:mc our.bowl)
          (give-error req-id "Comets cannot run a gateway")
        =/  val=?  =('on' (fall (~(get by form) 'enabled') ''))
        (gw-poke-redirect [%set-enabled val] ?:(val '/mail/gateway?msg=verifying' '/mail/gateway'))
      ?:  ?=([%set-domain ~] sub-path)
        =/  dom-val=(unit @t)  (~(get by form) 'domain')
        ?~  dom-val  (give-error req-id "Missing required field: domain")
        =/  dom=@t  (crip (trip u.dom-val))
        (gw-poke-redirect [%set-domain dom] '/mail/gateway?msg=verifying')
      ?.  is-gw  (give-error req-id "Gateway not enabled")
      ?+  sub-path  (give-405 req-id)
        ::  add ship to whitelist
        ::
          [%add ~]
        =/  ship-val=(unit @t)  (~(get by form) 'ship')
        ?~  ship-val  (give-error req-id "Missing required field: ship")
        =/  ship=(unit @p)  (slaw %p u.ship-val)
        ?~  ship  (give-error req-id "Invalid ship name")
        (gw-poke-redirect [%add-to-whitelist u.ship] '/mail/gateway')
        ::  approve access
        ::
          [%approve ~]
        =/  ship-val=(unit @t)  (~(get by form) 'ship')
        ?~  ship-val  (give-error req-id "Missing required field: ship")
        =/  ship=(unit @p)  (slaw %p u.ship-val)
        ?~  ship  (give-error req-id "Invalid ship name")
        (gw-poke-redirect [%approve-access u.ship] '/mail/gateway')
        ::  reject access
        ::
          [%reject ~]
        =/  ship-val=(unit @t)  (~(get by form) 'ship')
        ?~  ship-val  (give-error req-id "Missing required field: ship")
        =/  ship=(unit @p)  (slaw %p u.ship-val)
        ?~  ship  (give-error req-id "Invalid ship name")
        (gw-poke-redirect [%reject-access u.ship] '/mail/gateway')
        ::  remove access
        ::
          [%remove ~]
        =/  ship-val=(unit @t)  (~(get by form) 'ship')
        ?~  ship-val  (give-error req-id "Missing required field: ship")
        =/  ship=(unit @p)  (slaw %p u.ship-val)
        ?~  ship  (give-error req-id "Invalid ship name")
        (gw-poke-redirect [%remove-access u.ship] '/mail/gateway')
        ::  toggle auto-approve
        ::
          [%auto-approve ~]
        =/  val=?  =('on' (fall (~(get by form) 'auto') ''))
        (gw-poke-redirect [%set-auto-approve val] '/mail/gateway')
        ::  approve all pending
        ::
          [%approve-all ~]
        =/  wl=(map @p wl-entry)  (fall (mole |.(.^((map @p wl-entry) %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/whitelist/noun))) *(map @p wl-entry))
        =/  pending-ships=(list @p)
          %+  murn  ~(tap by wl)
          |=  [s=@p e=wl-entry]
          ?.  =(%pending status.e)  ~
          `s
        =/  cards=(list card)
          %+  turn  pending-ships
          |=  s=@p
          [%pass /gw-admin %agent [our.bowl %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%approve-access s])]
        =/  redir  (give-redirect req-id '/mail/gateway')
        [(weld cards -.redir) +.redir]
        ::  toggle public/private
        ::
          [%set-public ~]
        =/  val=?  =('on' (fall (~(get by form) 'public') ''))
        (gw-poke-redirect [%set-public val] '/mail/gateway')
        ::  toggle aliases
        ::
          [%set-aliases-enabled ~]
        =/  val=?  =('on' (fall (~(get by form) 'enabled') ''))
        =/  cur-cfg=alias-cfg  (fall (mole |.(.^(alias-cfg %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/alias-config/noun))) *alias-cfg)
        (gw-poke-redirect [%set-alias-config cur-cfg(aliases-enabled val)] '/mail/gateway#aliases')
        ::  set alias config (rules)
        ::
          [%set-alias-config ~]
        =/  cur-cfg=alias-cfg  (fall (mole |.(.^(alias-cfg %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/alias-config/noun))) *alias-cfg)
        =/  ml-val=(unit @t)  (~(get by form) 'min-len')
        ?~  ml-val  (give-error req-id "Missing required field: min-len")
        =/  ml=(unit @ud)  (slaw %ud u.ml-val)
        ?~  ml  (give-error req-id "Invalid number for min-len")
        =/  fml-val=(unit @t)  (~(get by form) 'free-min-len')
        ?~  fml-val  (give-error req-id "Missing required field: free-min-len")
        =/  fml=(unit @ud)  (slaw %ud u.fml-val)
        ?~  fml  (give-error req-id "Invalid number for free-min-len")
        =/  fl-val=(unit @t)  (~(get by form) 'free-limit')
        ?~  fl-val  (give-error req-id "Missing required field: free-limit")
        =/  fl=(unit @ud)  (slaw %ud u.fl-val)
        ?~  fl  (give-error req-id "Invalid number for free-limit")
        =/  new-cfg=alias-cfg  [aliases-enabled.cur-cfg u.ml u.fml u.fl payment-enabled.cur-cfg payment-wallet.cur-cfg base-price.cur-cfg etherscan-key.cur-cfg]
        (gw-poke-redirect [%set-alias-config new-cfg] '/mail/gateway#aliases')
        ::  toggle payment enabled (keeps all other config from scry)
        ::
          [%toggle-payments ~]
        =/  cur-cfg=alias-cfg  (fall (mole |.(.^(alias-cfg %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/alias-config/noun))) *alias-cfg)
        =/  new-ena=?  !payment-enabled.cur-cfg
        ?:  ?&(new-ena |(=('' payment-wallet.cur-cfg) =('' etherscan-key.cur-cfg)))
          (give-error req-id "Fill in wallet address and API key before enabling payments")
        (gw-poke-redirect [%set-alias-config cur-cfg(payment-enabled new-ena)] '/mail/gateway#aliases')
        ::  set payment config
        ::
          [%set-payment-config ~]
        =/  wallet-val=(unit @t)  (~(get by form) 'wallet')
        ?~  wallet-val  (give-error req-id "Missing required field: wallet")
        =/  price-val=@t  (fall (~(get by form) 'price') '0')
        =/  price-wei=@ud  (fall (rust (trip price-val) dem) 0)
        =/  key-val=(unit @t)  (~(get by form) 'key')
        ?~  key-val  (give-error req-id "Missing required field: key")
        =/  cur-cfg=alias-cfg  (fall (mole |.(.^(alias-cfg %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/alias-config/noun))) *alias-cfg)
        (gw-poke-redirect [%set-payment-config u.wallet-val price-wei u.key-val payment-enabled.cur-cfg] '/mail/gateway#aliases')
        ::  block alias
        ::
          [%block-alias ~]
        =/  alias-val=(unit @t)  (~(get by form) 'alias')
        ?~  alias-val  (give-error req-id "Missing required field: alias")
        (gw-poke-redirect [%block-alias u.alias-val] '/mail/gateway#aliases')
        ::  unreserve alias
        ::
          [%unreserve-alias ~]
        =/  alias-val=(unit @t)  (~(get by form) 'alias')
        ?~  alias-val  (give-error req-id "Missing required field: alias")
        (gw-poke-redirect [%unreserve-alias u.alias-val] '/mail/gateway#aliases')
        ::  unblock alias
        ::
          [%unblock-alias ~]
        =/  alias-val=(unit @t)  (~(get by form) 'alias')
        ?~  alias-val  (give-error req-id "Missing required field: alias")
        (gw-poke-redirect [%unblock-alias u.alias-val] '/mail/gateway#aliases')
        ::  generate invite code
        ::
          [%generate-invite ~]
        =/  alias-val=(unit @t)  (~(get by form) 'alias')
        ?~  alias-val  (give-error req-id "Missing required field: alias")
        =/  alias=@t  (crip (cass (trip u.alias-val)))
        ::  validate alias format
        =/  chars=tape  (trip alias)
        ?:  =(~ chars)
          (give-redirect req-id '/mail/gateway?invite=error:Invalid+alias+format#aliases')
        ::  check first char: must be a-z or 0-9
        ?.  ?|  &((gte (snag 0 chars) 'a') (lte (snag 0 chars) 'z'))
                &((gte (snag 0 chars) '0') (lte (snag 0 chars) '9'))
            ==
          (give-redirect req-id '/mail/gateway?invite=error:Alias+must+start+with+a+letter+or+digit#aliases')
        ::  check all chars: a-z, 0-9, hyphen, underscore only
        ?.  %+  levy  chars
            |=  c=@t
            ?|  &((gte c 'a') (lte c 'z'))
                &((gte c '0') (lte c '9'))
                =(c '-')
                =(c '_')
            ==
          (give-redirect req-id '/mail/gateway?invite=error:Only+a-z,+0-9,+hyphen,+underscore+allowed.+No+dots.#aliases')
        =/  clen=@ud  (lent chars)
        =/  with-sig=@t  (crip (weld "~" chars))
        ?:  ?&  ?|  =(3 clen)
                    =(6 clen)
                    =(13 clen)
                    =(27 clen)
                ==
                ?=(^ (slaw %p with-sig))
            ==
          (give-redirect req-id '/mail/gateway?invite=error:This+alias+matches+a+ship+name#aliases')
        ::  poke gateway to reserve alias + generate code locally
        =/  poke-card=card
          [%pass /gw-admin %agent [our.bowl %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%generate-invite alias])]
        ::  generate code locally for display
        =/  secret=@  .^(@ %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/invite-secret/noun)
        =?  secret  =(0 secret)
          `@`(sham [eny.bowl now.bowl our.bowl])
        =/  alias-len=@ud  (met 3 alias)
        =/  sig=@  (extract:hkdf [32 secret] [alias-len `@`alias])
        =/  sig-b64=@t  (~(en base64:mimes:html | &) [32 sig])
        =/  code=@t
          %-  crip
          ;:  weld
            (trip alias)
            "@"
            (scow %p our.bowl)
            ":"
            (trip sig-b64)
          ==
        =/  redir  (give-redirect req-id (crip (weld "/mail/gateway?invite=" (weld (url-encode:mc (trip code)) "#aliases"))))
        [(weld ~[poke-card] -.redir) +.redir]
      ==
      ::  gw-poke-redirect: poke gateway with action and redirect
      ::
      ++  gw-poke-redirect
        |=  [act=gateway-action redir-url=@t]
        ^-  (quip card _this)
        =/  poke-card=card
          [%pass /gw-admin %agent [our.bowl %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`act)]
        =/  redir  (give-redirect req-id redir-url)
        [(weld ~[poke-card] -.redir) +.redir]
      --
    ::
    ++  handle-post
      |=  [req-id=@ta url=request-line:server bod=(unit octs)]
      ^-  (quip card _this)
      =/  form=(map @t @t)  (parse-form-body:mc bod)
      ?+  site.url  (give-404 req-id)
        ::  set custom icon URL
        ::
          [%mail %set-icon ~]
        =/  url-val=(unit @t)  (~(get by form) 'url')
        ?~  url-val  (give-error req-id "Missing URL")
        =/  url=@t  u.url-val
        ?:  =('' url)
          =.  custom-icon-url  ~
          (give-redirect req-id '/mail/settings')
        =/  url-tape=tape  (trip url)
        ?.  ?|  =("https://" (scag 8 url-tape))
                =("http://" (scag 7 url-tape))
            ==
          (give-error req-id "URL must start with http:// or https://")
        ?:  ?|  !=(~ (find "\"" url-tape))
                !=(~ (find "<" url-tape))
                !=(~ (find ">" url-tape))
                !=(~ (find "\0a" url-tape))
                !=(~ (find "\0d" url-tape))
            ==
          (give-error req-id "URL contains invalid characters")
        =.  custom-icon-url  `url
        (give-redirect req-id '/mail/settings')
        ::  remove custom icon
        ::
          [%mail %remove-icon ~]
        =.  custom-icon-url  ~
        (give-redirect req-id '/mail/settings')
        ::  resend a failed message
        ::
          [%mail %resend ~]
        =/  id-val=(unit @t)  (~(get by form) 'id')
        ?~  id-val  (give-error req-id "Missing message ID")
        =/  id=(unit @uv)  (slaw %uv u.id-val)
        ?~  id  (give-error req-id "Invalid message ID")
        =/  env  (~(get by sent) u.id)
        ?~  env  (give-error req-id "Message not found in sent")
        =/  msg  msg.u.env
        ::  create new send with same content
        =/  new-id=@uv  (sham [now.bowl eny.bowl %resend u.id])
        =/  new-msg=message  msg(id new-id, sent-at now.bowl)
        =/  new-env=envelope  [new-msg %sending %sent labels.u.env recv-addr.u.env]
        =.  sent  (~(put by sent) new-id new-env)
        =/  upd-card=card  [%give %fact ~[/updates] %mail-update !>([%sent new-env])]
        =/  timeout-card=card  [%pass /send-timeout/(scot %uv new-id) %arvo %b %wait (add now.bowl ~m5)]
        ?:  ?&(?=([%ext *] to.msg) ?=(~ gateway))
          (give-error req-id "No gateway configured")
        =/  send-labels=(list @tas)  ~(tap in labels.u.env)
        =/  send-card=card
          ?:  ?=([%urbit *] to.msg)
            ?:  =(~ send-labels)
              [%pass /send/(scot %uv new-id) %agent [p.to.msg %mail-client] %poke %mail-message !>(new-msg)]
            [%pass /send/(scot %uv new-id) %agent [p.to.msg %mail-client] %poke %mail-action !>(`action`[%receive-labeled new-msg (silt send-labels) ''])]
          ?:  =(~ send-labels)
            [%pass /send/(scot %uv new-id) %agent [(need gateway) %mail-gateway] %poke %mail-message !>(new-msg)]
          [%pass /send/(scot %uv new-id) %agent [(need gateway) %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%send-labeled new-msg send-labels])]
        =/  redir  (give-redirect req-id '/mail/sent')
        [(weld ~[send-card upd-card timeout-card] -.redir) +.redir]
        ::  send a new message
        ::
          [%mail %send ~]
        ::  block comets from sending (128-bit @p = comet)
        ?:  (is-comet:mc our.bowl)
          (give-html req-id (page-layout:ui 'Error' %error unread-count our.bowl is-gw pending-gw-count (render-error:ui "Comets cannot send mail" "Only planets, stars, and galaxies can send messages. Comets can receive mail only.")))
        =/  to-val=(unit @t)  (~(get by form) 'to')
        ?~  to-val  (give-error req-id "Missing required field: to")
        =/  to-text=@t  u.to-val
        =/  to-tape=tape  (trip to-text)
        =/  is-ship=?
          ?&  (gth (lent to-tape) 0)
              =('~' (snag 0 to-tape))
          ==
        ?:  ?&  is-ship
                =(~ (slaw %p to-text))
            ==
          (give-error req-id "Invalid ship name in 'to' field")
        ?:  ?&  !is-ship
                !(is-valid-email:mc to-text)
            ==
          (give-error req-id "Invalid email address in 'to' field")
        =/  to=contact
          ?:  is-ship
            [%urbit (need (slaw %p to-text))]
          [%ext to-text]
        =/  cc-text=@t   (fall (~(get by form) 'cc') '')
        =/  bcc-text=@t  (fall (~(get by form) 'bcc') '')
        =/  cc=(list contact)   (parse-contacts:mc cc-text)
        =/  bcc=(list contact)  (parse-contacts:mc bcc-text)
        =/  subj-val=(unit @t)  (~(get by form) 'subject')
        ?~  subj-val  (give-error req-id "Missing required field: subject")
        =/  subj=@t  u.subj-val
        =/  hidden-labels=(list @tas)
          %+  turn  (parse-form-all:mc bod 'labels')
          |=(t=@t `@tas`(crip (trip t)))
        =/  text-labels=(list @tas)
          =/  lt  (fall (~(get by form) 'labels-text') '')
          ?:  =('' lt)  ~
          %+  murn  (split-on:mc ',' (trip lt))
          |=  t=tape
          =/  trimmed=tape  (trim-spaces:mc t)
          ?:(=(~ trimmed) ~ `(crip trimmed))
        =/  labels=(list @tas)  (weld hidden-labels text-labels)
        =/  bod-val=(unit @t)  (~(get by form) 'body')
        ?~  bod-val  (give-error req-id "Missing required field: body")
        =/  bod=@t  u.bod-val
        =/  all-recips=(list contact)  (weld ~[to] (weld cc bcc))
        ::  determine which gateway to use: form selection > default gateway
        =/  from-val=tape  (trip (fall (~(get by form) 'from-gateway') ''))
        =/  from-parts=(list tape)  (split-on:mc ' ' from-val)
        =/  sel-gw=(unit @p)
          ?~  from-parts  gateway
          ?:  =(~ i.from-parts)  gateway
          =/  parsed-gw=(unit @p)  (slaw %p (crip i.from-parts))
          ?~  parsed-gw  gateway
          parsed-gw
        =/  from-alias=(unit @t)
          ?:  (lth (lent from-parts) 2)  ~
          =/  alias-part=tape  (snag 1 from-parts)
          ?:(=(~ alias-part) ~ `(crip alias-part))
        ::  check if any external recipient exists without gateway
        =/  has-ext=?
          %+  lien  all-recips
          |=(c=contact ?=([%ext *] c))
        ?:  &(has-ext ?=(~ sel-gw))
          (give-html req-id (page-layout:ui 'Error' %error unread-count our.bowl is-gw pending-gw-count (render-error:ui "Gateway not configured" "To send email to external addresses, configure a gateway ship in Settings.")))
        ::  check if gateway has approved our access
        =/  send-blocked=(unit tape)
          ?.  has-ext  ~
          =/  gw-st  (~(get by gw-status) (need sel-gw))
          ?~  gw-st
            `"Gateway access not requested. Add gateway in Settings first."
          ?:  ?=(%approved u.gw-st)  ~
          ?:  ?=(%pending u.gw-st)
            `"Your access request to gateway {(scow %p (need sel-gw))} is still pending approval."
          `"Gateway {(scow %p (need sel-gw))} rejected your access request."
        ?^  send-blocked
          (give-html req-id (page-layout:ui 'Error' %error unread-count our.bowl is-gw pending-gw-count (render-error:ui "Gateway access denied" u.send-blocked)))
        ::  convert urbit @p to email — only for CC when recipient is external
        =/  gw-domain=(unit @t)
          ?~  sel-gw  ~
          (~(get by mail-domains) u.sel-gw)
        =/  p-to-email
          |=  c=contact
          ^-  contact
          ?:  ?=([%ext *] c)  c
          ?~  gw-domain  c
          =/  ship-name=tape  (slag 1 (scow %p p.c))
          [%ext (crip (weld ship-name (weld "@" (trip u.gw-domain))))]
        ::  send to each recipient: to=them, cc=visible minus them
        =/  sent-id=@uv  `@uv`(sham [now.bowl eny.bowl])
        =/  send-cards=(list card)  ~
        =/  recips  all-recips
        =/  idx=@ud  0
        |-
        ?~  recips
          ::  store one copy in sent with original to and cc
          =/  sent-msg=message  [sent-id [%urbit our.bowl] to cc ~ subj bod now.bowl ~]
          =/  all-labels=(list @tas)
            ?~  from-alias  labels
            (weld labels ~[`@tas`(crip (weld "sendas:" (trip u.from-alias)))])
          =/  send-addr=@t
            ?~  sel-gw  ''
            =/  dom  (~(get by mail-domains) u.sel-gw)
            ?~  dom  ''
            =/  local=tape
              ?~  from-alias  (slag 1 (scow %p our.bowl))
              (trip u.from-alias)
            (crip (weld local (weld "@" (trip u.dom))))
          =/  env=envelope  [sent-msg %sending %sent (silt all-labels) send-addr]
          =/  upd-card=card
            [%give %fact ~[/updates] %mail-update !>([%sent env])]
          =/  timeout-card=card
            [%pass /send-timeout/(scot %uv sent-id) %arvo %b %wait (add now.bowl ~m5)]
          =.  sent  (~(put by sent) sent-id env)
          =/  redir  (give-redirect req-id '/mail/sent')
          [(weld (weld send-cards ~[upd-card timeout-card]) -.redir) +.redir]
        =/  recip  i.recips
        ::  build cc for this recipient's message
        ::  convert @p to email in cc only when this recip is external
        =/  is-ext  ?=([%ext *] recip)
        =/  visible=(list contact)  (weld ~[to] cc)
        =/  recip-cc=(list contact)
          =/  others  (skip visible |=(c=contact =(c recip)))
          ?:  is-ext  (turn others p-to-email)
          others
        =/  recip-to=contact
          ?:  is-ext  (p-to-email recip)
          recip
        =/  id=@uv  ?:(=(0 idx) sent-id `@uv`(sham [now.bowl eny.bowl idx]))
        =/  msg=message  [id [%urbit our.bowl] recip-to recip-cc ~ subj bod now.bowl ~]
        ::  add alias to labels if sending from alias
        =/  send-labels=(list @tas)
          ?~  from-alias  labels
          (weld labels ~[`@tas`(crip (weld "sendas:" (trip u.from-alias)))])
        ::  use sent-id on wire so on-agent can find the envelope in sent map
        =/  target-card=card
          ?-  -.recip
              %urbit
            ?:  =(~ send-labels)
              [%pass /send/(scot %uv sent-id) %agent [p.recip %mail-client] %poke %mail-message !>(msg)]
            [%pass /send/(scot %uv sent-id) %agent [p.recip %mail-client] %poke %mail-action !>(`action`[%receive-labeled msg (silt send-labels) ''])]
              %ext
            ?:  =(~ send-labels)
              [%pass /send/(scot %uv sent-id) %agent [(need sel-gw) %mail-gateway] %poke %mail-message !>(msg)]
            [%pass /send/(scot %uv sent-id) %agent [(need sel-gw) %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%send-labeled msg send-labels])]
          ==
        $(recips t.recips, idx +(idx), send-cards (snoc send-cards target-card))
        ::  mark message as read
        ::
          [%mail %mark-read ~]
        =/  id-val=(unit @t)  (~(get by form) 'id')
        ?~  id-val  (give-error req-id "Missing required field: id")
        =/  id=(unit @uv)  (slaw %uv u.id-val)
        ?~  id  (give-error req-id "Invalid message ID")
        %^    update-env  req-id  u.id
        :+  |=(e=envelope e(status %read))
          |=(e=envelope [%status-change id.msg.e %read])
        (crip "/mail/read?id={(trip (scot %uv u.id))}")
        ::  mark message as unread
        ::
          [%mail %mark-unread ~]
        =/  id-val=(unit @t)  (~(get by form) 'id')
        ?~  id-val  (give-error req-id "Missing required field: id")
        =/  id=(unit @uv)  (slaw %uv u.id-val)
        ?~  id  (give-error req-id "Invalid message ID")
        %^    update-env  req-id  u.id
        :+  |=(e=envelope e(status %unread))
          |=(e=envelope [%status-change id.msg.e %unread])
        '/mail'
        ::  save settings (outbound gateway)
        ::
          [%mail %settings ~]
        =/  gw-text=@t  (fall (~(get by form) 'gateway') '')
        ?:  =('' gw-text)
          =.  gateway  ~
          (give-redirect req-id '/mail/settings')
        =/  gw-parsed=(unit @p)  (slaw %p gw-text)
        ?~  gw-parsed  (give-error req-id "Invalid gateway ship name")
        =/  gw=@p  u.gw-parsed
        =.  gateway  `gw
        =.  gateways  (~(put in gateways) gw)
        ~&  >  '%mail: gateway set to {<gw>}'
        =/  sub-card=card
          [%pass /gateway-info/(scot %p gw) %agent [gw %mail-gateway] %watch /info]
        =/  redir  (give-redirect req-id '/mail/settings')
        [(weld ~[sub-card] -.redir) +.redir]
        ::  delete message
        ::
          [%mail %delete ~]
        =/  id-val=(unit @t)  (~(get by form) 'id')
        ?~  id-val  (give-error req-id "Missing required field: id")
        =/  id-parsed=(unit @uv)  (slaw %uv u.id-val)
        ?~  id-parsed  (give-error req-id "Invalid message ID")
        =/  id=@uv  u.id-parsed
        ?:  (~(has by inbox) id)
          =/  env=envelope  (~(got by inbox) id)
          =/  trashed=envelope  env(folder %trash)
          =/  upd-card=card
            [%give %fact ~[/updates] %mail-update !>([%deleted id])]
          =.  inbox  (~(del by inbox) id)
          =.  trash  (~(put by trash) id trashed)
          =.  addr-labels  (~(del by addr-labels) id)
          =/  redir  (give-redirect req-id '/mail')
          [(weld ~[upd-card] -.redir) +.redir]
        ?:  (~(has by sent) id)
          =/  env=envelope  (~(got by sent) id)
          =/  trashed=envelope  env(folder %trash)
          =/  upd-card=card
            [%give %fact ~[/updates] %mail-update !>([%deleted id])]
          =.  sent  (~(del by sent) id)
          =.  trash  (~(put by trash) id trashed)
          =.  addr-labels  (~(del by addr-labels) id)
          =/  redir  (give-redirect req-id '/mail/sent')
          [(weld ~[upd-card] -.redir) +.redir]
        (give-error req-id "Message not found")
        ::  add label to message
        ::
          [%mail %add-label ~]
        =/  id-val=(unit @t)  (~(get by form) 'id')
        ?~  id-val  (give-error req-id "Missing required field: id")
        =/  id=(unit @uv)  (slaw %uv u.id-val)
        ?~  id  (give-error req-id "Invalid message ID")
        =/  label-val=(unit @t)  (~(get by form) 'label')
        ?~  label-val  (give-error req-id "Missing required field: label")
        =/  label=@tas  (crip (trip u.label-val))
        %^    update-env  req-id  u.id
        :+  |=(e=envelope e(labels (~(put in labels.e) label)))
          |=(e=envelope [%labels-changed id.msg.e labels.e])
        (crip "/mail/read?id={(trip (scot %uv u.id))}")
        ::  remove label from message
        ::
          [%mail %remove-label ~]
        =/  id-val=(unit @t)  (~(get by form) 'id')
        ?~  id-val  (give-error req-id "Missing required field: id")
        =/  id=(unit @uv)  (slaw %uv u.id-val)
        ?~  id  (give-error req-id "Invalid message ID")
        =/  label-val=(unit @t)  (~(get by form) 'label')
        ?~  label-val  (give-error req-id "Missing required field: label")
        =/  label=@tas  (crip (trip u.label-val))
        %^    update-env  req-id  u.id
        :+  |=(e=envelope e(labels (~(del in labels.e) label)))
          |=(e=envelope [%labels-changed id.msg.e labels.e])
        (crip "/mail/read?id={(trip (scot %uv u.id))}")
        ::  add trusted gateway
        ::
          [%mail %add-gateway ~]
        ?:  (is-comet:mc our.bowl)
          (give-error req-id "Comets cannot add gateways")
        =/  gw-val=(unit @t)  (~(get by form) 'ship')
        ?~  gw-val  (give-error req-id "Missing required field: ship")
        =/  gw-parsed=(unit @p)  (slaw %p u.gw-val)
        ?~  gw-parsed  (give-error req-id "Invalid ship name")
        =/  gw=@p  u.gw-parsed
        =/  already=?  (~(has in gateways) gw)
        =.  gateways  (~(put in gateways) gw)
        =?  gateway  ?=(~ gateway)  `gw
        =.  gw-status  (~(put by gw-status) gw %pending)
        ~&  >  '%mail: added trusted gateway {<gw>}'
        =/  cards=(list card)
          :~  [%pass /gw-req/(scot %p gw) %agent [gw %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%request-access ~])]
          ==
        =?  cards  !already
          (snoc cards [%pass /gateway-info/(scot %p gw) %agent [gw %mail-gateway] %watch /info])
        =/  redir  (give-redirect req-id '/mail/settings')
        [(weld cards -.redir) +.redir]
        ::  remove trusted gateway
        ::
          [%mail %remove-gateway ~]
        =/  gw-val=(unit @t)  (~(get by form) 'ship')
        ?~  gw-val  (give-error req-id "Missing required field: ship")
        =/  gw-parsed=(unit @p)  (slaw %p u.gw-val)
        ?~  gw-parsed  (give-error req-id "Invalid ship name")
        =/  gw=@p  u.gw-parsed
        =.  gateways  (~(del in gateways) gw)
        =.  mail-domains  (~(del by mail-domains) gw)
        =.  gw-status  (~(del by gw-status) gw)
        =?  gateway  ?&(?=(^ gateway) =(gw u.gateway))
          =/  remaining  ~(tap in gateways)
          ?~(remaining ~ `i.remaining)
        ~&  >  '%mail: removed trusted gateway {<gw>}'
        =/  leave-card=card
          [%pass /gateway-info/(scot %p gw) %agent [gw %mail-gateway] %leave ~]
        =/  redir  (give-redirect req-id '/mail/settings')
        [(weld ~[leave-card] -.redir) +.redir]
        ::  re-request gateway access (also resubscribes for domain)
        ::
          [%mail %re-request ~]
        =/  gw-val=(unit @t)  (~(get by form) 'ship')
        ?~  gw-val  (give-error req-id "Missing required field: ship")
        =/  gw-parsed=(unit @p)  (slaw %p u.gw-val)
        ?~  gw-parsed  (give-error req-id "Invalid ship name")
        =/  gw=@p  u.gw-parsed
        =.  gw-status  (~(put by gw-status) gw %pending)
        ~&  >  '%mail: re-requesting access to {<gw>}'
        =/  poke-card=card
          [%pass /gw-req/(scot %p gw) %agent [gw %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%request-access ~])]
        =/  resub-cards=(list card)
          :~  [%pass /gateway-info/(scot %p gw) %agent [gw %mail-gateway] %leave ~]
              [%pass /gateway-info/(scot %p gw) %agent [gw %mail-gateway] %watch /info]
          ==
        =/  redir  (give-redirect req-id '/mail/settings')
        [(weld (weld ~[poke-card] resub-cards) -.redir) +.redir]
        ::  add forwarding rule
        ::
          [%mail %add-fwd-rule ~]
        ?:  (is-comet:mc our.bowl)
          (give-error req-id "Comets cannot create forwarding rules")
        =/  to-val=(unit @t)  (~(get by form) 'to')
        ?~  to-val  (give-error req-id "Missing required field: to")
        =/  to-cord=@t  u.to-val
        =/  to-text=tape  (trip to-cord)
        =/  is-ship=?
          ?&  (gth (lent to-text) 1)
              =('~' (snag 0 to-text))
          ==
        ?:  ?&  is-ship
                =(~ (slaw %p to-cord))
            ==
          (give-error req-id "Invalid ship name in 'to' field")
        ?:  ?&  !is-ship
                !(is-valid-email:mc to-cord)
            ==
          (give-error req-id "Invalid email address")
        =/  to=contact
          ?:  is-ship
            [%urbit (need (slaw %p to-cord))]
          [%ext to-cord]
        =/  conditions=@t
          =/  cond-val  (~(get by form) 'conditions')
          ?~  cond-val  ''
          (crip (trip u.cond-val))
        =.  fwd-rules  (snoc fwd-rules [to conditions %.y])
        (give-redirect req-id '/mail/settings')
        ::  remove forwarding rule
        ::
          [%mail %remove-fwd-rule ~]
        =/  key-val=(unit @t)  (~(get by form) 'key')
        ?~  key-val  (give-error req-id "Missing key")
        =/  key=@uv  (fall (slaw %uv u.key-val) 0v0)
        =.  fwd-rules
          %+  skip  fwd-rules
          |=  r=fwd-rule
          =((sham [to.r conditions.r]) key)
        (give-redirect req-id '/mail/settings')
        ::  toggle forwarding rule
        ::
          [%mail %toggle-fwd-rule ~]
        =/  key-val=(unit @t)  (~(get by form) 'key')
        ?~  key-val  (give-error req-id "Missing key")
        =/  key=@uv  (fall (slaw %uv u.key-val) 0v0)
        =.  fwd-rules
          %+  turn  fwd-rules
          |=  r=fwd-rule
          ?.  =((sham [to.r conditions.r]) key)  r
          r(enabled !enabled.r)
        (give-redirect req-id '/mail/settings')
        ::  set registry: change registry ship
        ::
          [%mail %set-registry ~]
        =/  reg-val=(unit @t)  (~(get by form) 'ship')
        ?~  reg-val  (give-error req-id "Missing required field: ship")
        =/  reg-parsed=(unit @p)  (slaw %p u.reg-val)
        ?~  reg-parsed  (give-error req-id "Invalid ship name")
        =/  new-reg=@p  u.reg-parsed
        ::  leave old registry subscription if exists
        =/  leave-cards=(list card)
          ?~  registry  ~
          :~  [%pass /registry/(scot %p u.registry) %agent [u.registry %mail-registry] %leave ~]
          ==
        =.  registry  `new-reg
        =.  registry-gateways  ~
        ~&  >  '%mail: registry changed to {<new-reg>}'
        =/  sub-card=card
          [%pass /registry/(scot %p new-reg) %agent [new-reg %mail-registry] %watch /registry]
        =/  redir  (give-redirect req-id '/mail/settings')
        [(weld (snoc leave-cards sub-card) -.redir) +.redir]
        ::  gateway admin routes
        ::
          [%mail %gateway *]
        (handle-gw-post t.t.site.url form req-id)
        ::  alias: request free alias
        ::
          [%mail %request-alias ~]
        ?:  (is-comet:mc our.bowl)
          (give-error req-id "Comets cannot manage aliases")
        =/  alias-val=(unit @t)  (~(get by form) 'alias')
        ?~  alias-val  (give-error req-id "Missing required field: alias")
        =/  alias=@t  (crip (cass (trip u.alias-val)))
        =/  gw-val=(unit @t)  (~(get by form) 'gateway')
        ?~  gw-val  (give-error req-id "Missing required field: gateway")
        =/  gw-parsed=(unit @p)  (slaw %p u.gw-val)
        ?~  gw-parsed  (give-error req-id "Invalid gateway ship name")
        =/  gw=@p  u.gw-parsed
        ::  client-side validation
        =/  chars=tape  (trip alias)
        ?:  =(~ chars)
          (give-redirect req-id '/mail/settings?msg=alias-invalid')
        ::  check @p collision
        =/  with-sig=@t  (crip (weld "~" chars))
        =/  clen=@ud  (lent chars)
        ?:  ?&  ?|  =(3 clen)
                    =(6 clen)
                    =(13 clen)
                    =(27 clen)
                ==
                ?=(^ (slaw %p with-sig))
            ==
          (give-redirect req-id '/mail/settings?msg=alias-invalid#s-aliases')
        =/  poke-card=card
          [%pass /alias-req/(scot %p gw) %agent [gw %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%request-alias alias])]
        =/  redir  (give-redirect req-id '/mail/settings?msg=alias-requested#s-aliases')
        [(weld ~[poke-card] -.redir) +.redir]
        ::  alias: request paid alias
        ::
          [%mail %request-paid-alias ~]
        ?:  (is-comet:mc our.bowl)
          (give-error req-id "Comets cannot manage aliases")
        =/  alias-val=(unit @t)  (~(get by form) 'alias')
        ?~  alias-val  (give-error req-id "Missing required field: alias")
        =/  alias=@t  (crip (cass (trip u.alias-val)))
        =/  gw-val=(unit @t)  (~(get by form) 'gateway')
        ?~  gw-val  (give-error req-id "Missing required field: gateway")
        =/  gw-parsed=(unit @p)  (slaw %p u.gw-val)
        ?~  gw-parsed  (give-error req-id "Invalid gateway ship name")
        =/  gw=@p  u.gw-parsed
        =/  chars=tape  (trip alias)
        ?:  =(~ chars)
          (give-redirect req-id '/mail/buy-alias?err=invalid')
        =/  poke-card=card
          [%pass /alias-req/(scot %p gw) %agent [gw %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%request-paid-alias alias])]
        =/  redir  (give-redirect req-id (crip "/mail/buy-alias?pending={(trip alias)}"))
        [(weld ~[poke-card] -.redir) +.redir]
        ::  alias: cancel pending payment
        ::
          [%mail %cancel-payment ~]
        ?:  (is-comet:mc our.bowl)
          (give-error req-id "Comets cannot manage aliases")
        =/  cancel-cards=(list card)
          ?~  pending-payment  ~
          ?~  gateway  ~
          :~  [%pass /alias-cancel %agent [u.gateway %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%cancel-payment alias.u.pending-payment])]
          ==
        =.  pending-payment  ~
        =/  redir  (give-redirect req-id '/mail/settings#s-aliases')
        [(weld cancel-cards -.redir) +.redir]
        ::  alias: verify payment
        ::
          [%mail %verify-payment ~]
        ?:  (is-comet:mc our.bowl)
          (give-error req-id "Comets cannot manage aliases")
        =/  alias-val=(unit @t)  (~(get by form) 'alias')
        ?~  alias-val  (give-error req-id "Missing required field: alias")
        =/  alias=@t  u.alias-val
        =/  gw-val=(unit @t)  (~(get by form) 'gateway')
        ?~  gw-val  (give-error req-id "Missing required field: gateway")
        =/  gw-parsed=(unit @p)  (slaw %p u.gw-val)
        ?~  gw-parsed  (give-error req-id "Invalid gateway ship name")
        =/  gw=@p  u.gw-parsed
        =/  tx-val=(unit @t)  (~(get by form) 'tx-hash')
        ?~  tx-val  (give-error req-id "Missing required field: tx-hash")
        =/  tx-hash=@t  u.tx-val
        =/  poke-card=card
          [%pass /alias-req/(scot %p gw) %agent [gw %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%verify-payment alias tx-hash])]
        =/  redir  (give-redirect req-id '/mail/buy-alias')
        [(weld ~[poke-card] -.redir) +.redir]
        ::  alias: redeem invite code
        ::
          [%mail %redeem-invite ~]
        ?:  (is-comet:mc our.bowl)
          (give-error req-id "Comets cannot manage aliases")
        =/  code-val=(unit @t)  (~(get by form) 'code')
        ?~  code-val  (give-error req-id "Missing required field: code")
        =/  code=@t  u.code-val
        ::  parse gateway from code: alias@~gateway:signature
        =/  code-tape=tape  (trip code)
        =/  at-idx  (find "@" code-tape)
        ?~  at-idx
          (give-redirect req-id '/mail/settings?msg=alias-invalid#s-aliases')
        =/  after-at=tape  (slag +(u.at-idx) code-tape)
        =/  colon-idx  (find ":" after-at)
        ?~  colon-idx
          (give-redirect req-id '/mail/settings?msg=alias-invalid#s-aliases')
        =/  gw-text=tape  (scag u.colon-idx after-at)
        =/  gw-parsed=(unit @p)  (slaw %p (crip gw-text))
        ?~  gw-parsed
          (give-redirect req-id '/mail/settings?msg=alias-invalid#s-aliases')
        =/  gw=@p  u.gw-parsed
        ::  auto-add gateway if not subscribed
        =/  new-gw=?  !(~(has in gateways) gw)
        =?  gateways   new-gw  (~(put in gateways) gw)
        =.  gw-status  (~(put by gw-status) gw %approved)
        =?  gateway    ?&(new-gw ?=(~ gateway))  `gw
        =/  add-cards=(list card)
          ?.  new-gw  ~
          :~  [%pass /gateway-info/(scot %p gw) %agent [gw %mail-gateway] %watch /info]
          ==
        ::  redeem first, then request-access (gateway already approved from redeem)
        =/  poke-card=card
          [%pass /alias-req/(scot %p gw) %agent [gw %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%redeem-invite code])]
        =/  access-card=card
          [%pass /gw-req/(scot %p gw) %agent [gw %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%request-access ~])]
        =/  redir  (give-redirect req-id '/mail/settings?msg=invite-redeemed#s-aliases')
        [(weld (weld add-cards ~[poke-card access-card]) -.redir) +.redir]
        ::  alias: disable own alias
        ::
          [%mail %disable-alias ~]
        ?:  (is-comet:mc our.bowl)
          (give-error req-id "Comets cannot manage aliases")
        =/  alias-val=(unit @t)  (~(get by form) 'alias')
        ?~  alias-val  (give-error req-id "Missing required field: alias")
        =/  alias=@t  u.alias-val
        =/  gw-val=(unit @t)  (~(get by form) 'gateway')
        ?~  gw-val  (give-error req-id "Missing required field: gateway")
        =/  gw-parsed=(unit @p)  (slaw %p u.gw-val)
        ?~  gw-parsed  (give-error req-id "Invalid gateway ship name")
        =/  gw=@p  u.gw-parsed
        =/  poke-card=card
          [%pass /alias-req/(scot %p gw) %agent [gw %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%disable-alias alias])]
        =/  redir  (give-redirect req-id '/mail/settings?msg=alias-updated#s-aliases')
        [(weld ~[poke-card] -.redir) +.redir]
        ::  alias: re-enable own alias
        ::
          [%mail %enable-alias ~]
        ?:  (is-comet:mc our.bowl)
          (give-error req-id "Comets cannot manage aliases")
        =/  alias-val=(unit @t)  (~(get by form) 'alias')
        ?~  alias-val  (give-error req-id "Missing required field: alias")
        =/  alias=@t  u.alias-val
        =/  gw-val=(unit @t)  (~(get by form) 'gateway')
        ?~  gw-val  (give-error req-id "Missing required field: gateway")
        =/  gw-parsed=(unit @p)  (slaw %p u.gw-val)
        ?~  gw-parsed  (give-error req-id "Invalid gateway ship name")
        =/  gw=@p  u.gw-parsed
        =/  poke-card=card
          [%pass /alias-req/(scot %p gw) %agent [gw %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%enable-alias alias])]
        =/  redir  (give-redirect req-id '/mail/settings?msg=alias-updated#s-aliases')
        [(weld ~[poke-card] -.redir) +.redir]
        ::  batch delete: move multiple messages to trash
        ::
          [%mail %batch-delete ~]
        =/  ids=(list @t)  (parse-form-all:mc bod 'ids')
        =/  from=@t  (fall (~(get by form) 'from') 'inbox')
        =/  ret=@t
          =/  r  (fall (~(get by form) 'return') '')
          =/  safe=?  ?&  !=('' r)
                          ?|  =('/mail' r)
                              =('/mail/' (end [3 6] r))
                      ==  ==
          ?.  safe  (crip "/mail{?:(=('sent' from) "/sent" "")}")
          r
        =/  cards=(list card)  ~
        |-
        ?~  ids
          =/  redir  (give-redirect req-id ret)
          [(weld (flop cards) -.redir) +.redir]
        =/  id=(unit @uv)  (slaw %uv i.ids)
        ?~  id  $(ids t.ids)
        =/  mid  u.id
        ?:  (~(has by inbox) mid)
          =/  env  (~(got by inbox) mid)
          =.  inbox  (~(del by inbox) mid)
          =.  trash  (~(put by trash) mid env(folder %trash))
          =.  addr-labels  (~(del by addr-labels) mid)
          $(ids t.ids, cards [[%give %fact ~[/updates] %mail-update !>([%deleted mid])] cards])
        ?:  (~(has by sent) mid)
          =/  env  (~(got by sent) mid)
          =.  sent  (~(del by sent) mid)
          =.  trash  (~(put by trash) mid env(folder %trash))
          =.  addr-labels  (~(del by addr-labels) mid)
          $(ids t.ids, cards [[%give %fact ~[/updates] %mail-update !>([%deleted mid])] cards])
        $(ids t.ids)
        ::  batch mark read
        ::
          [%mail %batch-mark-read ~]
        =/  ids=(list @t)  (parse-form-all:mc bod 'ids')
        =/  ret=@t
          =/  r  (fall (~(get by form) 'return') '')
          =/  safe=?  ?&  !=('' r)
                          ?|  =('/mail' r)
                              =('/mail/' (end [3 6] r))
                      ==  ==
          ?.  safe  '/mail'
          r
        =/  cards=(list card)  ~
        |-
        ?~  ids
          =/  redir  (give-redirect req-id ret)
          [(weld (flop cards) -.redir) +.redir]
        =/  id=(unit @uv)  (slaw %uv i.ids)
        ?~  id  $(ids t.ids)
        ?.  (~(has by inbox) u.id)
          $(ids t.ids)
        =/  env  (~(got by inbox) u.id)
        =.  inbox  (~(put by inbox) u.id env(status %read))
        $(ids t.ids, cards [[%give %fact ~[/updates] %mail-update !>([%status-change u.id %read])] cards])
        ::  batch mark unread
        ::
          [%mail %batch-mark-unread ~]
        =/  ids=(list @t)  (parse-form-all:mc bod 'ids')
        =/  ret=@t
          =/  r  (fall (~(get by form) 'return') '')
          =/  safe=?  ?&  !=('' r)
                          ?|  =('/mail' r)
                              =('/mail/' (end [3 6] r))
                      ==  ==
          ?.  safe  '/mail'
          r
        =/  cards=(list card)  ~
        |-
        ?~  ids
          =/  redir  (give-redirect req-id ret)
          [(weld (flop cards) -.redir) +.redir]
        =/  id=(unit @uv)  (slaw %uv i.ids)
        ?~  id  $(ids t.ids)
        ?.  (~(has by inbox) u.id)
          $(ids t.ids)
        =/  env  (~(got by inbox) u.id)
        =.  inbox  (~(put by inbox) u.id env(status %unread))
        $(ids t.ids, cards [[%give %fact ~[/updates] %mail-update !>([%status-change u.id %unread])] cards])
        ::  backup: download state as JSON file
        ::
          [%mail %backup-download ~]
        ::  download from recovery agent (full backup with gateway)
        ::  fallback to client-only if recovery agent empty
        =/  backup=@t
          =/  recovery=(unit @t)
            %-  mole  |.
            .^(@t %gx /(scot %p our.bowl)/mail-recovery/(scot %da now.bowl)/backup-json/noun)
          ?^  recovery
            ?:  =('' u.recovery)
              (en:json:html (state-to-json:mc state))
            u.recovery
          (en:json:html (state-to-json:mc state))
        :_  this
        %+  give-simple-payload:app:server  req-id
        :-  :-  200
            :~  ['content-type' 'application/json; charset=utf-8']
                ['content-disposition' (crip "attachment; filename=\"mail-backup-{(scow %da now.bowl)}.json\"")]
            ==
        `(as-octs:mimes:html backup)
        ::  create-backup: trigger manual backup now
        ::  dismiss recovery banner
        ::
          [%mail %dismiss-recovery ~]
        =.  recovered-from  ~
        :_  this
        %+  give-simple-payload:app:server  req-id
        [[200 ~] `(as-octs:mimes:html 'ok')]
        ::  set backup interval
        ::
          [%mail %set-backup-interval ~]
        =/  min-val=(unit @t)  (~(get by form) 'minutes')
        ?~  min-val  (give-error req-id "Missing required field: minutes")
        =/  min-parsed=(unit @ud)  (slaw %ud u.min-val)
        ?~  min-parsed  (give-error req-id "Invalid number for minutes")
        =/  minutes=@ud  (max 5 u.min-parsed)
        =/  new-interval=@dr  (mul ~m1 minutes)
        =/  nb=@da  (add now.bowl new-interval)
        =/  cancel-card=card  [%pass /backup-timer %arvo %b %rest next-backup]
        =/  new-timer=card  [%pass /backup-timer %arvo %b %wait nb]
        =.  backup-interval  new-interval
        =.  next-backup  nb
        =/  redir  (give-redirect req-id '/mail/backup')
        [(weld ~[cancel-card new-timer] -.redir) +.redir]
        ::
          [%mail %create-backup ~]
        =/  client-json=json  (state-to-json:mc state)
        =/  gw-json=json
          ?.  is-gw  ~
          =/  gw-backup=(unit @t)
            %-  mole  |.
            .^(@t %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/backup-json/noun)
          ?~  gw-backup  ~
          (fall (de:json:html u.gw-backup) ~)
        =/  full-json=@t
          %-  en:json:html
          %-  pairs:enjs:format
          :~  ['mail' client-json]
              ['mail-gateway' gw-json]
          ==
        ~&  >  '%mail: manual backup ({<(met 3 full-json)>} bytes)'
        =/  poke-card=card
          [%pass /backup-save %agent [our.bowl %mail-recovery] %poke %noun !>([%save-backup full-json])]
        =/  redir  (give-redirect req-id '/mail/backup')
        [(weld ~[poke-card] -.redir) +.redir]
        ::  restore-from-agent: restore from auto-backup
        ::
          [%mail %restore-from-agent ~]
        =/  backup-json=(unit @t)
          %-  mole  |.
          .^(@t %gx /(scot %p our.bowl)/mail-recovery/(scot %da now.bowl)/backup-json/noun)
        ?~  backup-json
          ~&  >>>  '%mail: no auto-backup found'
          (give-redirect req-id '/mail/backup')
        ?:  =('' u.backup-json)
          ~&  >>>  '%mail: auto-backup is empty'
          (give-redirect req-id '/mail/backup')
        =/  all-json  (de:json:html u.backup-json)
        ?~  all-json
          ~&  >>>  '%mail: auto-backup JSON parse failed'
          (give-redirect req-id '/mail/backup')
        ?.  ?=([%o *] u.all-json)
          (give-redirect req-id '/mail/backup')
        =/  client-json
          =/  cj  (~(get by p.u.all-json) 'mail')
          ?^  cj  cj
          (~(get by p.u.all-json) 'mail-client')
        ?~  client-json
          ~&  >>>  '%mail: no mail key in backup'
          (give-redirect req-id '/mail/backup')
        =/  new-state  (restore-from-json:mc (en:json:html u.client-json))
        ?~  new-state
          ~&  >>>  '%mail: restore from auto-backup failed'
          (give-redirect req-id '/mail/backup')
        =*  rs  u.new-state
        =.  state  (apply-restored-state rs)
        ::  also restore gateway if backup has gateway data and we're gateway
        =/  gw-json  (~(get by p.u.all-json) 'mail-gateway')
        =/  gw-restore-card=(list card)
          ?~  gw-json  ~
          ?.  is-gw  ~
          ~&  >  '%mail: gateway backup found — poke gateway to restore'
          :~  [%pass /gw-restore %agent [our.bowl %mail-gateway] %poke %noun !>([%restore-from-json (en:json:html u.gw-json)])]
          ==
        ~&  >  '%mail: state restored from auto-backup'
        =/  redir  (give-redirect req-id '/mail')
        [(weld gw-restore-card -.redir) +.redir]
        ::  restore: upload JSON backup and replace state
        ::
          [%mail %restore ~]
        ?~  bod
          (give-redirect req-id '/mail/backup')
        =/  new-state  (restore-from-json:mc q.u.bod)
        ?~  new-state
          ~&  >>>  '%mail: backup restore failed — invalid JSON'
          (give-redirect req-id '/mail/backup')
        =*  rs  u.new-state
        =.  state  (apply-restored-state rs)
        ~&  >  '%mail: state restored from backup'
        (give-redirect req-id '/mail')
      ==
    ++  apply-restored-state
      |=  rs=current-state
      ^-  current-state
      %=  state
        inbox             inbox.rs
        sent              sent.rs
        trash             trash.rs
        gateway           gateway.rs
        gateways          gateways.rs
        mail-domains      mail-domains.rs
        addr-labels       addr-labels.rs
        gw-status         gw-status.rs
        is-gw             is-gw.rs
        fwd-rules         fwd-rules.rs
        registry          registry.rs
        registry-gateways  registry-gateways.rs
        my-aliases        my-aliases.rs
        pending-payment   pending-payment.rs
        gw-alias-cfg      gw-alias-cfg.rs
        backup-interval   (max ~m5 backup-interval.rs)
        recovered-from    recovered-from.rs
        next-backup       next-backup.rs
        custom-icon-url   custom-icon-url.rs
      ==
    --
    ::
      %mail-action
    =/  act  !<(action vase)
    =/  update-in-mailboxes
      |=  [id=@uv transform=$-(envelope envelope) make-update=$-(envelope update)]
      ^-  (quip card _this)
      ?:  (~(has by inbox) id)
        =/  env  (~(got by inbox) id)
        =/  new-env  (transform env)
        :_  this(inbox (~(put by inbox) id new-env))
        ~[[%give %fact ~[/updates] %mail-update !>((make-update new-env))]]
      ?:  (~(has by sent) id)
        =/  env  (~(got by sent) id)
        =/  new-env  (transform env)
        :_  this(sent (~(put by sent) id new-env))
        ~[[%give %fact ~[/updates] %mail-update !>((make-update new-env))]]
      ?:  (~(has by trash) id)
        =/  env  (~(got by trash) id)
        =/  new-env  (transform env)
        :_  this(trash (~(put by trash) id new-env))
        ~[[%give %fact ~[/updates] %mail-update !>((make-update new-env))]]
      `this
    ?-  -.act
      ::  %send: compose and route a message
      ::
        %send
      =/  id  (make-id:mc now.bowl eny.bowl)
      =/  msg=message
        :*  id
            [%urbit our.bowl]
            to.act
            cc.act
            ~
            subject.act
            body.act
            now.bowl
            ~
        ==
      =/  env=envelope  [msg %sending %sent ~ '']
      =/  target-card=card
        ?-  -.to.act
          ::  urbit recipient: poke directly
          ::
            %urbit
          [%pass /send/(scot %uv id) %agent [p.to.act %mail-client] %poke %mail-message !>(msg)]
          ::  external recipient: route through gateway
          ::
            %ext
          =/  gw=@p
            ?~  gateway
              ~|('%mail: no gateway configured' !!)
            u.gateway
          [%pass /send/(scot %uv id) %agent [gw %mail-gateway] %poke %mail-message !>(msg)]
        ==
      =/  upd-card=card
        [%give %fact ~[/updates] %mail-update !>([%sent env])]
      =/  timeout-card=card
        [%pass /send-timeout/(scot %uv id) %arvo %b %wait (add now.bowl ~m5)]
      :_  this(sent (~(put by sent) id env))
      ~[target-card upd-card timeout-card]
      ::  %receive: accept an incoming message
      ::
        %receive
      =*  msg  msg.act
      ?.  ?|  =(our.bowl src.bowl)
              (~(has in gateways) src.bowl)
              ?&  ?=([%urbit *] from.msg)
                  =(p.from.msg src.bowl)
              ==
          ==
        `this
      ?:  (gth (met 3 body.msg) 1.000.000)  `this
      =/  env=envelope  [msg %unread %inbox ~ '']
      =/  upd-card=card
        [%give %fact ~[/updates] %mail-update !>([%new-mail env])]
      =/  fwd-cards=(list card)
        (build-fwd-cards:mc msg ~ fwd-rules our.bowl now.bowl eny.bowl gateway %.y '')
      :_  this(inbox (~(put by inbox) id.msg env))
      (weld ~[upd-card] fwd-cards)
      ::  %receive-labeled: accept message with labels from gateway
      ::
        %receive-labeled
      =*  msg  msg.act
      ?.  ?|  =(our.bowl src.bowl)
              (~(has in gateways) src.bowl)
              ?&  ?=([%urbit *] from.msg)
                  =(p.from.msg src.bowl)
              ==
          ==
        `this
      ?:  (gth (met 3 body.msg) 1.000.000)  `this
      =/  env=envelope  [msg %unread %inbox labels.act recv-addr.act]
      =/  upd-card=card
        [%give %fact ~[/updates] %mail-update !>([%new-mail env])]
      =.  addr-labels  (~(put by addr-labels) id.msg ~(tap in labels.act))
      =/  fwd-cards=(list card)
        (build-fwd-cards:mc msg labels.act fwd-rules our.bowl now.bowl eny.bowl gateway %.y recv-addr.act)
      :_  this(inbox (~(put by inbox) id.msg env))
      (weld ~[upd-card] fwd-cards)
      ::  %mark-read: mark a message as read
      ::
        %mark-read
      ?.  (~(has by inbox) id.act)  `this
      =/  env=envelope  (~(got by inbox) id.act)
      =/  new-env=envelope  env(status %read)
      =/  upd-card=card
        [%give %fact ~[/updates] %mail-update !>([%status-change id.act %read])]
      :_  this(inbox (~(put by inbox) id.act new-env))
      ~[upd-card]
      ::  %mark-unread: mark a message as unread
      ::
        %mark-unread
      ?.  (~(has by inbox) id.act)  `this
      =/  env=envelope  (~(got by inbox) id.act)
      =/  new-env=envelope  env(status %unread)
      =/  upd-card=card
        [%give %fact ~[/updates] %mail-update !>([%status-change id.act %unread])]
      :_  this(inbox (~(put by inbox) id.act new-env))
      ~[upd-card]
      ::  %delete: move message to trash
      ::
        %delete
      =/  id  id.act
      ?:  (~(has by inbox) id)
        =/  env=envelope  (~(got by inbox) id)
        =/  trashed=envelope  env(folder %trash)
        =/  upd-card=card
          [%give %fact ~[/updates] %mail-update !>([%deleted id])]
        :_  this(inbox (~(del by inbox) id), trash (~(put by trash) id trashed), addr-labels (~(del by addr-labels) id))
        ~[upd-card]
      ?:  (~(has by sent) id)
        =/  env=envelope  (~(got by sent) id)
        =/  trashed=envelope  env(folder %trash)
        =/  upd-card=card
          [%give %fact ~[/updates] %mail-update !>([%deleted id])]
        :_  this(sent (~(del by sent) id), trash (~(put by trash) id trashed), addr-labels (~(del by addr-labels) id))
        ~[upd-card]
      `this
      ::  %add-label: add a label to a message
      ::
        %add-label
      %-  update-in-mailboxes
      :+  id.act
        |=(e=envelope e(labels (~(put in labels.e) label.act)))
      |=(e=envelope [%labels-changed id.msg.e labels.e])
      ::  %remove-label: remove a label from a message
      ::
        %remove-label
      %-  update-in-mailboxes
      :+  id.act
        |=(e=envelope e(labels (~(del in labels.e) label.act)))
      |=(e=envelope [%labels-changed id.msg.e labels.e])
      ::  %set-gateway: set the outbound gateway ship
      ::
        %set-gateway
      ~&  >  '%mail: gateway set to {<ship.act>}'
      =/  already=?  (~(has in gateways) ship.act)
      =.  gateways  (~(put in gateways) ship.act)
      =.  gw-status  (~(put by gw-status) ship.act %pending)
      =/  cards=(list card)
        :~  [%pass /gw-req/(scot %p ship.act) %agent [ship.act %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%request-access ~])]
        ==
      =?  cards  !already
        (snoc cards [%pass /gateway-info/(scot %p ship.act) %agent [ship.act %mail-gateway] %watch /info])
      :_  this(gateway `ship.act)
      cards
      ::  %add-gateway: add a trusted inbound gateway
      ::
        %add-gateway
      ~&  >  '%mail: added trusted gateway {<ship.act>}'
      :_  this(gateways (~(put in gateways) ship.act), gw-status (~(put by gw-status) ship.act %pending))
      :~  [%pass /gateway-info/(scot %p ship.act) %agent [ship.act %mail-gateway] %watch /info]
          [%pass /gw-req/(scot %p ship.act) %agent [ship.act %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%request-access ~])]
      ==
      ::  %remove-gateway: remove a trusted inbound gateway
      ::
        %remove-gateway
      ~&  >  '%mail: removed trusted gateway {<ship.act>}'
      =.  mail-domains  (~(del by mail-domains) ship.act)
      =.  gw-status  (~(del by gw-status) ship.act)
      :_  this(gateways (~(del in gateways) ship.act))
      :~  [%pass /gateway-info/(scot %p ship.act) %agent [ship.act %mail-gateway] %leave ~]
      ==
      ::  %access-response: gateway approved/rejected our access
      ::
        %access-response
      ?.  (~(has in gateways) src.bowl)  `this
      ~&  >  '%mail: gateway {<src.bowl>} responded with {<status.act>}'
      =.  gw-status  (~(put by gw-status) src.bowl status.act)
      ::  if approved and we don't have domain yet, resubscribe to get it
      ?.  ?&  =(%approved status.act)
              =('' (fall (~(get by mail-domains) src.bowl) ''))
          ==
        `this
      ~&  >  '%mail: resubscribing to {<src.bowl>} /info for domain'
      :_  this
      :~  [%pass /gateway-info/(scot %p src.bowl) %agent [src.bowl %mail-gateway] %leave ~]
          [%pass /gateway-info/(scot %p src.bowl) %agent [src.bowl %mail-gateway] %watch /info]
      ==
      ::  %set-is-gateway: gateway agent notifies us it's running locally
      ::
        %set-is-gateway
      ?.  =(our.bowl src.bowl)  `this
      ~&  >  '%mail: is-gw set to {<is-gw.act>}'
      `this(is-gw is-gw.act)
      ::
        %alias-update
      ?.  ?&((~(has in gateways) src.bowl) =(gw.act src.bowl))  `this
      ~&  >  '%mail: alias update from {<gw.act>}'
      ::  clear pending-payment if the purchased alias is now active
      =?  pending-payment  ?=(^ pending-payment)
        ?.  (lien aliases.act |=([a=@t *] =(a alias.u.pending-payment)))
          pending-payment
        ~&  >  '%mail: alias {(trip alias.u.pending-payment)} confirmed, clearing pending payment'
        ~
      `this(my-aliases (~(put by my-aliases) gw.act aliases.act))
      ::
        %alias-error
      ?.  (~(has in gateways) src.bowl)  `this
      ~&  >>>  '%mail: alias error: {(trip msg.act)}'
      :_  this
      :~  [%give %fact ~[/updates] %mail-update !>([%send-failed `@uv`0 msg.act])]
      ==
      ::
        %payment-request
      ?.  (~(has in gateways) src.bowl)  `this
      ~&  >  '%mail: payment request for alias {(trip alias.act)} amount={<amount.act>}'
      `this(pending-payment `[alias.act amount.act wallet.act now.bowl])
      ::
        %send-failed
      ?.  (~(has in gateways) src.bowl)  `this
      ~&  >>>  '%mail: delivery failed for {<id.act>}'
      =/  env  (~(get by sent) id.act)
      ?~  env  `this
      =.  sent  (~(put by sent) id.act u.env(status %failed))
      :_  this
      :~  [%give %fact ~[/updates] %mail-update !>(`update`[%send-failed id.act reason.act])]
      ==
    ==
    ::  %mail-message: incoming message from another ship or gateway
    ::
      %mail-message
    =/  msg  !<(message vase)
    ?.  ?|  =(our.bowl src.bowl)
            (~(has in gateways) src.bowl)
            ?&  ?=([%urbit *] from.msg)
                =(p.from.msg src.bowl)
            ==
        ==
      `this
    ?:  (gth (met 3 body.msg) 1.000.000)  `this
    =/  env=envelope  [msg %unread %inbox ~ '']
    =/  upd-card=card
      [%give %fact ~[/updates] %mail-update !>([%new-mail env])]
    =/  fwd-cards=(list card)
      (build-fwd-cards:mc msg ~ fwd-rules our.bowl now.bowl eny.bowl gateway %.n '')
    :_  this(inbox (~(put by inbox) id.msg env))
    (weld ~[upd-card] fwd-cards)
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  `this
      [%http-response *]
    `this
    ::
      [%updates ~]
    ?.  =(our.bowl src.bowl)
      :_  this
      ~[[%give %kick ~[path] `src.bowl]]
    `this
    ::
      [%inbox ~]
    ?.  =(our.bowl src.bowl)
      :_  this
      ~[[%give %kick ~[path] `src.bowl]]
    :_  this
    %+  turn  ~(tap by inbox)
    |=  [id=@uv env=envelope]
    ^-  card
    [%give %fact ~[/inbox] %mail-update !>([%new-mail env])]
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  ~
      [%x %inbox ~]
    ``[%noun !>(inbox)]
      [%x %sent ~]
    ``[%noun !>(sent)]
      [%x %trash ~]
    ``[%noun !>(trash)]
    ::
      [%x %message @ ~]
    =/  id  (slav %uv i.t.t.path)
    =/  result=(unit envelope)
      ?^  res=(~(get by inbox) id)  res
      ?^  res=(~(get by sent) id)   res
      (~(get by trash) id)
    ``[%noun !>(result)]
    ::
      [%x %unread-count ~]
    =/  count=@ud
      %-  ~(rep by inbox)
      |=  [[id=@uv env=envelope] acc=@ud]
      ?:(=(status.env %unread) +(acc) acc)
    ``[%noun !>(count)]
    ::
      [%x %gateway ~]
    ``[%noun !>(gateway)]
    ::
      [%x %gateways ~]
    ``[%noun !>(gateways)]
    ::
      [%x %mail-domains ~]
    ``[%noun !>(mail-domains)]
    ::
      [%x %installed ~]
    ``[%noun !>(%.y)]
    ::
      [%x %labels ~]
    =/  lab=(set @tas)  ~
    =.  lab
      %-  ~(rep by inbox)
      |=  [[id=@uv env=envelope] acc=(set @tas)]
      (~(uni in acc) labels.env)
    =.  lab
      %-  ~(rep by sent)
      |=  [[id=@uv env=envelope] acc=(set @tas)]
      (~(uni in acc) labels.env)
    =.  lab
      %-  ~(rep by trash)
      |=  [[id=@uv env=envelope] acc=(set @tas)]
      (~(uni in acc) labels.env)
    ``[%noun !>(lab)]
    ::
      [%x %by-label @ ~]
    =/  label=@tas  i.t.t.path
    =/  matches=(list [id=@uv env=envelope])
      %+  skim
        (weld ~(tap by inbox) (weld ~(tap by sent) ~(tap by trash)))
      |=  [id=@uv env=envelope]
      (~(has in labels.env) label)
    ``[%noun !>(matches)]
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+  wire  `this
      [%send @ ~]
    =/  id  (slav %uv i.t.wire)
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign
        ::  success: mark as sent (delivered)
        ?.  (~(has by sent) id)
          `this
        =/  env=envelope  (~(got by sent) id)
        `this(sent (~(put by sent) id env(status %sent)))
      ::  failure: mark as failed
      ~&  >>>  '%mail: message {<id>} delivery failed'
      =/  upd-card=card
        [%give %fact ~[/updates] %mail-update !>([%send-failed id 'delivery failed'])]
      ?:  (~(has by sent) id)
        =/  env=envelope  (~(got by sent) id)
        :_  this(sent (~(put by sent) id env(status %failed)))
        ~[upd-card]
      :_  this
      ~[upd-card]
    ==
    ::
      [%gw-req @ ~]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign
        ~&  >  '%mail: access request sent to {<i.t.wire>}'
        `this
      ~&  >>>  '%mail: access request to {<i.t.wire>} failed'
      `this
    ==
    ::
      [%alias-req @ ~]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign
        ~&  >  '%mail: alias request to {<i.t.wire>} succeeded'
        `this
      ~&  >>>  '%mail: alias request to {<i.t.wire>} failed: {<u.p.sign>}'
      `this
    ==
    ::
      [%alias-notify @ ~]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign  `this
      ~&  >>>  '%mail: alias notify ack failed for {<i.t.wire>}'
      `this
    ==
    ::
      [%gw-admin ~]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign  `this
      ~&  >>>  '%mail: gateway admin poke failed'
      `this
    ==
    ::
      [%payment-check ~]
    ?+  -.sign  `this
        %poke-ack  `this
    ==
    ::
      [%fwd @ ~]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign  `this
      ~&  >>>  '%mail: forwarding failed for {<i.t.wire>}'
      `this
    ==
    ::
      [%gateway-info @ ~]
    =/  gw-ship=@p  (slav %p i.t.wire)
    ?+  -.sign  `this
        %watch-ack
      ?~  p.sign
        ~&  >  '%mail: subscribed to gateway info from {<gw-ship>}'
        `this
      ~&  >>>  '%mail: gateway info subscription to {<gw-ship>} failed'
      `this
        %fact
      =/  noun  q.q.cage.sign
      ::  try 6-cell [domain on min free-min base pay-on], fallback to defaults
      =/  [dom=@t als-on=? als-min=@ud als-free-min=@ud als-base=@ud pay-on=?]
        =/  full  (mole |.(;;([@ ? @ @ @ ?] noun)))
        ?^  full  u.full
        ::  try 5-cell (no payment-enabled)
        =/  five  (mole |.(;;([@ ? @ @ @] noun)))
        ?^  five  [-.u.five +<.u.five +>-.u.five +>+<.u.five +>+>.u.five %.n]
        ::  old format — extract domain, assume aliases on with defaults
        =/  d=@t  ?:(?=(@ noun) `@t`noun ?:(?=([@ @] noun) `@t`-.noun ''))
        [d %.y 5 10 5.000.000.000.000.000 %.n]
      ~&  >  '%mail: info from {<gw-ship>}: {(trip dom)}, aliases={<als-on>}, pay={<pay-on>}'
      =.  mail-domains  (~(put by mail-domains) gw-ship dom)
      =.  gw-alias-cfg  (~(put by gw-alias-cfg) gw-ship [als-on als-min als-free-min als-base pay-on])
      `this
        %kick
      ~&  >  '%mail: gateway info from {<gw-ship>} kicked, resubscribing'
      :_  this
      :~  [%pass /gateway-info/(scot %p gw-ship) %agent [gw-ship %mail-gateway] %watch /info]
      ==
    ==
    ::
      [%registry @ ~]
    =/  reg-ship=@p  (slav %p i.t.wire)
    ?+  -.sign  `this
        %watch-ack
      ?~  p.sign
        ~&  >  '%mail: subscribed to registry on {<reg-ship>}'
        `this
      ~&  >>>  '%mail: registry subscription to {<reg-ship>} failed'
      `this
        %fact
      ?.  ?=(%json p.cage.sign)
        ~&  >>>  '%mail: unexpected registry fact mark: {<p.cage.sign>}'
        `this
      =/  j=json  !<(json q.cage.sign)
      =/  new-gws=(map @p reg-entry)  (parse-registry-json:mc j)
      ~&  >  '%mail: registry update from {<reg-ship>}: {<~(wyt by new-gws)>} gateways'
      `this(registry-gateways new-gws)
        %kick
      ~&  >  '%mail: registry from {<reg-ship>} kicked, resubscribing'
      :_  this
      :~  [%pass /registry/(scot %p reg-ship) %agent [reg-ship %mail-registry] %watch /registry]
      ==
    ==
  ==
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+  wire  `this
      [%bind ~]
    ~&  >  '%mail: eyre bound'
    `this
    ::  send timeout: mark as failed if still sending
    ::
      [%send-timeout @ ~]
    =/  id  (slav %uv i.t.wire)
    ?.  (~(has by sent) id)
      `this
    =/  env=envelope  (~(got by sent) id)
    ?.  =(%sending status.env)
      ::  already resolved (ack or nack arrived), ignore
      `this
    :_  this(sent (~(put by sent) id env(status %failed)))
    :~  [%give %fact ~[/updates] %mail-update !>([%send-failed id 'delivery timed out'])]
    ==
    ::  auto-backup timer + trash cleanup
    ::
      [%backup-timer ~]
    ::  purge trash older than 30 days
    =.  trash
      %-  ~(gas by *(map @uv envelope))
      %+  skip  ~(tap by trash)
      |=  [id=@uv env=envelope]
      ?&  (gth now.bowl sent-at.msg.env)
          (gth (sub now.bowl sent-at.msg.env) ~d30)
      ==
    =/  client-json=json  (state-to-json:mc state)
    ::  include gateway state if running locally
    =/  gw-json=json
      ?.  is-gw  ~
      =/  gw-backup=(unit @t)
        %-  mole  |.
        .^(@t %gx /(scot %p our.bowl)/mail-gateway/(scot %da now.bowl)/backup-json/noun)
      ?~  gw-backup  ~
      (fall (de:json:html u.gw-backup) ~)
    =/  full-json=@t
      %-  en:json:html
      %-  pairs:enjs:format
      :~  ['mail' client-json]
          ['mail-gateway' gw-json]
      ==
    ::  silent auto-backup — reschedule with tracked next-backup
    =/  nb=@da  (add now.bowl backup-interval)
    :_  this(next-backup nb)
    :~  [%pass /backup-save %agent [our.bowl %mail-recovery] %poke %noun !>([%save-backup full-json])]
        [%pass /backup-timer %arvo %b %wait nb]
    ==
  ==
++  on-leave  on-leave:def
::
++  on-fail
  |=  [=term =tang]
  ^-  (quip card _this)
  ~&  >>>  'mail-client on-fail: {<term>}'
  `this
--
