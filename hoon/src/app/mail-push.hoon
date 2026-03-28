::  %mail-push: push notification agent for Urbit Mail
::
::  Subscribes to %mail-client /updates, sends Web Push
::  notifications via iris when new mail arrives.
::
/-  *mail-client
/-  *mail-push
/-  *push
/+  default-agent, dbug, server, web-push
|%
+$  card  card:agent:gall
+$  state  push-state
--
=/  sw-js=@t
  'self.addEventListener("install",function(e){self.skipWaiting()});self.addEventListener("activate",function(e){e.waitUntil(self.clients.claim())});self.addEventListener("push",function(e){var d={title:"Notification",body:""};try{d=e.data.json()}catch(x){}e.waitUntil(self.registration.showNotification(d.title,{body:d.body||"",icon:d.icon||"",data:{url:d.url||""}}))});self.addEventListener("notificationclick",function(e){e.notification.close();if(e.notification.data&&e.notification.data.url)e.waitUntil(clients.openWindow(e.notification.data.url))});'
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
  ~&  >  '%mail-push: installed'
  =.  config  (some (generate-vapid-keypair:web-push eny.bowl 'mailto:rolrup.push.admin@urmail.me'))
  :_  this
  :~  [%pass /bind %arvo %e %connect [~ /mail-push] %mail-push]
      [%pass /mail-updates %agent [our.bowl %mail-client] %watch /updates]
  ==
::
++  on-save
  ^-  vase
  !>([%0 state])
::
++  on-load
  |=  old-vase=vase
  ^-  (quip card _this)
  =/  old  !<(versioned-push-state old-vase)
  ?-  -.old
      %0
    =.  state  +.old
    =?  config  ?=(~ config)
      (some (generate-vapid-keypair:web-push eny.bowl 'mailto:rolrup.push.admin@urmail.me'))
    :_  this
    :~  [%pass /bind %arvo %e %connect [~ /mail-push] %mail-push]
        [%pass /mail-updates %agent [our.bowl %mail-client] %watch /updates]
    ==
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?.  ?=(%handle-http-request mark)  `this
  |^
  =+  !<([req-id=@ta req=inbound-request:eyre] vase)
  =/  url  (parse-request-line:server url.request.req)
  ?+  method.request.req  `this
      %'GET'   (handle-get req-id url req)
      %'POST'  (handle-post req-id url body.request.req req)
  ==
  ::
  ++  handle-get
    |=  [req-id=@ta url=request-line:server req=inbound-request:eyre]
    ^-  (quip card _this)
    ?+  site.url  `this
        [%mail-push %vapid-key ~]
      ?~  config
        :_  this
        %+  give-simple-payload:app:server  req-id
        [[500 ~] `(as-octs:mimes:html 'not configured')]
      =/  pub-b64=@t  (~(en base64:mimes:html | &) [65 (rev 3 65 public-key.u.config)])
      :_  this
      %+  give-simple-payload:app:server  req-id
      :-  [200 ~[['content-type' 'text/plain'] ['access-control-allow-origin' '*']]]
      `(as-octs:mimes:html pub-b64)
      ::
        [%mail-push %sw ~]
      :_  this
      %+  give-simple-payload:app:server  req-id
      :-  [200 ~[['content-type' 'application/javascript'] ['service-worker-allowed' '/']]]
      `(as-octs:mimes:html sw-js)
    ==
  ::
  ++  handle-post
    |=  [req-id=@ta url=request-line:server body=(unit octs) req=inbound-request:eyre]
    ^-  (quip card _this)
    ?+  site.url  `this
        [%mail-push %subscribe ~]
      ?~  body  (give-err req-id 400 'no body')
      =/  jon=(unit json)  (de:json:html q.u.body)
      ?~  jon  (give-err req-id 400 'invalid json')
      ?.  ?=(%o -.u.jon)  (give-err req-id 400 'expected object')
      =/  obj  p.u.jon
      =/  id-j  (~(get by obj) 'id')
      =/  ep-j  (~(get by obj) 'endpoint')
      =/  dh-j  (~(get by obj) 'p256dh')
      =/  au-j  (~(get by obj) 'auth')
      ?.  ?&  ?=(^ id-j)  ?=(%s -.u.id-j)
              ?=(^ ep-j)  ?=(%s -.u.ep-j)
              ?=(^ dh-j)  ?=(%s -.u.dh-j)
              ?=(^ au-j)  ?=(%s -.u.au-j)
          ==
        (give-err req-id 400 'missing fields')
      =/  dh-octs=(unit octs)  (~(de base64:mimes:html | &) p.u.dh-j)
      =/  au-octs=(unit octs)  (~(de base64:mimes:html | &) p.u.au-j)
      ?~  dh-octs  (give-err req-id 400 'invalid p256dh')
      ?~  au-octs  (give-err req-id 400 'invalid auth')
      =/  dh=@  (rev 3 p.u.dh-octs q.u.dh-octs)
      =/  au=@  (rev 3 p.u.au-octs q.u.au-octs)
      =/  sub=subscription  [p.u.ep-j dh au]
      =/  id=@ta  `@ta`p.u.id-j
      =/  inner=(map @ta subscription)  (~(gut by subs) src.bowl ~)
      =.  subs  (~(put by subs) src.bowl (~(put by inner) id sub))
      ~&  >  'mail-push: subscription added for {<src.bowl>}'
      :_  this
      %+  give-simple-payload:app:server  req-id
      :-  [200 ~[['content-type' 'application/json']]]
      `(as-octs:mimes:html '{"ok":true}')
      ::
        [%mail-push %unsubscribe ~]
      ?~  body  (give-err req-id 400 'no body')
      =/  jon=(unit json)  (de:json:html q.u.body)
      ?~  jon  (give-err req-id 400 'invalid json')
      ?.  ?=(%o -.u.jon)  (give-err req-id 400 'expected object')
      =/  id-j  (~(get by p.u.jon) 'id')
      ?.  &(?=(^ id-j) ?=(%s -.u.id-j))  (give-err req-id 400 'missing id')
      =/  id=@ta  `@ta`p.u.id-j
      =/  inner=(map @ta subscription)  (~(gut by subs) src.bowl ~)
      =/  new-inner  (~(del by inner) id)
      =.  subs
        ?:  =(~ new-inner)
          (~(del by subs) src.bowl)
        (~(put by subs) src.bowl new-inner)
      ~&  >  'mail-push: subscription removed for {<src.bowl>}'
      :_  this
      %+  give-simple-payload:app:server  req-id
      :-  [200 ~[['content-type' 'application/json']]]
      `(as-octs:mimes:html '{"ok":true}')
    ==
  ::
  ++  give-err
    |=  [req-id=@ta code=@ud msg=@t]
    ^-  (quip card _this)
    :_  this
    %+  give-simple-payload:app:server  req-id
    :-  [code ~[['content-type' 'application/json']]]
    =/  err=@t  (rap 3 ~['{"error":"' msg '"}'])
    `(as-octs:mimes:html err)
  --
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  `this
      [%http-response *]  `this
  ==
