::  %mail-gateway: relay agent for Urbit Mail Gateway
::
::  Sits in the same desk as %mail-client.
::  On the gateway ship, relays messages between:
::    - Python bridge (via Eyre) and target ships
::    - Client ships sending external email and Python bridge
::
/-  *mail-client
/-  *mail-gateway
/-  *mail-registry
/+  default-agent, dbug, mc=mail-client, hkdf
|%
+$  card  card:agent:gall
+$  state  gateway-state-9
::  reserved alias names that cannot be registered
::
++  reserved-aliases
  ^-  (set @t)
  %-  silt
  ^-  (list @t)
  :~  ::  RFC 2142 / email system
      'postmaster'  'abuse'  'hostmaster'  'webmaster'  'mailer-daemon'
      'noreply'  'no-reply'  'do-not-reply'  'daemon'  'bounce'  'devnull'  'null'
      ::  admin / system
      'admin'  'root'  'system'  'operator'  'info'  'support'  'help'
      'security'  'billing'  'sales'  'contact'  'service'
      'newsletter'  'alerts'  'notifications'
      ::  brand / impersonation
      'ceo'  'cto'  'founder'  'team'  'staff'  'official'  'urbit'  'tlon'
      ::  finance / crypto scam vectors
      'wallet'  'payment'  'payments'  'pay'  'invoice'
      'bank'  'crypto'  'ethereum'  'bitcoin'  'eth'  'btc'
      'treasury'  'escrow'  'refund'
      ::  infrastructure
      'www'  'mail'  'smtp'  'imap'  'pop'  'ftp'
      'dns'  'ns1'  'ns2'  'ssl'  'api'  'dev'  'test'  'staging'  'localhost'
  ==
::  validate-alias: check alias format and reject @p lookalikes
::
++  validate-alias
  |=  a=@t
  ^-  ?
  =/  chars=tape  (trip a)
  ?~  chars  %.n
  ?:  (gth (lent chars) 63)  %.n
  ::  reject if parseable as @p — galaxies (3 chars), stars (6),
  ::  planets (13 with hyphen), moons (27 with hyphens)
  =/  len=@ud  (lent chars)
  =/  with-sig=@t  (crip (weld "~" chars))
  ?:  ?&  ?|  =(3 len)   :: galaxy: ~zod
              =(6 len)   :: star: ~marzod
              =(13 len)  :: planet: ~sampel-palnet
              =(27 len)  :: moon: ~sampel-palnet-sampel-palnet
          ==
          ?=(^ (slaw %p with-sig))
      ==
    %.n
  ::  first char must be a-z or 0-9
  ?.  ?|  &((gte i.chars 'a') (lte i.chars 'z'))
          &((gte i.chars '0') (lte i.chars '9'))
      ==
    %.n
  ::  rest can also include - _  (no dots — dots are label separators)
  =/  rest=tape  t.chars
  |-
  ?~  rest  %.y
  ?.  ?|  &((gte i.rest 'a') (lte i.rest 'z'))
          &((gte i.rest '0') (lte i.rest '9'))
          =(i.rest '-')
          =(i.rest '_')
      ==
    %.n
  $(rest t.rest)
::  count-ship-aliases: count aliases owned by a ship
::
++  count-ship-aliases
  |=  [als=(map @t alias-entry) ship=@p]
  ^-  @ud
  %-  ~(rep by als)
  |=  [[* e=alias-entry] acc=@ud]
  ?:(=(owner.e ship) +(acc) acc)
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
  ~&  >  '%mail-gateway installed'
  :_  this(domain '', whitelist ~, auto-approve %.n, enabled %.n, out-log ~, public %.y, aliases ~, alias-config [%.n 5 10 5 %.n '' 5.000.000.000.000.000 ''], invite-secret 0, pending-payments ~)
  :~  [%pass /set-gw %agent [our.bowl %mail-client] %poke %mail-action !>(`action`[%set-is-gateway %.n])]
  ==
::
++  on-save
  ^-  vase
  !>([%9 state])
