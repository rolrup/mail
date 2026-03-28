/-  *mail-client
/-  *mail-gateway
|%
::  make-id: generate unique message id from entropy
::
++  make-id
  |=  [now=@da eny=@uvJ]
  ^-  @uv
  `@uv`(sham [now eny])
::  is-comet: check if ship is a comet (128-bit @p)
::
++  is-comet
  |=  ship=@p
  ^-  ?
  (gte (met 3 (scot %p ship)) 55)
::  is-valid-email: basic email validation
::
++  is-valid-email
  |=  addr=@t
  ^-  ?
  ?&  (gth (met 3 addr) 3)
      !=(~ (find "@" (trip addr)))
  ==
::  contact-to-json: convert contact to json
::
++  contact-to-json
  |=  c=contact
  ^-  json
  ?-  -.c
    %urbit  (frond:enjs:format 'urbit' s+(scot %p p.c))
    %ext    (frond:enjs:format 'ext' s+p.c)
  ==
::  json-to-contact: convert json to contact
::
++  json-to-contact
  |=  j=json
  ^-  contact
  ?.  ?=([%o *] j)  [%ext '']
  ?:  (~(has by p.j) 'urbit')
    =/  ship  (mole |.((slav %p (so:dejs:format (~(got by p.j) 'urbit')))))
    ?~  ship  [%ext '']
    [%urbit u.ship]
  ?:  (~(has by p.j) 'ext')
    [%ext (so:dejs:format (~(got by p.j) 'ext'))]
  [%ext '']
::  envelope-to-json: convert envelope to json
::
++  envelope-to-json
  |=  env=envelope
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  ['id' s+(scot %uv id.msg.env)]
      ['from' (contact-to-json from.msg.env)]
      ['to' (contact-to-json to.msg.env)]
      ['cc' [%a (turn cc.msg.env |=(c=contact (contact-to-json c)))]]
      :-  'reply-to'
      ?~  reply-to.msg.env  ~
      (contact-to-json u.reply-to.msg.env)
      ['subject' s+subject.msg.env]
      ['body' s+body.msg.env]
      ['sent-at' s+(scot %da sent-at.msg.env)]
      ['route' [%a (turn route.msg.env |=(s=@p s+(scot %p s)))]]
      ['status' s+(scot %tas status.env)]
      ['folder' s+folder.env]
      ['labels' [%a (turn ~(tap in labels.env) |=(l=@tas s+l))]]
      ['recv-addr' s+recv-addr.env]
  ==