::
++  on-leave
  |=  =path
  ^-  (quip card _this)
  `this
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  [~ ~]
      [%x %state ~]
    ``noun+!>(state)
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+  wire  `this
      [%mail-updates ~]
    ?+  -.sign  `this
        %watch-ack
      ?~  p.sign
        ~&  >  'mail-push: subscribed to %mail updates'
        `this
      ~&  >>>  'mail-push: subscription to %mail failed'
      `this
        %kick
      ~&  >  'mail-push: kicked from %mail, resubscribing'
      :_  this
      ~[[%pass /mail-updates %agent [our.bowl %mail-client] %watch /updates]]
        %fact
      =/  upd  !<(update q.cage.sign)
      ?.  ?=(%new-mail -.upd)  `this
      ~&  >  'mail-push: new mail, sending push'
      |^
      =/  push-cards=(list card)  (send-pushes +.upd)
      [push-cards this]
      ++  send-pushes
        |=  env=envelope
        ^-  (list card)
        ?~  config  ~
        =/  from-short=tape
          ?-  -.from.msg.env
            %urbit  =/  full  (scow %p p.from.msg.env)
                    ?:  (lte (lent full) 28)  full
                    (weld (scag 14 full) (weld "..." (slag (sub (lent full) 7) full)))
            %ext    =/  full  (trip p.from.msg.env)
                    ?:  (lte (lent full) 30)  full
                    (weld (scag 15 full) (weld "..." (slag (sub (lent full) 12) full)))
          ==
        =/  pm=push-message
          :*  (crip from-short)
              (crip (scag 100 (trip subject.msg.env)))
              `'/mail/icon-192.png'
              `(crip "/mail/read?id={(trip (scot %uv id.msg.env))}")
              ~
          ==
        =/  payload=octs  (message-to-json:web-push pm)
        =/  exp=@ud  (add (div (sub now.bowl ~1970.1.1) ~s1) 86.400)
        =/  all-subs=(list [=ship id=@ta sub=subscription])
          %-  zing
          %+  turn  ~(tap by subs)
          |=  [=ship inner=(map @ta subscription)]
          %+  turn  ~(tap by inner)
          |=  [id=@ta sub=subscription]
          [ship id sub]
        %+  turn  all-subs
        |=  [=ship id=@ta sub=subscription]
        ^-  card
        =/  req=request:http  (send-notification:web-push sub u.config payload exp eny.bowl)
        [%pass /push-send/(scot %p ship)/[id] %arvo %i %request req *outbound-config:iris]
      --
    ==
  ==
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+  wire  `this
      [%bind ~]
    ~&  >  '%mail-push: eyre bound'
    `this
      [%push-send @ @ ~]
    `this
  ==
::
++  on-fail
  |=  [=term =tang]
  ^-  (quip card _this)
  ~&  >>>  'mail-push on-fail: {<term>}'
  `this
--