::
++  on-load
  |=  old-vase=vase
  ^-  (quip card _this)
  =/  parsed=(unit versioned-gateway-state)
    %-  mole  |.
    !<(versioned-gateway-state old-vase)
  ?~  parsed
    ~&  >>>  '%mail-gateway: state mismatch — attempting recovery'
    =/  body  +.q.old-vase
    ::  strategy 1: try full state cast (works when only version tag differs)
    =/  rec-full=(unit gateway-state-9)  (mole |.(;;(gateway-state-9 body)))
    ?^  rec-full
      ~&  >  '%mail-gateway: FULL RECOVERY — {<~(wyt by whitelist.u.rec-full)>} ships, {<~(wyt by aliases.u.rec-full)>} aliases'
      =/  gw-card=card  [%pass /set-gw %agent [our.bowl %mail-client] %poke %mail-action !>(`action`[%set-is-gateway enabled.u.rec-full])]
      :_  this(state u.rec-full)
      ~[gw-card]
    ::  strategy 2: extract critical fields by position
    =/  rec-domain=(unit @t)                      (mole |.(;;(@t +<.body)))
    =/  rec-wl=(unit (map @p wl-entry))           (mole |.(;;((map @p wl-entry) +>-.body)))
    =/  rec-aliases=(unit (map @t alias-entry))    (mole |.(;;((map @t alias-entry) +>+>+>+<.body)))
    =/  rec-acfg=(unit alias-cfg)                  (mole |.(;;(alias-cfg +>+>+>+>-.body)))
    =/  rec-secret=(unit @)                        (mole |.(;;(@ +>+>+>+>+<.body)))
    ?:  ?&(?=(^ rec-domain) ?=(^ rec-wl) ?=(^ rec-aliases))
      ~&  >  '%mail-gateway: PARTIAL RECOVERY — domain={<u.rec-domain>}, {<~(wyt by u.rec-wl)>} ships, {<~(wyt by u.rec-aliases)>} aliases'
      =/  gw-card=card  [%pass /set-gw %agent [our.bowl %mail-client] %poke %mail-action !>(`action`[%set-is-gateway %.y])]
      :_  this(domain u.rec-domain, whitelist u.rec-wl, aliases u.rec-aliases, alias-config (fall rec-acfg [%.n 5 10 5 %.n '' 5.000.000.000.000.000 '']), invite-secret (fall rec-secret 0), auto-approve %.n, enabled %.y, out-log ~, public %.y, pending-payments ~)
      ~[gw-card]
    ~&  >>>  '%mail-gateway: recovery FAILED — reinitializing'
    on-init
  ?-  -.u.parsed
      %9
    =/  gw-card=card  [%pass /set-gw %agent [our.bowl %mail-client] %poke %mail-action !>(`action`[%set-is-gateway enabled.+.u.parsed])]
    :_  this(state +.u.parsed)
    ~[gw-card]
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  |^
  ::  handle restore-from-json poke (from mail-client backup restore)
  ?:  ?&  =(%noun mark)
          ?=(^ (mole |.(;;([%restore-from-json @] q.vase))))
      ==
    ^-  (quip card _this)
    ?.  =(our.bowl src.bowl)  `this
    =/  json-cord=@t  ;;(@t +.q.vase)
    =/  parsed  (de:json:html json-cord)
    ?~  parsed
      ~&  >>>  'mail-gateway: restore JSON parse failed'
      `this
    ?.  ?=([%o *] u.parsed)  `this
    =/  o  p.u.parsed
    =,  dejs:format
    =/  new-domain=@t  (fall (bind (~(get by o) 'domain') so) domain)
    =/  new-auto=?  (fall (bind (~(get by o) 'auto-approve') bo) auto-approve)
    =/  new-enabled=?  (fall (bind (~(get by o) 'enabled') bo) enabled)
    =/  new-public=?  (fall (bind (~(get by o) 'public') bo) public)
    ::  restore whitelist
    =/  new-wl=(map @p wl-entry)
      ?~  w=(~(get by o) 'whitelist')  whitelist
      ?.  ?=([%o *] u.w)  whitelist
      %-  ~(gas by *(map @p wl-entry))
      %+  murn  ~(tap by p.u.w)
      |=  [k=@t v=json]
      ^-  (unit [@p wl-entry])
      =/  ship  (mole |.((slav %p k)))
      ?~  ship  ~
      ?.  ?=([%o *] v)  ~
      =/  st-cord=@t  (fall (bind (~(get by p.v) 'status') so) 'approved')
      =/  st=wl-status
        ?+  st-cord  %approved
          %'pending'   %pending
          %'approved'  %approved
          %'rejected'  %rejected
        ==
      `[u.ship [st 0 0 now.bowl]]
    ::  restore aliases
    =/  new-aliases=(map @t alias-entry)
      ?~  a=(~(get by o) 'aliases')  aliases
      ?.  ?=([%o *] u.a)  aliases
      %-  ~(gas by *(map @t alias-entry))
      %+  murn  ~(tap by p.u.a)
      |=  [name=@t v=json]
      ^-  (unit [@t alias-entry])
      ?.  ?=([%o *] v)  ~
      =/  owner  (mole |.((slav %p (so (~(got by p.v) 'owner')))))
      ?~  owner  ~
      =/  st-cord=@t  (fall (bind (~(get by p.v) 'status') so) 'active')
      =/  st=alias-status
        ?+  st-cord  %active
          %'active'    %active
          %'disabled'  %disabled
          %'blocked'   %blocked
          %'reserved'  %reserved
        ==
      =/  created=@da  (fall (mole |.((slav %da (so (~(got by p.v) 'created'))))) now.bowl)
      =/  inv=@t  (fall (bind (~(get by p.v) 'invite-code') so) '')
      `[name [u.owner st created inv]]
    ::  restore alias-config
    =/  new-acfg=alias-cfg
      ?~  c=(~(get by o) 'alias-config')  alias-config
      ?.  ?=([%o *] u.c)  alias-config
      =/  co  p.u.c
      :*  (fall (bind (~(get by co) 'aliases-enabled') bo) aliases-enabled.alias-config)
          (fall (bind (~(get by co) 'min-len') ni) min-len.alias-config)
          (fall (bind (~(get by co) 'free-min-len') ni) free-min-len.alias-config)
          (fall (bind (~(get by co) 'free-limit') ni) free-limit.alias-config)
          (fall (bind (~(get by co) 'payment-enabled') bo) payment-enabled.alias-config)
          (fall (bind (~(get by co) 'payment-wallet') so) payment-wallet.alias-config)
          (fall (bind (~(get by co) 'base-price') ni) base-price.alias-config)
          (fall (bind (~(get by co) 'etherscan-key') so) etherscan-key.alias-config)
      ==
    ~&  >  'mail-gateway: RESTORED from backup — {<~(wyt by new-wl)>} ships, {<~(wyt by new-aliases)>} aliases'
    =.  domain        new-domain
    =.  whitelist     new-wl
    =.  aliases       new-aliases
    =.  alias-config  new-acfg
    =.  auto-approve  new-auto
    =.  enabled       new-enabled
    =.  public        new-public
    :_  this
    :~  [%pass /set-gw %agent [our.bowl %mail-client] %poke %mail-action !>(`action`[%set-is-gateway new-enabled])]
    ==
  ~&  >  'mail-gateway: poke from {<src.bowl>} mark={<mark>}'
  ?+  mark  `this
    ::  %mail-message: core relay logic
    ::
      %mail-message
    =/  msg  !<(message vase)
    ::  determine direction based on recipient type
    ::
    ?:  ?=([%urbit *] to.msg)
      ::  inbound: relay to target ship as receive-labeled with recv-addr
      ::  block delivery to comets (128-bit @p) — only internal urbit mail
      ?:  (is-comet:mc p.to.msg)
        ~&  >>>  'mail-gateway: rejected delivery to comet {<p.to.msg>}'
        `this
      ~&  >  'mail-gateway: relaying inbound to {<p.to.msg>}'
      =/  wl-e  (~(get by whitelist) p.to.msg)
      =?  whitelist  ?=(^ wl-e)
        (~(put by whitelist) p.to.msg u.wl-e(in +(in.u.wl-e)))
      =/  recv-addr=@t
        ?:  =('' domain)  ''
        (crip (weld (slag 1 (scow %p p.to.msg)) (weld "@" (trip domain))))
      =/  act=action  [%receive-labeled msg ~ recv-addr]
      :_  this
      :~  [%pass /relay/(scot %uv id.msg) %agent [p.to.msg %mail-client] %poke %mail-action !>(act)]
      ==
    ::  outbound or alias: recipient is external address (type narrowed by branch above)
    ::
    ::  check if this is an alias lookup from bridge (local poke with ext address)
    ?.  =(our.bowl src.bowl)
      =/  auth  (check-outbound-auth src.bowl)
      ?.  ok.auth  `this
      =.  whitelist  wl.auth
      ~&  >  'mail-gateway: queuing outbound for bridge'
      :_  this(pending (~(put in pending) id.msg), out-log [now.bowl (scag 3.000 (skim out-log |=(d=@da (gth d (sub now.bowl ~d30)))))])
      :~  [%give %fact ~[/outbound] %mail-message !>(msg)]
      ==
    ::  local poke — check if this is an alias inbound from bridge
    =/  addr=tape  (trip p.to.msg)
    =/  local=tape
      =/  at  (find "@" addr)
      ?~  at  addr
      (scag u.at addr)
    =/  local-cord=@t  (crip local)
    =/  alias-ent  (~(get by aliases) local-cord)
    ?:  ?&  ?=(^ alias-ent)
            =(%active status.u.alias-ent)
            aliases-enabled.alias-config
        ==
      ::  resolve alias to owner ship and relay inbound
      ~&  >  'mail-gateway: alias {local} → {<owner.u.alias-ent>}'
      =/  resolved-msg=message  msg(to [%urbit owner.u.alias-ent])
      =/  recv-addr=@t
        ?:  =('' domain)  ''
        (crip (weld local (weld "@" (trip domain))))
      =/  act=action  [%receive-labeled resolved-msg ~ recv-addr]
      :_  this
      :~  [%pass /relay/(scot %uv id.msg) %agent [owner.u.alias-ent %mail-client] %poke %mail-action !>(act)]
      ==
    ::  not an alias — queue for bridge as outbound
    ~&  >  'mail-gateway: queuing outbound for bridge'
    :_  this(pending (~(put in pending) id.msg), out-log [now.bowl (scag 3.000 (skim out-log |=(d=@da (gth d (sub now.bowl ~d30)))))])
    :~  [%give %fact ~[/outbound] %mail-message !>(msg)]
    ==
    ::  %mail-action: labeled message from Python bridge, forward to target
    ::
      %mail-action
    =/  act  !<(action vase)
    ?.  =(our.bowl src.bowl)  `this
    ?.  ?=(%receive-labeled -.act)  `this
    =*  msg  msg.act
    ::  resolve alias if to is external
    ?:  ?=([%ext *] to.msg)
      =/  addr=tape  (trip p.to.msg)
      =/  local=tape
        =/  at  (find "@" addr)
        ?~  at  addr
        (scag u.at addr)
      ::  strip labels from alias: xezol.spam → xezol
      =/  alias-name=tape
        =/  dot  (find "." local)
        ?~  dot  local
        (scag u.dot local)
      =/  alias-ent  (~(get by aliases) (crip alias-name))
      ?.  ?&(?=(^ alias-ent) =(%active status.u.alias-ent) aliases-enabled.alias-config)
        ~&  >>>  'mail-gateway: alias {alias-name} not found or disabled'
        `this
      ~&  >  'mail-gateway: labeled alias {alias-name} → {<owner.u.alias-ent>}'
      =/  resolved-msg=message  msg(to [%urbit owner.u.alias-ent])
      =/  recv-addr=@t
        ?:  =('' domain)  ''
        (crip (weld local (weld "@" (trip domain))))
      =/  fwd-act=action  [%receive-labeled resolved-msg labels.act recv-addr]
      :_  this
      :~  [%pass /relay/(scot %uv id.msg) %agent [owner.u.alias-ent %mail-client] %poke %mail-action !>(fwd-act)]
      ==
    ~&  >  'mail-gateway: relaying labeled inbound to {<p.to.msg>}'
    ::  increment in counter
    =/  wl-e  (~(get by whitelist) p.to.msg)
    =?  whitelist  ?=(^ wl-e)
      (~(put by whitelist) p.to.msg u.wl-e(in +(in.u.wl-e)))
    ::  ensure recv-addr is filled
    =/  ra=@t
      ?:  !=('' recv-addr.act)  recv-addr.act
      ?:  =('' domain)  ''
      (crip (weld (slag 1 (scow %p p.to.msg)) (weld "@" (trip domain))))
    =/  fwd=action  [%receive-labeled msg labels.act ra]
    :_  this
    :~  [%pass /relay/(scot %uv id.msg) %agent [p.to.msg %mail-client] %poke %mail-action !>(fwd)]
    ==
    ::  %mail-gateway-action: bridge confirmations and admin
    ::
      %mail-gateway-action
    =/  act  !<(gateway-action vase)
    ?-  -.act
        %delivered
      ?.  =(our.bowl src.bowl)  `this
      ~&  >  'mail-gateway: bridge confirmed delivery of {<id.act>}'
      `this(pending (~(del in pending) id.act))
      ::
        %delivery-failed
      ?.  =(our.bowl src.bowl)  `this
      ~&  >>>  'mail-gateway: delivery failed'
      =.  pending  (~(del in pending) id.act)
      =/  orig-id=tape  (trip (scot %uv id.act))
      =/  human-reason=tape
        =/  raw=tape  (trip reason.act)
        ?:  !=(~ (find "401" raw))  "Authentication error on the gateway. The administrator has been notified."
        ?:  !=(~ (find "429" raw))  "Too many outgoing messages. Please try again in an hour."
        ?:  !=(~ (find "402" raw))  "Gateway email quota exceeded for today. Try again tomorrow."
        ?:  !=(~ (find "Rate limit" raw))  "You have reached the per-user sending limit. Try again later."
        ?:  !=(~ (find "500" raw))  "Email service temporarily unavailable. Try again later."
        "Delivery failed due to a temporary issue. Try again later."
      =/  bounce-body=@t  (crip "Your message could not be delivered.\0a\0a{human-reason}\0a\0a[View the original message](/mail/read?id={orig-id})")
      =/  bounce-msg=message
        :*  (sham [id.act now.bowl %bounce])
            [%urbit our.bowl]
            [%urbit ship.act]
            ~  ~
            'Delivery failed'
            bounce-body
            now.bowl  ~
        ==
      =/  admin-msg=message
        :*  (sham [id.act now.bowl %admin-bounce])
            [%urbit ship.act]
            [%urbit our.bowl]
            ~  ~
            (crip "Delivery failed: {(scow %p ship.act)}")
            (crip "{human-reason}")
            now.bowl  ~
        ==
      :_  this
      :~  [%pass /bounce/(scot %uv id.act) %agent [ship.act %mail-client] %poke %mail-message !>(bounce-msg)]
          [%pass /send-fail/(scot %uv id.act) %agent [ship.act %mail-client] %poke %mail-action !>(`action`[%send-failed id.act reason.act])]
          [%pass /admin-bounce/(scot %uv id.act) %agent [our.bowl %mail-client] %poke %mail-action !>(`action`[%receive-labeled admin-msg (silt ~[%delivery-fail]) ''])]
      ==
      ::
        %set-domain
      ?.  =(our.bowl src.bowl)  `this
      ~&  >  'mail-gateway: domain set to {(trip domain.act)}'
      =.  domain  domain.act
      :_  this
      :~  [%give %fact ~[/info] %noun !>([domain.act aliases-enabled.alias-config min-len.alias-config free-min-len.alias-config base-price.alias-config payment-enabled.alias-config])]
      ==
      ::
        %send-labeled
      =*  msg  msg.act
      ::  bypass whitelist for local pokes
      ?.  =(our.bowl src.bowl)
        =/  auth  (check-outbound-auth src.bowl)
        ?.  ok.auth  `this
        =.  whitelist  wl.auth
        ::  validate sendas: labels — only allow aliases owned by sender
        =/  valid-labels=(list @tas)
          %+  skim  labels.act
          |=  l=@tas
          =/  lt=tape  (trip l)
          ?.  =("sendas:" (scag 7 lt))  %.y  ::  keep non-sendas labels
          =/  alias-name=@t  (crip (slag 7 lt))
          =/  ent  (~(get by aliases) alias-name)
          ?~  ent  %.n  ::  drop: alias not found
          =(owner.u.ent src.bowl)  ::  keep only if sender owns alias
        (relay-labeled msg valid-labels)
      (relay-labeled msg labels.act)
      ::
        %request-access
      ::  block comets from gateway access
      ?:  (is-comet:mc src.bowl)
        ~&  >>>  'mail-gateway: rejected comet {<src.bowl>}'
        `this
      ::  always auto-approve self (gateway's own mail-client)
      ?:  =(our.bowl src.bowl)
        ~&  >  'mail-gateway: auto-approving self'
        =.  whitelist  (~(put by whitelist) src.bowl [%approved 0 0 now.bowl])
        :_  this
        :~  [%pass /access-resp/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%access-response %approved])]
            reg-update-card
        ==
      ~&  >  'mail-gateway: access request from {<src.bowl>}'
      =/  existing  (~(get by whitelist) src.bowl)
      ?^  existing
        ::  already in whitelist — re-send current status and aliases to client
        ~&  >  'mail-gateway: {<src.bowl>} already in whitelist as {<status.u.existing>}'
        ?:  ?=(%pending status.u.existing)  `this
        :_  this
        :~  [%pass /access-resp/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%access-response status.u.existing])]
            (notify-alias src.bowl aliases)
        ==
      ::  auto-approve if ship has active/disabled aliases on this gateway
      =/  has-aliases=?
        %+  lien  ~(tap by aliases)
        |=  [* ent=alias-entry]
        ?&  =(owner.ent src.bowl)
            ?|  =(%active status.ent)
                =(%disabled status.ent)
            ==
        ==
      ?:  ?|(auto-approve has-aliases)
        ~&  >  'mail-gateway: auto-approving {<src.bowl>}{?:(has-aliases " (has aliases)" "")}'
        =.  whitelist  (~(put by whitelist) src.bowl [%approved 0 0 now.bowl])
        :_  this
        :~  [%pass /access-resp/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%access-response %approved])]
            (notify-alias src.bowl aliases)
            reg-update-card
        ==
      `this(whitelist (~(put by whitelist) src.bowl [%pending 0 0 now.bowl]))
      ::
        %approve-access
      ?.  =(our.bowl src.bowl)  `this
      ?.  (~(has by whitelist) ship.act)  `this
      =/  wl-e  (~(got by whitelist) ship.act)
      ~&  >  'mail-gateway: approved access for {<ship.act>}'
      =.  whitelist  (~(put by whitelist) ship.act wl-e(status %approved))
      :_  this
      :~  [%pass /access-resp/(scot %p ship.act) %agent [ship.act %mail-client] %poke %mail-action !>(`action`[%access-response %approved])]
          (notify-alias ship.act aliases)
          reg-update-card
      ==
      ::
        %reject-access
      ?.  =(our.bowl src.bowl)  `this
      ?.  (~(has by whitelist) ship.act)  `this
      =/  wl-e  (~(got by whitelist) ship.act)
      ~&  >  'mail-gateway: rejected access for {<ship.act>}'
      :_  this(whitelist (~(put by whitelist) ship.act wl-e(status %rejected)))
      :~  [%pass /access-resp/(scot %p ship.act) %agent [ship.act %mail-client] %poke %mail-action !>(`action`[%access-response %rejected])]
      ==
      ::
        %remove-access
      ?.  =(our.bowl src.bowl)  `this
      ~&  >  'mail-gateway: removed access for {<ship.act>}'
      =.  whitelist  (~(del by whitelist) ship.act)
      :_  this
      :~  [%pass /access-resp/(scot %p ship.act) %agent [ship.act %mail-client] %poke %mail-action !>(`action`[%access-response %rejected])]
          reg-update-card
      ==
      ::
        %add-to-whitelist
      ?.  =(our.bowl src.bowl)  `this
      ~&  >  'mail-gateway: manually added {<ship.act>} to whitelist'
      =.  whitelist  (~(put by whitelist) ship.act [%approved 0 0 now.bowl])
      :_  this
      :~  [%pass /access-resp/(scot %p ship.act) %agent [ship.act %mail-client] %poke %mail-action !>(`action`[%access-response %approved])]
          reg-update-card
      ==
      ::
        %set-auto-approve
      ?.  =(our.bowl src.bowl)  `this
      ~&  >  'mail-gateway: auto-approve set to {<auto.act>}'
      =.  auto-approve  auto.act
      :_  this
      ~[reg-update-card]
      ::
        %set-enabled
      ?.  =(our.bowl src.bowl)  `this
      ::  disabling — always allowed
      ?.  enabled.act
        ~&  >  'mail-gateway: disabled'
        =.  enabled  %.n
        :_  this
        :~  [%pass /set-gw %agent [our.bowl %mail-client] %poke %mail-action !>(`action`[%set-is-gateway %.n])]
            reg-update-card
        ==
      ::  enabling — requires domain with DNS verification
      ?:  =('' domain)
        ~&  >>>  'mail-gateway: cannot enable without a domain. Set domain first.'
        `this
      =/  url=@t
        %-  crip
        ;:  weld
          "https://dns.google/resolve?name=_urbit-gw."
          (trip domain)
          "&type=TXT"
        ==
      ~&  >  'mail-gateway: verifying DNS before enabling...'
      :_  this
      :~  [%pass /dns-enable %arvo %i %request [%'GET' url ~ ~] *outbound-config:iris]
      ==
      ::
        %set-public
      ?.  =(our.bowl src.bowl)  `this
      ~&  >  'mail-gateway: public set to {<public.act>}'
      =.  public  public.act
      :_  this
      ?:  public.act
        ::  going public — register in registry
        ~[reg-update-card]
      ::  going private — unregister from registry
      :~  [%pass /reg-update %agent [default-registry %mail-registry] %poke %mail-registry-action !>(`registry-action`[%unregister ~])]
      ==
      ::  === ALIAS ACTIONS ===
      ::
        %request-alias
      ?:  (is-comet:mc src.bowl)
        ~&  >>>  'mail-gateway: comets cannot register aliases'
        `this
      ?.  aliases-enabled.alias-config
        ~&  >>>  'mail-gateway: aliases disabled on this gateway'
        `this
      =/  a=@t  alias.act
      ~&  >  'mail-gateway: request-alias: raw={<a>} len={<(met 3 a)>} valid={<(validate-alias a)>}'
      ?.  (validate-alias a)
        ~&  >>>  'mail-gateway: invalid alias format'
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Invalid alias: only a-z, 0-9, hyphen, underscore. Cannot match a ship name.'])]
        ==
      ?:  (lth (met 3 a) min-len.alias-config)
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error (crip (weld "Alias too short (min " (weld (a-co:co min-len.alias-config) " chars)")))])]
        ==
      ?:  (~(has in reserved-aliases) a)
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Alias name is reserved'])]
        ==
      ?:  (~(has by aliases) a)
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Alias already taken'])]
        ==
      ?:  (~(has by pending-payments) a)
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Alias is reserved for pending purchase'])]
        ==
      =/  count=@ud  (count-ship-aliases aliases src.bowl)
      ?:  (gte count free-limit.alias-config)
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Free alias limit reached'])]
        ==
      ?:  (lth (met 3 a) free-min-len.alias-config)
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Alias too short for free registration. Use an invite code.'])]
        ==
      ~&  >  'mail-gateway: alias {(trip a)} registered to {<src.bowl>}'
      =.  aliases  (~(put by aliases) a [src.bowl %active now.bowl ''])
      :_  this
      :~  (notify-alias src.bowl aliases)
      ==
      ::
        %disable-alias
      =/  ent  (~(get by aliases) alias.act)
      ?~  ent
        ~&  >>>  'mail-gateway: alias not found'
        `this
      ?.  =(owner.u.ent src.bowl)
        ~&  >>>  'mail-gateway: not your alias'
        `this
      ?.  =(%active status.u.ent)
        ~&  >>>  'mail-gateway: alias is not active'
        `this
      ~&  >  'mail-gateway: alias {(trip alias.act)} disabled'
      =.  aliases  (~(put by aliases) alias.act u.ent(status %disabled))
      :_  this
      :~  (notify-alias src.bowl aliases)
      ==
      ::
        %enable-alias
      =/  ent  (~(get by aliases) alias.act)
      ?~  ent
        ~&  >>>  'mail-gateway: alias not found'
        `this
      ?.  =(owner.u.ent src.bowl)
        ~&  >>>  'mail-gateway: not your alias'
        `this
      ?.  =(%disabled status.u.ent)
        ~&  >>>  'mail-gateway: alias is not disabled (status: {<status.u.ent>})'
        `this
      ~&  >  'mail-gateway: alias {(trip alias.act)} re-enabled'
      =.  aliases  (~(put by aliases) alias.act u.ent(status %active))
      :_  this
      :~  (notify-alias src.bowl aliases)
      ==
      ::
        %block-alias
      ?.  =(our.bowl src.bowl)  `this
      =/  ent  (~(get by aliases) alias.act)
      ?~  ent
        ~&  >>>  'mail-gateway: alias not found'
        `this
      ~&  >  'mail-gateway: alias {(trip alias.act)} blocked by admin'
      =.  aliases  (~(put by aliases) alias.act u.ent(status %blocked))
      :_  this
      :~  (notify-alias owner.u.ent aliases)
      ==
      ::
        %unblock-alias
      ?.  =(our.bowl src.bowl)  `this
      =/  ent  (~(get by aliases) alias.act)
      ?~  ent
        ~&  >>>  'mail-gateway: alias not found'
        `this
      ?.  =(%blocked status.u.ent)
        ~&  >>>  'mail-gateway: alias is not blocked'
        `this
      ~&  >  'mail-gateway: alias {(trip alias.act)} unblocked'
      =.  aliases  (~(put by aliases) alias.act u.ent(status %active))
      :_  this
      :~  (notify-alias owner.u.ent aliases)
      ==
      ::
        %unreserve-alias
      ?.  =(our.bowl src.bowl)  `this
      =/  ent  (~(get by aliases) alias.act)
      ?~  ent
        ~&  >>>  'mail-gateway: alias not found'
        `this
      ?.  =(%reserved status.u.ent)
        ~&  >>>  'mail-gateway: alias is not reserved'
        `this
      ~&  >  'mail-gateway: alias {(trip alias.act)} unreserved'
      `this(aliases (~(del by aliases) alias.act))
      ::
        %redeem-invite
      ~&  >  'mail-gateway: redeem-invite from {<src.bowl>} code={<code.act>}'
      ?.  aliases-enabled.alias-config
        ~&  >>>  'mail-gateway: aliases disabled on this gateway'
        `this
      ?:  =(0 invite-secret)
        ~&  >>>  'mail-gateway: invite system not initialized'
        `this
      ::  parse code format: alias@~gateway:signature-base64
      =/  code-tape=tape  (trip code.act)
      =/  colon-idx  (find ":" code-tape)
      ?~  colon-idx
        ~&  >>>  'mail-gateway: invalid invite code format (no colon separator)'
        `this
      =/  prefix=tape  (scag u.colon-idx code-tape)
      =/  sig-b64=@t  (crip (slag +(u.colon-idx) code-tape))
      ::  extract alias from prefix (everything before @)
      =/  at-idx  (find "@" prefix)
      ?~  at-idx
        ~&  >>>  'mail-gateway: invalid invite code format (no @ in prefix)'
        `this
      =/  a=@t  (crip (scag u.at-idx prefix))
      ::  decode and verify HMAC signature
      =/  sig-decoded=(unit octs)  (de-base64url sig-b64)
      ?~  sig-decoded
        ~&  >>>  'mail-gateway: invalid invite code signature encoding'
        `this
      =/  sig=@  q.u.sig-decoded
      =/  alias-len=@ud  (met 3 a)
      =/  expected-sig=@  (extract:hkdf [32 invite-secret] [alias-len `@`a])
      ?.  =(sig expected-sig)
        ~&  >>>  'mail-gateway: invalid invite code signature'
        `this
      ::  code is valid — check alias status
      =/  existing  (~(get by aliases) a)
      ?^  existing
        ?.  =(%reserved status.u.existing)
          ~&  >>>  'mail-gateway: alias {(trip a)} already taken'
          `this
        ::  reserved alias — activate for redeemer (cancel any pending purchase)
        ::  auto-approve ship if not already in whitelist
        =/  wl-ent  (~(get by whitelist) src.bowl)
        =?  whitelist  ?|(?=(~ wl-ent) !=(%approved status.u.wl-ent))
          (~(put by whitelist) src.bowl [%approved 0 0 now.bowl])
        ~&  >  'mail-gateway: invite redeemed — alias {(trip a)} registered to {<src.bowl>}'
        =.  aliases  (~(put by aliases) a [src.bowl %active now.bowl ''])
        =.  pending-payments  (~(del by pending-payments) a)
        =/  approve-card=card
          [%pass /access-resp/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%access-response %approved])]
        :_  this
        :~  (notify-alias src.bowl aliases)
            approve-card
        ==
      ::  not reserved (shouldn't happen with generate flow, but handle gracefully)
      =/  wl-ent  (~(get by whitelist) src.bowl)
      =?  whitelist  ?|(?=(~ wl-ent) !=(%approved status.u.wl-ent))
        (~(put by whitelist) src.bowl [%approved 0 0 now.bowl])
      ~&  >  'mail-gateway: invite redeemed — alias {(trip a)} registered to {<src.bowl>}'
      =.  aliases  (~(put by aliases) a [src.bowl %active now.bowl ''])
      =.  pending-payments  (~(del by pending-payments) a)
      =/  approve-card=card
        [%pass /access-resp/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%access-response %approved])]
      :_  this
      :~  (notify-alias src.bowl aliases)
          approve-card
      ==
      ::
        %generate-invite
      ?.  =(our.bowl src.bowl)  `this
      ::  initialize secret if needed
      =?  invite-secret  =(0 invite-secret)
        `@`(sham [eny.bowl now.bowl our.bowl])
      =/  a=@t  alias.act
      ?.  (validate-alias a)
        ~&  >>>  'mail-gateway: invalid alias format'
        `this
      ?:  (~(has by aliases) a)
        ~&  >>>  'mail-gateway: alias {(trip a)} already taken or reserved'
        `this
      ?:  (~(has by pending-payments) a)
        ~&  >>>  'mail-gateway: alias {(trip a)} has pending purchase'
        `this
      ::  generate HMAC signature
      =/  alias-len=@ud  (met 3 a)
      =/  sig=@  (extract:hkdf [32 invite-secret] [alias-len `@`a])
      =/  sig-octs=octs  [32 sig]
      =/  sig-b64=@t  (en-base64url sig-octs)
      ::  format: alias@~gateway:signature
      =/  code=@t
        %-  crip
        ;:  weld
          (trip a)
          "@"
          (scow %p our.bowl)
          ":"
          (trip sig-b64)
        ==
      ::  reserve alias with invite code stored
      =.  aliases  (~(put by aliases) a [our.bowl %reserved now.bowl code])
      ~&  >>  'mail-gateway: invite code for alias {(trip a)}:'
      ~&  >>  code
      `this
      ::
        %set-alias-config
      ?.  =(our.bowl src.bowl)  `this
      ~&  >  'mail-gateway: alias config updated'
      :_  this(alias-config cfg.act)
      :~  [%give %fact ~[/info] %noun !>([domain aliases-enabled.cfg.act min-len.cfg.act free-min-len.cfg.act base-price.cfg.act payment-enabled.cfg.act])]
      ==
      ::  === PAYMENT ACTIONS ===
      ::
        %request-paid-alias
      ?:  (is-comet:mc src.bowl)
        ~&  >>>  'mail-gateway: comets cannot purchase aliases'
        `this
      ?.  aliases-enabled.alias-config
        ~&  >>>  'mail-gateway: aliases disabled'
        `this
      ?.  payment-enabled.alias-config
        ~&  >>>  'mail-gateway: payment disabled'
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Paid aliases are not enabled on this gateway'])]
        ==
      =/  a=@t  alias.act
      ?.  (validate-alias a)
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Invalid alias format'])]
        ==
      ?:  (lth (met 3 a) min-len.alias-config)
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error (crip (weld "Alias too short (min " (weld (a-co:co min-len.alias-config) " chars)")))])]
        ==
      ?:  (~(has in reserved-aliases) a)
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Alias name is reserved'])]
        ==
      ?:  (~(has by aliases) a)
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Alias already taken'])]
        ==
      ::  if same ship has pending payment for this alias, allow overwrite
      ?:  ?&  (~(has by pending-payments) a)
              !=(src.bowl ship:(~(got by pending-payments) a))
          ==
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Alias is reserved for pending purchase'])]
        ==
      ::  must be shorter than free-min-len (otherwise just request free)
      ?:  (gte (met 3 a) free-min-len.alias-config)
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'This alias is long enough for free registration'])]
        ==
      ::  price = base-price * 2^(free-min-len - alias-len - 1)
      ::  shorter aliases cost exponentially more
      =/  alias-len=@ud  (met 3 a)
      =/  exp=@ud  (sub free-min-len.alias-config +(alias-len))
      =/  multiplier=@ud  (bex exp)
      =/  tier-price=@ud  (mul base-price.alias-config multiplier)
      ::  truncate to 0.0001 ETH precision (10^14 wei)
      =/  truncated=@ud  (mul (div tier-price 100.000.000.000.000) 100.000.000.000.000)
      ::  random 5 digits at decimal positions 5-9: 0.0000yyyyy
      =/  random=@ud  (mod (sham [a now.bowl eny.bowl]) 100.000)
      =/  pay-amount=@ud  (add truncated (mul random 1.000.000.000))
      ~&  >  'mail-gateway: paid alias request {(trip a)} from {<src.bowl>} amount={<pay-amount>} wei'
      ::  clean expired pending payments (>24h)
      =.  pending-payments
        %-  ~(gas by *(map @t [alias=@t ship=@p amount=@ud created=@da]))
        %+  skim  ~(tap by pending-payments)
        |=  [k=@t v=[alias=@t ship=@p amount=@ud created=@da]]
        ?|  (lth now.bowl created.v)
            (lth (sub now.bowl created.v) ~d1)
        ==
      =.  pending-payments  (~(put by pending-payments) a [a src.bowl pay-amount now.bowl])
      :_  this
      :~  [%pass /payment-req/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%payment-request a pay-amount payment-wallet.alias-config])]
          [%pass /payment-timer %arvo %b %wait (add now.bowl ~s15)]
      ==
      ::
        %verify-payment
      =/  pp  (~(get by pending-payments) alias.act)
      ?~  pp
        ~&  >>>  'mail-gateway: no pending payment for alias {(trip alias.act)}'
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'No pending payment for this alias'])]
        ==
      ?.  =(ship.u.pp src.bowl)
        ~&  >>>  'mail-gateway: payment verification from wrong ship'
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'This payment request belongs to another ship'])]
        ==
      ::  check TTL (1 hour)
      ?:  ?&((gth now.bowl created.u.pp) (gth (sub now.bowl created.u.pp) ~h1))
        ~&  >>>  'mail-gateway: payment expired for alias {(trip alias.act)}'
        =.  pending-payments  (~(del by pending-payments) alias.act)
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Payment expired (1 hour limit). Request a new one.'])]
        ==
      ::  validate tx-hash format: must be 0x + 64 hex chars
      =/  tx-tape=tape  (trip tx-hash.act)
      ?.  ?&  =(66 (lent tx-tape))
              =('0' (snag 0 tx-tape))
              =('x' (snag 1 tx-tape))
              %+  levy  (slag 2 tx-tape)
              |=  c=@t
              ?|  &((gte c '0') (lte c '9'))
                  &((gte c 'a') (lte c 'f'))
              ==
          ==
        ~&  >>>  'mail-gateway: invalid tx-hash format'
        :_  this
        :~  [%pass /alias-err/(scot %p src.bowl) %agent [src.bowl %mail-client] %poke %mail-action !>(`action`[%alias-error 'Invalid transaction hash format'])]
        ==
      ::  send Etherscan API request to verify transaction
      =/  url=@t
        %-  crip
        ;:  weld
          "https://api.etherscan.io/v2/api?chainid=1&module=proxy&action=eth_getTransactionByHash&txhash="
          tx-tape
          "&apikey="
          (trip etherscan-key.alias-config)
        ==
      ~&  >  'mail-gateway: verifying tx {(trip tx-hash.act)} for alias {(trip alias.act)}'
      :_  this
      :~  [%pass /etherscan/(scot %t alias.act)/(scot %t tx-hash.act) %arvo %i %request [%'GET' url ~ ~] *outbound-config:iris]
      ==
      ::
        %cancel-payment
      =/  pp  (~(get by pending-payments) alias.act)
      ?~  pp
        ~&  >>>  'mail-gateway: no pending payment for alias {(trip alias.act)}'
        `this
      ?.  =(ship.u.pp src.bowl)
        ~&  >>>  'mail-gateway: cancel-payment from wrong ship'
        `this
      ~&  >  'mail-gateway: payment cancelled for alias {(trip alias.act)} by {<src.bowl>}'
      =.  pending-payments  (~(del by pending-payments) alias.act)
      `this
      ::
        %check-payments
      ?.  =(our.bowl src.bowl)  `this
      ::  clean expired pending payments first
      =.  pending-payments
        %-  ~(gas by *(map @t pending-payment))
        %+  skim  ~(tap by pending-payments)
        |=  [* pp=pending-payment]
        ?|  (lth now.bowl created.pp)
            (lth (sub now.bowl created.pp) ~h1)
        ==
      ::  skip if no pending payments or no payment config
      ?.  ?&  !=(~ pending-payments)
              payment-enabled.alias-config
              !=('' etherscan-key.alias-config)
              !=('' payment-wallet.alias-config)
          ==
        `this
      ::  rate limit: max 1 check per 5 seconds (use last-check marker in wire)
      =/  url=@t
        %-  crip
        ;:  weld
          "https://api.etherscan.io/v2/api?chainid=1&module=account&action=txlist&address="
          (trip payment-wallet.alias-config)
          "&startblock=0&endblock=99999999&sort=desc&page=1&offset=50&apikey="
          (trip etherscan-key.alias-config)
        ==
      :_  this
      :~  [%pass /txlist-check %arvo %i %request [%'GET' url ~ ~] *outbound-config:iris]
      ==
      ::
        %set-payment-config
      ?.  =(our.bowl src.bowl)  `this
      ::  truncate price to 0.0001 ETH (10^14 wei) precision
      =/  truncated-price=@ud  (mul (div price.act 100.000.000.000.000) 100.000.000.000.000)
      =/  final-price=@ud  (max truncated-price 100.000.000.000.000)
      ~&  >  'mail-gateway: payment config updated, base-price={<final-price>} wei'
      `this(alias-config alias-config(payment-enabled enabled.act, payment-wallet wallet.act, base-price final-price, etherscan-key key.act))
    ==
  ==
  ::
  ++  notify-alias
    |=  [ship=@p als=(map @t alias-entry)]
    ^-  card
    =/  ship-aliases=(list [@t ?])
      %+  murn  ~(tap by als)
      |=  [name=@t ent=alias-entry]
      ?.  =(owner.ent ship)  ~
      ?.  ?|  =(%active status.ent)
              =(%disabled status.ent)
          ==
        ~
      `[name =(%active status.ent)]
    [%pass /alias-notify/(scot %p ship) %agent [ship %mail-client] %poke %mail-action !>(`action`[%alias-update our.bowl ship-aliases])]
  ::
  ++  en-base64url
    |=  dat=octs
    ^-  @t
    (~(en base64:mimes:html | &) dat)
  ::
  ++  de-base64url
    |=  t=@t
    ^-  (unit octs)
    (~(de base64:mimes:html | &) t)
  ::
  ++  relay-labeled
    |=  [msg=message labels=(list @tas)]
    ^-  (quip card _this)
    ?.  ?=([%ext *] to.msg)  `this
    ~&  >  'mail-gateway: queuing labeled outbound {<id.msg>} for bridge'
    =/  msg-json=json
      =,  enjs:format
      %-  pairs
      :~  ['id' s+(scot %uv id.msg)]
          ['from' (contact-to-json:mc from.msg)]
          ['to' (contact-to-json:mc to.msg)]
          ['cc' [%a (turn cc.msg |=(c=contact (contact-to-json:mc c)))]]
          ['subject' s+subject.msg]
          ['body' s+body.msg]
          ['sent-at' s+(scot %da sent-at.msg)]
          ['labels' [%a (turn labels |=(l=@tas s+l))]]
      ==
    :_  this(pending (~(put in pending) id.msg))
    :~  [%give %fact ~[/outbound] %json !>(msg-json)]
    ==
  ::  check-outbound-auth: verify whitelist + increment out counter for remote sender
  ::  returns (unit _this) — ~ if authorized (with updated whitelist), [~ this] if rejected
  ::
  ++  check-outbound-auth
    |=  ship=@p
    ^-  [ok=? wl=(map @p wl-entry)]
    =/  wl-e  (~(get by whitelist) ship)
    ?~  wl-e  [%.n whitelist]
    ?.  =(%approved status.u.wl-e)  [%.n whitelist]
    [%.y (~(put by whitelist) ship u.wl-e(out +(out.u.wl-e)))]
  ::
  ++  reg-update-card
    ^-  card
    =/  user-count=@ud
      %-  ~(rep by whitelist)
      |=  [[* e=wl-entry] acc=@ud]
      ?:(=(%approved status.e) +(acc) acc)
    [%pass /reg-update %agent [default-registry %mail-registry] %poke %mail-registry-action !>(`registry-action`?:(public [%register domain auto-approve user-count] [%unregister ~]))]
  --
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  `this
    ::  /outbound: Python bridge subscribes for messages to send via email
    ::
      [%outbound ~]
    ?.  =(our.bowl src.bowl)
      :_  this
      ~[[%give %kick ~[path] `src.bowl]]
    ~&  >  'mail-gateway: bridge subscribed to /outbound'
    `this
    ::  /info: clients subscribe to get gateway config (domain)
    ::
      [%info ~]
    ~&  >  'mail-gateway: {<src.bowl>} subscribed to /info'
    :_  this
    :~  [%give %fact ~ %noun !>([domain aliases-enabled.alias-config min-len.alias-config free-min-len.alias-config base-price.alias-config payment-enabled.alias-config])]
    ==
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  ~
      [%x %installed ~]
    ``[%noun !>(%.y)]
    ::
      [%x %pending ~]
    ``[%noun !>(pending)]
    ::
      [%x %domain ~]
    ``[%noun !>(domain)]
    ::
      [%x %whitelist ~]
    ``[%noun !>(whitelist)]
    ::
      [%x %pending-count ~]
    =/  count=@ud
      %-  ~(rep by whitelist)
      |=  [[ship=@p entry=wl-entry] acc=@ud]
      ?:(=(%pending status.entry) +(acc) acc)
    ``[%noun !>(count)]
    ::
      [%x %auto-approve ~]
    ``[%noun !>(auto-approve)]
    ::
      [%x %enabled ~]
    ``[%noun !>(enabled)]
    ::
      [%x %public ~]
    ``[%noun !>(public)]
    ::
      [%x %aliases ~]
    ``[%noun !>(aliases)]
    ::
      [%x %alias-config ~]
    ``[%noun !>(alias-config)]
    ::
      [%x %aliases-enabled ~]
    ``[%noun !>(aliases-enabled.alias-config)]
    ::
      [%x %pending-payments ~]
    ?.  =(our.bowl src.bowl)  ~
    ``[%noun !>(pending-payments)]
    ::
      [%x %backup-json ~]
    ?.  =(our.bowl src.bowl)  ~
    =/  j=@t
      %-  en:json:html
      %-  pairs:enjs:format
      :~  ['domain' s+domain]
          ['auto-approve' b+auto-approve]
          ['enabled' b+enabled]
          ['public' b+public]
          ['invite-secret' s+'redacted']
          :-  'whitelist'
          %-  pairs:enjs:format
          %+  turn  ~(tap by whitelist)
          |=  [ship=@p e=wl-entry]
          :-  (scot %p ship)
          %-  pairs:enjs:format
          :~  ['status' s+(scot %tas status.e)]
              ['in' (numb:enjs:format in.e)]
              ['out' (numb:enjs:format out.e)]
          ==
          :-  'aliases'
          %-  pairs:enjs:format
          %+  turn  ~(tap by aliases)
          |=  [name=@t e=alias-entry]
          :-  name
          %-  pairs:enjs:format
          :~  ['owner' s+(scot %p owner.e)]
              ['status' s+(scot %tas status.e)]
              ['created' s+(scot %da created.e)]
              ['invite-code' s+invite-code.e]
          ==
          :-  'alias-config'
          %-  pairs:enjs:format
          :~  ['aliases-enabled' b+aliases-enabled.alias-config]
              ['min-len' (numb:enjs:format min-len.alias-config)]
              ['free-min-len' (numb:enjs:format free-min-len.alias-config)]
              ['free-limit' (numb:enjs:format free-limit.alias-config)]
              ['payment-enabled' b+payment-enabled.alias-config]
              ['payment-wallet' s+payment-wallet.alias-config]
              ['base-price' (numb:enjs:format base-price.alias-config)]
              ['etherscan-key' s+etherscan-key.alias-config]
          ==
      ==
    ``[%noun !>(j)]
    ::
      [%x %invite-secret ~]
    ?.  =(our.bowl src.bowl)  ~
    ``[%noun !>(invite-secret)]
    ::
      [%x %out-today ~]
    =/  day-start=@da  (sub now.bowl (mod now.bowl ~d1))
    =/  count=@ud
      %-  lent
      (skim out-log |=(d=@da (gte d day-start)))
    ``[%noun !>(count)]
    ::
      [%x %out-month ~]
    =/  month-start=@da  (sub now.bowl (mod now.bowl (mul ~d1 30)))
    =/  count=@ud
      %-  lent
      (skim out-log |=(d=@da (gte d month-start)))
    ``[%noun !>(count)]
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  ?+  wire  `this
      [%relay @ ~]
    =/  id  (slav %uv i.t.wire)
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign
        ~&  >  'mail-gateway: relayed {<id>} successfully'
        `this
      ~&  >>>  'mail-gateway: relay of {<id>} failed'
      `this
    ==
    ::
      [%access-resp @ ~]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign
        ~&  >  'mail-gateway: access response sent to {<i.t.wire>}'
        `this
      ~&  >>>  'mail-gateway: access response to {<i.t.wire>} failed'
      `this
    ==
    ::
      [%set-gw ~]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign
        ~&  >  'mail-gateway: notified %mail of gateway status'
        `this
      ~&  >>>  'mail-gateway: failed to notify %mail'
      `this
    ==
    ::
      [%reg-update ~]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign
        ~&  >  'mail-gateway: registry updated'
        `this
      ~&  >>>  'mail-gateway: registry update failed (registry may be disabled)'
      `this
    ==
    ::
      [%payment-req @ ~]
    ?+  -.sign  `this
        %poke-ack
      ?~  p.sign
        ~&  >  'mail-gateway: payment request sent to {<i.t.wire>}'
        `this
      ~&  >>>  'mail-gateway: payment request to {<i.t.wire>} failed'
      `this
    ==
    ::
      [%alias-err @ ~]
    ?+  -.sign  `this
        %poke-ack
      `this
    ==
  ==
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+  wire  `this
      [%payment-timer ~]
    ::  clean expired pending payments (>1h) before checking
    =.  pending-payments
      %-  ~(gas by *(map @t pending-payment))
      %+  skim  ~(tap by pending-payments)
      |=  [* pp=pending-payment]
      ?|  (lth now.bowl created.pp)
          (lth (sub now.bowl created.pp) ~h1)
      ==
    ::  timer fired — check for payments if any pending
    ?.  ?&  !=(~ pending-payments)
            payment-enabled.alias-config
            !=('' etherscan-key.alias-config)
            !=('' payment-wallet.alias-config)
        ==
      `this
    =/  url=@t
      %-  crip
      ;:  weld
        "https://api.etherscan.io/v2/api?chainid=1&module=account&action=txlist&address="
        (trip payment-wallet.alias-config)
        "&startblock=0&endblock=99999999&sort=desc&page=1&offset=50&apikey="
        (trip etherscan-key.alias-config)
      ==
    :_  this
    :~  [%pass /txlist-check %arvo %i %request [%'GET' url ~ ~] *outbound-config:iris]
    ==
    ::
      [%txlist-check ~]
    =/  retry-card=(list card)
      ?.  !=(~ pending-payments)  ~
      :~  [%pass /payment-timer %arvo %b %wait (add now.bowl ~s30)]
      ==
    ?.  ?=([%iris %http-response %finished *] sign-arvo)
      ~&  >>>  'mail-gateway: txlist check failed (no response)'
      [retry-card this]
    =/  dat  full-file.client-response.sign-arvo
    ?~  dat
      ~&  >>>  'mail-gateway: txlist check failed (empty body)'
      [retry-card this]
    =/  bod=octs  +.u.dat
    =/  body-cord=@t  q.bod
    =/  json-parsed  (de:json:html body-cord)
    ?~  json-parsed
      ~&  >>>  'mail-gateway: txlist check failed (bad JSON)'
      [retry-card this]
    |^
    =/  txs=(list [to=@t value=@ud])  (extract-txlist u.json-parsed)
    ::  match tx values against pending payments
    =/  cards=(list card)  ~
    =/  pps=(list [name=@t pp=pending-payment])  ~(tap by pending-payments)
    |-
    ?~  pps
      ::  reschedule timer if pending payments remain
      =/  timer-card=(list card)
        ?.  !=(~ pending-payments)  ~
        :~  [%pass /payment-timer %arvo %b %wait (add now.bowl ~s15)]
        ==
      [(weld cards timer-card) this]
    =/  name=@t  name.i.pps
    =/  pp=pending-payment  pp.i.pps
    ::  find tx with matching value (to wallet, value == expected amount)
    =/  found=?
      %+  lien  txs
      |=  [to=@t value=@ud]
      ?&  =((cass (trip to)) (cass (trip payment-wallet.alias-config)))
          =(value amount.pp)
      ==
    ?.  found  $(pps t.pps)
    ::  match found — activate alias
    ~&  >  'mail-gateway: auto-verified payment for alias {(trip name)}'
    =.  aliases  (~(put by aliases) name [ship.pp %active now.bowl ''])
    =.  pending-payments  (~(del by pending-payments) name)
    =/  ship-aliases=(list [@t ?])
      %+  murn  ~(tap by aliases)
      |=  [n=@t ent=alias-entry]
      ?.  =(owner.ent ship.pp)  ~
      ?.  ?|  =(%active status.ent)
              =(%disabled status.ent)
          ==
        ~
      `[n =(%active status.ent)]
    =/  notify-card=card
      [%pass /alias-notify/(scot %p ship.pp) %agent [ship.pp %mail-client] %poke %mail-action !>(`action`[%alias-update our.bowl ship-aliases])]
    $(pps t.pps, cards (snoc cards notify-card))
    ::
    ++  extract-txlist
      |=  j=json
      ^-  (list [to=@t value=@ud])
      ?.  ?=([%o *] j)  ~
      =/  res  (~(get by p.j) 'result')
      ?~  res  ~
      ?.  ?=([%a *] u.res)  ~
      ::  current unix time for 2-hour filter
      =/  now-unix=@ud  (div (sub now.bowl ~1970.1.1) ~s1)
      =/  cutoff=@ud  (sub now-unix 7.200)
      %+  murn  p.u.res
      |=  tx=json
      ^-  (unit [to=@t value=@ud])
      ?.  ?=([%o *] tx)  ~
      ::  filter: skip tx older than 2 hours
      =/  ts-json  (~(get by p.tx) 'timeStamp')
      ?~  ts-json  ~
      ?.  ?=([%s *] u.ts-json)  ~
      =/  ts=(unit @ud)  (mole |.((rash p.u.ts-json dem)))
      ?~  ts  ~
      ?.  (gte u.ts cutoff)  ~
      ::  extract to and value
      =/  to-json  (~(get by p.tx) 'to')
      ?~  to-json  ~
      ?.  ?=([%s *] u.to-json)  ~
      =/  val-json  (~(get by p.tx) 'value')
      ?~  val-json  ~
      ?.  ?=([%s *] u.val-json)  ~
      =/  val=(unit @ud)  (mole |.((rash p.u.val-json dem)))
      ?~  val  ~
      `[p.u.to-json u.val]
    --
    ::
      [%etherscan @ @ ~]
    =/  alias=@t  (slav %t i.t.wire)
    =/  tx-hash=@t  (slav %t i.t.t.wire)
    ?.  ?=([%iris %http-response %finished *] sign-arvo)
      ~&  >>>  'mail-gateway: Etherscan API call failed for alias {(trip alias)}'
      =/  pp  (~(get by pending-payments) alias)
      ?~  pp  `this
      :_  this
      :~  [%pass /alias-err/(scot %p ship.u.pp) %agent [ship.u.pp %mail-client] %poke %mail-action !>(`action`[%alias-error 'Payment verification failed — try again'])]
      ==
    =/  dat  full-file.client-response.sign-arvo
    ?~  dat
      ~&  >>>  'mail-gateway: Etherscan response empty for alias {(trip alias)}'
      `this
    =/  bod=octs  +.u.dat
    =/  body-cord=@t  q.bod
    =/  json-parsed  (de:json:html body-cord)
    ?~  json-parsed
      ~&  >>>  'mail-gateway: Etherscan JSON parse failed for alias {(trip alias)}'
      `this
    =/  pp  (~(get by pending-payments) alias)
    ?~  pp
      ~&  >>>  'mail-gateway: no pending payment for alias {(trip alias)} (expired?)'
      `this
    |^
    =/  result  (extract-tx-data u.json-parsed)
    ?~  result
      ~&  >>>  'mail-gateway: cannot extract tx data for alias {(trip alias)}'
      :_  this
      :~  [%pass /alias-err/(scot %p ship.u.pp) %agent [ship.u.pp %mail-client] %poke %mail-action !>(`action`[%alias-error 'Payment verification failed — invalid or unconfirmed transaction'])]
      ==
    =/  [tx-to=@t tx-value=@ud tx-block=(unit @ud)]  u.result
    ::  check: to-address matches payment wallet (case-insensitive)
    ?.  =((cass (trip tx-to)) (cass (trip payment-wallet.alias-config)))
      ~&  >>>  'mail-gateway: tx recipient mismatch: {(trip tx-to)} != {(trip payment-wallet.alias-config)}'
      :_  this
      :~  [%pass /alias-err/(scot %p ship.u.pp) %agent [ship.u.pp %mail-client] %poke %mail-action !>(`action`[%alias-error 'Payment sent to wrong address'])]
      ==
    ::  check: value >= expected amount
    ?.  (gte tx-value amount.u.pp)
      ~&  >>>  'mail-gateway: tx value {<tx-value>} < expected {<amount.u.pp>}'
      :_  this
      :~  [%pass /alias-err/(scot %p ship.u.pp) %agent [ship.u.pp %mail-client] %poke %mail-action !>(`action`[%alias-error 'Insufficient payment amount'])]
      ==
    ::  check: transaction mined (has block number)
    ?~  tx-block
      ~&  >>>  'mail-gateway: tx not yet mined for alias {(trip alias)}'
      :_  this
      :~  [%pass /alias-err/(scot %p ship.u.pp) %agent [ship.u.pp %mail-client] %poke %mail-action !>(`action`[%alias-error 'Transaction not yet mined — try again later'])]
      ==
    ::  phase 2: check confirmations via eth_blockNumber
    ~&  >  'mail-gateway: tx mined at block {<u.tx-block>}, checking confirmations...'
    =/  block-url=@t
      %-  crip
      ;:  weld
        "https://api.etherscan.io/v2/api?chainid=1&module=proxy&action=eth_blockNumber&apikey="
        (trip etherscan-key.alias-config)
      ==
    :_  this
    :~  [%pass /etherscan-block/(scot %t alias)/(scot %ud u.tx-block) %arvo %i %request [%'GET' block-url ~ ~] *outbound-config:iris]
    ==
    ::
    ++  parse-hex
      |=  h=tape
      ^-  @ud
      ?:  (lth (lent h) 3)  0
      (scan (slag 2 h) hex)
    ::
    ++  extract-tx-data
      |=  j=json
      ^-  (unit [to=@t value=@ud block=(unit @ud)])
      ?.  ?=([%o *] j)  ~
      =/  res  (~(get by p.j) 'result')
      ?~  res  ~
      ?.  ?=([%o *] u.res)  ~
      =/  tx-obj  p.u.res
      =/  to-json  (~(get by tx-obj) 'to')
      ?~  to-json  ~
      ?.  ?=([%s *] u.to-json)  ~
      =/  val-json  (~(get by tx-obj) 'value')
      ?~  val-json  ~
      ?.  ?=([%s *] u.val-json)  ~
      =/  block=(unit @ud)
        =/  block-json  (~(get by tx-obj) 'blockNumber')
        ?~  block-json  ~
        ?:  =(~ u.block-json)  ~
        ?.  ?=([%s *] u.block-json)  ~
        =/  bh=tape  (trip p.u.block-json)
        ?:  (lth (lent bh) 3)  ~
        `(parse-hex bh)
      `[p.u.to-json (parse-hex (trip p.u.val-json)) block]
    --
    ::  phase 2: check confirmation count
    ::
      [%etherscan-block @ @ ~]
    =/  alias=@t  (slav %t i.t.wire)
    =/  tx-block=@ud  (slav %ud i.t.t.wire)
    ?.  ?=([%iris %http-response %finished *] sign-arvo)
      ~&  >>>  'mail-gateway: eth_blockNumber call failed for alias {(trip alias)}'
      `this
    =/  dat  full-file.client-response.sign-arvo
    ?~  dat  `this
    =/  bod=octs  +.u.dat
    =/  body-cord=@t  q.bod
    =/  json-parsed  (de:json:html body-cord)
    ?~  json-parsed  `this
    =/  pp  (~(get by pending-payments) alias)
    ?~  pp
      ~&  >>>  'mail-gateway: no pending payment for alias {(trip alias)} (expired?)'
      `this
    ::  extract current block from {"result":"0x..."}
    ?.  ?=([%o *] u.json-parsed)  `this
    =/  res  (~(get by p.u.json-parsed) 'result')
    ?~  res  `this
    ?.  ?=([%s *] u.res)  `this
    =/  current-block=@ud
      =/  h=tape  (trip p.u.res)
      ?:  (lth (lent h) 3)  0
      (scan (slag 2 h) hex)
    =/  confirmations=@ud
      ?:  (gte current-block tx-block)
        (sub current-block tx-block)
      0
    ?.  (gte confirmations 3)
      ~&  >>>  'mail-gateway: only {<confirmations>} confirmations for alias {(trip alias)} (need 3)'
      :_  this
      :~  [%pass /alias-err/(scot %p ship.u.pp) %agent [ship.u.pp %mail-client] %poke %mail-action !>(`action`[%alias-error (crip "Transaction has {(a-co:co confirmations)}/3 confirmations — try again later")])]
      ==
    ::  >= 3 confirmations — activate alias
    ~&  >  'mail-gateway: payment verified! alias {(trip alias)} activated for {<ship.u.pp>} ({<confirmations>} confirmations)'
    =.  aliases  (~(put by aliases) alias [ship.u.pp %active now.bowl ''])
    =.  pending-payments  (~(del by pending-payments) alias)
    =/  ship-aliases=(list [@t ?])
      %+  murn  ~(tap by aliases)
      |=  [name=@t ent=alias-entry]
      ?.  =(owner.ent ship.u.pp)  ~
      ?.  ?|  =(%active status.ent)
              =(%disabled status.ent)
          ==
        ~
      `[name =(%active status.ent)]
    :_  this
    :~  [%pass /alias-notify/(scot %p ship.u.pp) %agent [ship.u.pp %mail-client] %poke %mail-action !>(`action`[%alias-update our.bowl ship-aliases])]
    ==
    ::
      [%dns-enable ~]
    ?.  ?=([%iris %http-response %finished *] sign-arvo)
      ~&  >>>  'mail-gateway: DNS check failed, gateway NOT enabled'
      `this
    =/  dat  full-file.client-response.sign-arvo
    ?~  dat
      ~&  >>>  'mail-gateway: DNS check failed (no body), gateway NOT enabled'
      `this
    =/  bod=octs  +.u.dat
    =/  body-cord=@t  q.bod
    =/  json-parsed  (de:json:html body-cord)
    ?~  json-parsed
      ~&  >>>  'mail-gateway: DNS parse failed, gateway NOT enabled'
      `this
    |^
    =/  expected=@t  (scot %p our.bowl)
    =/  answers  (extract-txt-answers u.json-parsed)
    =/  matched=?
      %+  lien  answers
      |=  txt=@t
      =/  trimmed  (crip (trim (trip txt)))
      =(trimmed expected)
    ?.  matched
      ~&  >>>  'mail-gateway: DNS verification FAILED for {(trip domain)} — gateway NOT enabled'
      ~&  >>>  'mail-gateway: add DNS record: _urbit-gw.{(trip domain)} TXT "{(trip expected)}"'
      `this
    ~&  >  'mail-gateway: DNS verified, gateway enabled'
    =.  enabled  %.y
    =/  user-count=@ud
      %-  ~(rep by whitelist)
      |=  [[* e=wl-entry] acc=@ud]
      ?:(=(%approved status.e) +(acc) acc)
    :_  this
    :~  [%pass /set-gw %agent [our.bowl %mail-client] %poke %mail-action !>(`action`[%set-is-gateway %.y])]
        [%pass /reg-update %agent [default-registry %mail-registry] %poke %mail-registry-action !>(`registry-action`[%register domain auto-approve user-count])]
    ==
    ::
    ++  trim
      |=  t=tape
      ^-  tape
      (flop (skip-spaces (flop (skip-spaces t))))
    ++  skip-spaces
      |=  t=tape
      ^-  tape
      ?.  ?=(^ t)  ~
      ?:  =(i.t ' ')  $(t t.t)
      t
    ::
    ++  extract-txt-answers
      |=  j=json
      ^-  (list @t)
      ?.  ?=([%o *] j)  ~
      =/  ans  (~(get by p.j) 'Answer')
      ?~  ans  ~
      ?.  ?=([%a *] u.ans)  ~
      %-  zing
      %+  turn  p.u.ans
      |=  entry=json
      ^-  (list @t)
      ?.  ?=([%o *] entry)  ~
      =/  typ  (~(get by p.entry) 'type')
      ?~  typ  ~
      ?.  ?=([%n *] u.typ)  ~
      ?.  =('16' p.u.typ)  ~
      =/  dat  (~(get by p.entry) 'data')
      ?~  dat  ~
      ?.  ?=([%s *] u.dat)  ~
      =/  raw=tape  (trip p.u.dat)
      =/  cleaned=tape
        ?:  &((gte (lent raw) 2) =((snag 0 raw) '"') =((snag (dec (lent raw)) raw) '"'))
          (slag 1 (snip raw))
        raw
      :~  (crip cleaned)
      ==
    --
  ==
++  on-leave  on-leave:def
::
++  on-fail
  |=  [=term =tang]
  ^-  (quip card _this)
  ~&  >>>  'mail-gateway on-fail: {<term>}'
  `this
--