::  json-to-envelope: convert json to envelope
::
++  json-to-envelope
  |=  j=json
  ^-  [id=@uv env=envelope]
  ?.  ?=([%o *] j)  !!
  =,  dejs:format
  =/  o  p.j
  =/  id=@uv  (slav %uv (so (~(got by o) 'id')))
  =/  from=contact  (json-to-contact (~(got by o) 'from'))
  =/  to=contact  (json-to-contact (~(got by o) 'to'))
  =/  cc=(list contact)
    ?~  ca=(~(get by o) 'cc')  ~
    ?.  ?=([%a *] u.ca)  ~
    (turn p.u.ca |=(c=json (json-to-contact c)))
  =/  repl=(unit contact)
    ?~  rt=(~(get by o) 'reply-to')  ~
    ?:  ?=(~ u.rt)  ~
    `(json-to-contact u.rt)
  =/  subject=@t  (so (~(got by o) 'subject'))
  =/  body=@t  (so (~(got by o) 'body'))
  =/  sent-at=@da  (slav %da (so (~(got by o) 'sent-at')))
  =/  route=(list @p)
    ?~  ro=(~(get by o) 'route')  ~
    ?.  ?=([%a *] u.ro)  ~
    (turn p.u.ro |=(s=json (slav %p (so s))))
  =/  status=mail-status
    =/  s  (so (~(got by o) 'status'))
    ?+  s  %read
      %unread   %unread
      %read     %read
      %sending  %sending
      %sent     %sent
      %failed   %failed
    ==
  =/  folder=@tas
    ?~  f=(~(get by o) 'folder')  %inbox
    (slav %tas (so u.f))
  =/  labels=(set @tas)
    ?~  la=(~(get by o) 'labels')  ~
    ?.  ?=([%a *] u.la)  ~
    (silt (turn p.u.la |=(l=json (slav %tas (so l)))))
  =/  recv-addr=@t
    ?~  ra=(~(get by o) 'recv-addr')  ''
    (so u.ra)
  :-  id
  :*  [id from to cc repl subject body sent-at route]
      status
      folder
      labels
      recv-addr
  ==
::  fwd-rule-to-json: convert forwarding rule to json
::
++  fwd-rule-to-json
  |=  r=fwd-rule
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  ['to' (contact-to-json to.r)]
      ['conditions' s+conditions.r]
      ['enabled' b+enabled.r]
  ==
::  json-to-fwd-rule: convert json to forwarding rule
::
++  json-to-fwd-rule
  |=  j=json
  ^-  fwd-rule
  ?.  ?=([%o *] j)  !!
  =/  o  p.j
  =/  to=contact  (json-to-contact (~(got by o) 'to'))
  =/  conditions=@t
    ?~  cond=(~(get by o) 'conditions')  ''
    ?.  ?=([%s *] u.cond)  ''
    p.u.cond
  =/  enabled=?
    ?~  en=(~(get by o) 'enabled')  %.y
    ?.  ?=([%b *] u.en)  %.y
    p.u.en
  [to conditions enabled]
::  mailbox-to-json: convert map of envelopes to json array
::
++  mailbox-to-json
  |=  box=(map @uv envelope)
  ^-  json
  [%a (turn ~(tap by box) |=([id=@uv env=envelope] (envelope-to-json env)))]
::  json-to-mailbox: convert json array to map of envelopes
::
++  json-to-mailbox
  |=  j=json
  ^-  (map @uv envelope)
  ?.  ?=([%a *] j)  ~
  %-  ~(gas by *(map @uv envelope))
  (turn p.j |=(e=json (json-to-envelope e)))
::  state-to-json: serialize full state for backup
::
++  state-to-json
  |=  st=current-state
  ^-  json
  =,  enjs:format
  %-  pairs
  :~  ['version' (numb 20)]
      ['inbox' (mailbox-to-json inbox.st)]
      ['sent' (mailbox-to-json sent.st)]
      ['trash' (mailbox-to-json trash.st)]
      ['gateway' ?~(gateway.st ~ s+(scot %p u.gateway.st))]
      :-  'gateways'
      [%a (turn ~(tap in gateways.st) |=(g=@p s+(scot %p g)))]
      :-  'mail-domains'
      %-  pairs
      %+  turn  ~(tap by mail-domains.st)
      |=  [g=@p d=@t]
      [(scot %p g) s+d]
      :-  'gw-status'
      %-  pairs
      %+  turn  ~(tap by gw-status.st)
      |=  [g=@p s=?(%pending %approved %rejected)]
      [(scot %p g) [%s (scot %tas s)]]
      ['is-gw' b+is-gw.st]
      ['fwd-rules' [%a (turn fwd-rules.st |=(r=fwd-rule (fwd-rule-to-json r)))]]
      ['registry' ?~(registry.st ~ s+(scot %p u.registry.st))]
      :-  'registry-gateways'
      %-  pairs
      %+  turn  ~(tap by registry-gateways.st)
      |=  [ship=@p ent=reg-entry]
      :-  (scot %p ship)
      %-  pairs
      :~  ['domain' s+domain.ent]
          ['auto-approve' b+auto-approve.ent]
          ['user-count' (numb user-count.ent)]
          ['last-seen' s+(scot %da last-seen.ent)]
      ==
      :-  'my-aliases'
      %-  pairs
      %+  turn  ~(tap by my-aliases.st)
      |=  [gw=@p als=(list [@t ?])]
      [(scot %p gw) [%a (turn als |=([a=@t ac=?] (pairs:enjs:format ~[['name' s+a] ['active' b+ac]])))]]
      :-  'pending-payment'
      ?~  pending-payment.st  ~
      %-  pairs
      :~  ['alias' s+alias.u.pending-payment.st]
          ['amount' (numb amount.u.pending-payment.st)]
          ['wallet' s+wallet.u.pending-payment.st]
          ['created' s+(scot %da created.u.pending-payment.st)]
      ==
      :-  'addr-labels'
      %-  pairs
      %+  turn  ~(tap by addr-labels.st)
      |=  [id=@uv labs=(list @tas)]
      [(scot %uv id) [%a (turn labs |=(l=@tas s+l))]]
      :-  'gw-alias-cfg'
      %-  pairs
      %+  turn  ~(tap by gw-alias-cfg.st)
      |=  [ship=@p cfg=[on=? min=@ud free-min=@ud base=@ud pay-on=?]]
      :-  (scot %p ship)
      %-  pairs
      :~  ['on' b+on.cfg]
          ['min' (numb min.cfg)]
          ['free-min' (numb free-min.cfg)]
          ['base' (numb base.cfg)]
          ['pay-on' b+pay-on.cfg]
      ==
      ['recovered-from' ?~(recovered-from.st ~ s+(scot %da u.recovered-from.st))]
      ['backup-interval' s+(scot %dr backup-interval.st)]
      ['next-backup' s+(scot %da next-backup.st)]
      ['custom-icon-url' ?~(custom-icon-url.st ~ s+u.custom-icon-url.st)]
  ==
::  json-to-state: deserialize backup json to state
::
++  json-to-state
  |=  j=json
  ^-  current-state
  ?.  ?=([%o *] j)  !!
  =/  o  p.j
  =,  dejs:format
  =/  inb=(map @uv envelope)  (json-to-mailbox (~(got by o) 'inbox'))
  =/  snt=(map @uv envelope)  (json-to-mailbox (~(got by o) 'sent'))
  =/  trs=(map @uv envelope)  (json-to-mailbox (~(got by o) 'trash'))
  =/  gw=(unit @p)
    ?~  g=(~(get by o) 'gateway')  ~
    ?:  ?=(~ u.g)  ~
    `(slav %p (so u.g))
  =/  gws=(set @p)
    ?~  g=(~(get by o) 'gateways')  ~
    ?.  ?=([%a *] u.g)  ~
    (silt (turn p.u.g |=(s=json (slav %p (so s)))))
  =/  doms=(map @p @t)
    ?~  d=(~(get by o) 'mail-domains')  ~
    ?.  ?=([%o *] u.d)  ~
    %-  ~(gas by *(map @p @t))
    %+  turn  ~(tap by p.u.d)
    |=  [k=@t v=json]
    [(slav %p k) (so v)]
  =/  gwst=(map @p ?(%pending %approved %rejected))
    ?~  s=(~(get by o) 'gw-status')  ~
    ?.  ?=([%o *] u.s)  ~
    %-  ~(gas by *(map @p ?(%pending %approved %rejected)))
    %+  turn  ~(tap by p.u.s)
    |=  [k=@t v=json]
    :-  (slav %p k)
    =/  st  (so v)
    ?+  st  %pending
      %pending   %pending
      %approved  %approved
      %rejected  %rejected
    ==
  =/  isgw=?
    ?~  ig=(~(get by o) 'is-gw')  %.n
    ?.  ?=([%b *] u.ig)  %.n
    p.u.ig
  =/  fwds=(list fwd-rule)
    ?~  f=(~(get by o) 'fwd-rules')  ~
    ?.  ?=([%a *] u.f)  ~
    (turn p.u.f |=(r=json (json-to-fwd-rule r)))
  =/  reg=(unit @p)
    ?~  r=(~(get by o) 'registry')  ~
    ?:  ?=(~ u.r)  ~
    `(slav %p (so u.r))
  =/  reg-gws=(map @p reg-entry)
    ?~  rg=(~(get by o) 'registry-gateways')  ~
    (parse-registry-map u.rg)
  =/  als=(map @p (list [@t ?]))
    ?~  a=(~(get by o) 'my-aliases')  *(map @p (list [@t ?]))
    ?.  ?=([%o *] u.a)  *(map @p (list [@t ?]))
    %-  ~(gas by *(map @p (list [@t ?])))
    %+  murn  ~(tap by p.u.a)
    |=  [k=@t v=json]
    ^-  (unit [@p (list [@t ?])])
    =/  ship=(unit @p)  (mole |.((slav %p k)))
    ?~  ship  ~
    ?.  ?=([%a *] v)  ~
    =/  als=(list [@t ?])
      %+  murn  p.v
      |=  i=json
      ?:  ?=([%s *] i)
        ::  old format: just string
        `[p.i %.y]
      ?.  ?=([%o *] i)  ~
      =/  nm  (~(get by p.i) 'name')
      ?~  nm  ~
      ?.  ?=([%s *] u.nm)  ~
      =/  ac  (~(get by p.i) 'active')
      =/  active=?  ?~(ac %.y ?.(?=([%b *] u.ac) %.y p.u.ac))
      `[p.u.nm active]
    `[u.ship als]
  =/  my-als=(map @p (list [@t ?]))  als
  =/  pp=(unit [alias=@t amount=@ud wallet=@t created=@da])
    ?~  p=(~(get by o) 'pending-payment')  ~
    ?:  ?=(~ u.p)  ~
    ?.  ?=([%o *] u.p)  ~
    =/  pobj  p.u.p
    =/  al  (~(get by pobj) 'alias')
    ?~  al  ~
    ?.  ?=([%s *] u.al)  ~
    =/  am  (~(get by pobj) 'amount')
    ?~  am  ~
    ?.  ?=([%n *] u.am)  ~
    =/  wl  (~(get by pobj) 'wallet')
    ?~  wl  ~
    ?.  ?=([%s *] u.wl)  ~
    =/  cr=@da
      ?~  c=(~(get by pobj) 'created')  *@da
      ?.  ?=([%s *] u.c)  *@da
      (fall (mole |.((slav %da p.u.c))) *@da)
    `[p.u.al (rash p.u.am dem) p.u.wl cr]
  =/  addr-labs=(map @uv (list @tas))
    ?~  al=(~(get by o) 'addr-labels')  ~
    ?.  ?=([%o *] u.al)  ~
    %-  ~(gas by *(map @uv (list @tas)))
    %+  murn  ~(tap by p.u.al)
    |=  [k=@t v=json]
    ^-  (unit [@uv (list @tas)])
    =/  id=(unit @uv)  (mole |.((slav %uv k)))
    ?~  id  ~
    ?.  ?=([%a *] v)  ~
    `[u.id (turn p.v |=(l=json (slav %tas (so:dejs:format l))))]
  =/  gw-cfg=(map @p [on=? min=@ud free-min=@ud base=@ud pay-on=?])
    ?~  gc=(~(get by o) 'gw-alias-cfg')  ~
    ?.  ?=([%o *] u.gc)  ~
    %-  ~(gas by *(map @p [on=? min=@ud free-min=@ud base=@ud pay-on=?]))
    %+  murn  ~(tap by p.u.gc)
    |=  [k=@t v=json]
    ^-  (unit [@p [on=? min=@ud free-min=@ud base=@ud pay-on=?]])
    =/  ship=(unit @p)  (mole |.((slav %p k)))
    ?~  ship  ~
    ?.  ?=([%o *] v)  ~
    =/  co  p.v
    =/  on=?  ?~(ov=(~(get by co) 'on') %.n ?.(?=([%b *] u.ov) %.n p.u.ov))
    =/  mn=@ud  ?~(m=(~(get by co) 'min') 0 ?.(?=([%n *] u.m) 0 (rash p.u.m dem)))
    =/  fm=@ud  ?~(f=(~(get by co) 'free-min') 0 ?.(?=([%n *] u.f) 0 (rash p.u.f dem)))
    =/  bs=@ud  ?~(b=(~(get by co) 'base') 0 ?.(?=([%n *] u.b) 0 (rash p.u.b dem)))
    =/  po=?  ?~(p=(~(get by co) 'pay-on') %.n ?.(?=([%b *] u.p) %.n p.u.p))
    `[u.ship [on mn fm bs po]]
  =/  rec-from=(unit @da)
    ?~  rf=(~(get by o) 'recovered-from')  ~
    ?:  ?=(~ u.rf)  ~
    ?.  ?=([%s *] u.rf)  ~
    (mole |.((slav %da p.u.rf)))
  =/  bk-int=@dr
    ?~  bi=(~(get by o) 'backup-interval')  ~h1
    ?.  ?=([%s *] u.bi)  ~h1
    (fall (mole |.((slav %dr p.u.bi))) ~h1)
  =/  nxt-bk=@da
    ?~  nb=(~(get by o) 'next-backup')  *@da
    ?.  ?=([%s *] u.nb)  *@da
    (fall (mole |.((slav %da p.u.nb))) *@da)
  =/  icon-url=(unit @t)
    ?~  iu=(~(get by o) 'custom-icon-url')  ~
    ?:  ?=(~ u.iu)  ~
    ?.  ?=([%s *] u.iu)  ~
    ?:  =('' p.u.iu)  ~
    `p.u.iu
  :*  inb  snt  trs  gw  gws  doms  addr-labs  gwst  isgw  fwds  reg  reg-gws  my-als  pp  gw-cfg  rec-from  bk-int  nxt-bk  icon-url
  ==
::  from-hex-char: convert hex digit to number
::
++  from-hex-char
  |=  c=@t
  ^-  (unit @)
  ?:  &((gte c '0') (lte c '9'))  `(sub c '0')
  ?:  &((gte c 'a') (lte c 'f'))  `(add 10 (sub c 'a'))
  ?:  &((gte c 'A') (lte c 'F'))  `(add 10 (sub c 'A'))
  ~
::  url-decode: decode percent-encoded string
::
++  url-decode
  |=  t=tape
  ^-  tape
  ?~  t  ~
  ?:  =('+' i.t)
    [' ' $(t t.t)]
  ?.  =('%' i.t)
    [i.t $(t t.t)]
  ?.  ?=([@ @ *] t.t)
    [i.t $(t t.t)]
  =/  hi  (from-hex-char i.t.t)
  =/  lo  (from-hex-char i.t.t.t)
  ?:  |(?=(~ hi) ?=(~ lo))
    [i.t $(t t.t)]
  [`@t`(add (mul 16 u.hi) u.lo) $(t t.t.t.t)]
::  to-hex-char: convert nibble to hex digit
::
++  to-hex-char
  |=  n=@
  ^-  @t
  ?:  (lth n 10)  (add '0' n)
  (add 'a' (sub n 10))
::  url-encode: percent-encode unsafe characters in tape
::
++  url-encode
  |=  t=tape
  ^-  tape
  ?~  t  ~
  =/  c=@t  i.t
  ?:  ?|  &((gte c 'a') (lte c 'z'))
          &((gte c 'A') (lte c 'Z'))
          &((gte c '0') (lte c '9'))
          =(c '-')  =(c '_')  =(c '.')  =(c '~')
      ==
    [c $(t t.t)]
  =/  hi=@  (div c 16)
  =/  lo=@  (mod c 16)
  ['%' (to-hex-char hi) (to-hex-char lo) $(t t.t)]
::  split-on: split tape on delimiter character
::
++  split-on
  |=  [delim=@t text=tape]
  ^-  (list tape)
  =/  acc=(list tape)  ~
  =/  cur=tape  ~
  |-
  ?~  text
    (flop [(flop cur) acc])
  ?:  =(i.text delim)
    $(text t.text, acc [(flop cur) acc], cur ~)
  $(text t.text, cur [i.text cur])
::  parse-form-body: parse application/x-www-form-urlencoded body
::
++  parse-form-body
  |=  bod=(unit octs)
  ^-  (map @t @t)
  ?~  bod  ~
  =/  text=tape  (trip q.u.bod)
  ?:  =(~ text)  ~
  =/  pairs=(list tape)  (split-on '&' text)
  %-  ~(gas by *(map @t @t))
  %+  turn  pairs
  |=  pair=tape
  ^-  [@t @t]
  =/  idx  (find "=" pair)
  ?~  idx
    [(crip (url-decode pair)) '']
  [(crip (url-decode (scag u.idx pair))) (crip (url-decode (slag +(u.idx) pair)))]
::  parse-form-all: extract all values for a key from form body
::
++  parse-form-all
  |=  [bod=(unit octs) key=@t]
  ^-  (list @t)
  ?~  bod  ~
  =/  text=tape  (trip q.u.bod)
  ?:  =(~ text)  ~
  =/  pairs=(list tape)  (split-on '&' text)
  =/  key-tape=tape  (trip key)
  %+  murn  pairs
  |=  pair=tape
  ^-  (unit @t)
  =/  idx  (find "=" pair)
  ?~  idx  ~
  =/  k=tape  (url-decode (scag u.idx pair))
  ?.  =(k key-tape)  ~
  `(crip (url-decode (slag +(u.idx) pair)))
::  trim-spaces: strip leading and trailing ASCII spaces from tape
::
++  trim-spaces
  |=  t=tape
  ^-  tape
  |-
  ?~  t  ~
  ?.  =(i.t ' ')  (flop (trip (crip (flop t))))
  $(t t.t)
::  parse-reg-entry: parse a single registry entry from ship cord + json object
::
++  parse-reg-entry
  |=  [ship-cord=@t obj=json]
  ^-  (unit [@p reg-entry])
  =/  ship-unit=(unit @p)  (mole |.((slav %p ship-cord)))
  ?~  ship-unit  ~
  ?.  ?=([%o *] obj)  ~
  =/  o  p.obj
  =,  dejs:format
  =/  domain=@t
    ?~  d=(~(get by o) 'domain')  ''
    (so u.d)
  =/  auto-approve=?
    ?~  a=(~(get by o) 'auto-approve')  %.n
    ?.  ?=([%b *] u.a)  %.n
    p.u.a
  =/  user-count=@ud
    ?~  c=(~(get by o) 'user-count')  0
    ?:  ?=([%n *] u.c)  (rash p.u.c dem)
    0
  =/  last-seen=@da
    ?~  ls=(~(get by o) 'last-seen')  *@da
    =/  parsed  (mole |.((slav %da (so u.ls))))
    ?~  parsed  *@da
    u.parsed
  `[u.ship-unit [domain auto-approve user-count last-seen]]
::  parse-registry-json: parse registry JSON array to map
::  used for facts from %mail-registry subscription
::
++  parse-registry-json
  |=  j=json
  ^-  (map @p reg-entry)
  ?.  ?=([%a *] j)  ~
  %-  ~(gas by *(map @p reg-entry))
  %+  murn  p.j
  |=  item=json
  ^-  (unit [@p reg-entry])
  ?.  ?=([%o *] item)  ~
  =/  ship-cord=@t
    ?~  s=(~(get by p.item) 'ship')  ''
    ?.  ?=([%s *] u.s)  ''
    p.u.s
  (parse-reg-entry ship-cord item)
::  parse-registry-map: parse registry JSON object to map (for backup restore)
::
++  parse-registry-map
  |=  j=json
  ^-  (map @p reg-entry)
  ?.  ?=([%o *] j)  ~
  %-  ~(gas by *(map @p reg-entry))
  %+  murn  ~(tap by p.j)
  |=  [k=@t v=json]
  (parse-reg-entry k v)
::  parse-contacts: parse comma-separated addresses into contact list
::
++  parse-contacts
  |=  text=@t
  ^-  (list contact)
  ?:  =('' text)  ~
  =/  parts=(list tape)  (split-on ',' (trip text))
  %+  murn  parts
  |=  part=tape
  ^-  (unit contact)
  =/  trimmed=tape  (trim-spaces part)
  ?:  =(~ trimmed)  ~
  ?:  =('~' (snag 0 trimmed))
    `[%urbit (slav %p (crip trimmed))]
  `[%ext (crip trimmed)]
::  check-fwd-conditions: evaluate conditions string against labels and recv-addr
::  format: "label1, label2, -spam, @alias, -@admin" (comma-separated)
::  positive = OR (any match), negative = AND-NOT (none match)
::
++  check-fwd-conditions
  |=  [cond=@t labels=(set @tas) recv-addr=@t]
  ^-  ?
  ?:  =('' cond)  %.y  ::  empty = forward all
  =/  terms=(list tape)
    %+  turn
    %+  skim
      (split-on ',' (trip cond))
    |=(t=tape !=(~ (trim-spaces t)))
    |=(t=tape (trim-spaces t))
  =/  pos-labels=(list @tas)  ~
  =/  neg-labels=(list @tas)  ~
  =/  pos-aliases=(list @t)   ~
  =/  neg-aliases=(list @t)   ~
  |-
  ?~  terms
    ::  evaluate: positive OR, then negative AND-NOT
    =/  has-positive=?  ?|(!=(~ pos-labels) !=(~ pos-aliases))
    =/  pos-match=?
      ?.  has-positive  %.y
      ?|  (lien pos-labels |=(l=@tas (~(has in labels) l)))
          (lien pos-aliases |=(a=@t !=(~ (find (trip a) (trip recv-addr)))))
      ==
    ?.  pos-match  %.n
    ?&  !(lien neg-labels |=(l=@tas (~(has in labels) l)))
        !(lien neg-aliases |=(a=@t !=(~ (find (trip a) (trip recv-addr)))))
    ==
  =/  term=tape  i.terms
  ?:  ?&(!=(~ term) =('-' (snag 0 term)) (gth (lent term) 1) =('@' (snag 1 term)))
    ::  -@alias (negative alias)
    $(terms t.terms, neg-aliases [(crip (slag 2 term)) neg-aliases])
  ?:  ?&(!=(~ term) =('-' (snag 0 term)))
    ::  -label (negative label)
    $(terms t.terms, neg-labels [`@tas`(crip (slag 1 term)) neg-labels])
  ?:  ?&(!=(~ term) =('@' (snag 0 term)))
    ::  @alias (positive alias)
    $(terms t.terms, pos-aliases [(crip (slag 1 term)) pos-aliases])
  ::  label (positive)
  $(terms t.terms, pos-labels [`@tas`(crip term) pos-labels])
::  build-fwd-cards: generate forwarding cards from rules
::  use-action-wrap: %.y wraps in %mail-action/%mail-gateway-action
::                   %.n sends raw %mail-message mark
::
++  build-fwd-cards
  |=  $:  msg=message
          labels=(set @tas)
          rules=(list fwd-rule)
          our=@p
          now=@da
          eny=@uvJ
          gateway=(unit @p)
          use-action-wrap=?
          recv-addr=@t
      ==
  ^-  (list card:agent:gall)
  ::  comets cannot forward
  ?:  (is-comet our)  ~
  ?:  (~(has in (silt route.msg)) our)  ~
  ?:  (gth (lent route.msg) 20)  ~
  %+  murn  rules
  |=  r=fwd-rule
  ?.  enabled.r  ~
  ?.  (check-fwd-conditions conditions.r labels recv-addr)  ~
  =/  fwd-id=@uv  (sham [now eny (scot %p our) 'fwd'])
  =/  fwd-route=(list @p)  (snoc route.msg our)
  =/  fmt-contact
    |=  c=contact
    ^-  tape
    ?-  -.c
      %urbit  (scow %p p.c)
      %ext    (trip p.c)
    ==
  =/  fwd-body=tape
    ;:  weld
      "---------- Relayed via Urbit Mail from {(scow %p our)} ----------\0a"
      "From: {(fmt-contact from.msg)}\0a"
      "To: {(fmt-contact to.msg)}{?:(=('' recv-addr) "" " ({(trip recv-addr)})")}\0a"
      "Date: {(scag 18 (scow %da sent-at.msg))}\0a"
      "Subject: {(trip subject.msg)}\0a\0a"
      (trip body.msg)
    ==
  ?-  -.to.r
      %urbit
    =/  fwd-msg=message  [fwd-id [%urbit our] to.r ~ ~ subject.msg (crip fwd-body) now fwd-route]
    ?:  use-action-wrap
      =/  fwd-act=action  [%receive-labeled fwd-msg labels '']
      `[%pass /fwd/(scot %uv fwd-id) %agent [p.to.r %mail-client] %poke %mail-action !>(fwd-act)]
    `[%pass /fwd/(scot %uv fwd-id) %agent [p.to.r %mail-client] %poke %mail-message !>(fwd-msg)]
      %ext
    ::  block comets from forwarding to external addresses
    ?:  (is-comet our)  ~
    =/  subj=@t  (crip (weld "[Fwd] " (trip subject.msg)))
    =/  fwd-msg=message  [fwd-id [%urbit our] to.r ~ ~ subj (crip fwd-body) now fwd-route]
    ?~  gateway  ~
    ?:  use-action-wrap
      =/  lab-list=(list @tas)  ~(tap in labels)
      `[%pass /fwd/(scot %uv fwd-id) %agent [u.gateway %mail-gateway] %poke %mail-gateway-action !>(`gateway-action`[%send-labeled fwd-msg lab-list])]
    `[%pass /fwd/(scot %uv fwd-id) %agent [u.gateway %mail-gateway] %poke %mail-message !>(fwd-msg)]
  ==
::  restore-from-json: parse JSON cord to state, unit for failure
::
++  restore-from-json
  |=  body=@t
  ^-  (unit current-state)
  =/  parsed  (de:json:html body)
  ?~  parsed  ~
  %-  mole  |.
  (json-to-state u.parsed)
--
