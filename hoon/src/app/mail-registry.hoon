/-  *mail-registry
/+  default-agent, dbug
|%
+$  card  card:agent:gall
+$  state  registry-state-1
::  registry-to-json: serialize registry data as json array
::
++  registry-to-json
  |=  data=(map @p registry-entry)
  ^-  json
  =,  enjs:format
  :-  %a
  %+  turn  ~(tap by data)
  |=  [ship=@p ent=registry-entry]
  %-  pairs
  :~  ['ship' s+(scot %p ship)]
      ['domain' s+domain.ent]
      ['auto-approve' b+auto-approve.ent]
      ['user-count' (numb user-count.ent)]
      ['last-seen' s+(scot %da last-seen.ent)]
      ['verified' b+%.y]
  ==
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
  ~&  >  '%mail-registry installed'
  `this(enabled %.n, data ~, pending ~)
::
++  on-save
  ^-  vase
  !>([%1 state])
::
++  on-load
  |=  old-vase=vase
  ^-  (quip card _this)
  =/  parsed=(unit versioned-registry-state)
    %-  mole  |.
    !<(versioned-registry-state old-vase)
  ?~  parsed
    ~&  >  '%mail-registry: state mismatch, reinitializing'
    on-init
  =/  old  u.parsed
  ?-  -.old
      %0
    ~&  >  '%mail-registry: migrating state 0 → 1'
    `this(enabled enabled.+.old, data data.+.old, pending ~)
    ::
      %1
    `this(state +.old)
  ==
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+  mark  (on-poke:def mark vase)
      %mail-registry-action
    =/  act  !<(registry-action vase)
    ?-  -.act
        %register
      ::  reject empty domain — nothing to verify, useless to users
      ?:  =('' domain.act)
        ~&  >>>  '%mail-registry: rejecting registration without domain'
        `this
      ::  save pending registration and start DNS verification
      =/  wire-key=@t  (scot %uv (sham [src.bowl domain.act now.bowl]))
      =/  pend=pending-reg  [src.bowl domain.act auto-approve.act user-count.act]
      =.  pending  (~(put by pending) wire-key pend)
      =/  url=@t
        %-  crip
        ;:  weld
          "https://dns.google/resolve?name=_urbit-gw."
          (trip domain.act)
          "&type=TXT"
        ==
      ~&  >  '%mail-registry: verifying DNS for {(trip domain.act)}'
      :_  this
      :~  [%pass /dns-verify/[wire-key] %arvo %i %request [%'GET' url ~ ~] *outbound-config:iris]
      ==
      ::
        %unregister
      =/  new-data  (~(del by data) src.bowl)
      :_  this(data new-data)
      ?:  enabled
        :~  [%give %fact ~[/registry] %json !>((registry-to-json new-data))]
        ==
      ~
        %set-enabled
      ?.  =(src.bowl our.bowl)
        ~&  >>>  '%mail-registry: only local ship can toggle enabled'
        `this
      `this(enabled enabled.act)
    ==
  ==
::
++  on-watch
  |=  =path
  ^-  (quip card _this)
  ?+  path  `this
      [%registry ~]
    ?.  enabled
      ~&  >>>  '%mail-registry: registry disabled, rejecting subscription'
      !!
    :_  this
    :~  [%give %fact ~ %json !>((registry-to-json data))]
    ==
  ==
::
++  on-leave  on-leave:def
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  ~
      [%x %enabled ~]
    ``noun+!>(enabled)
      [%x %data ~]
    ``noun+!>(data)
      [%x %count ~]
    ``noun+!>(~(wyt by data))
  ==
::
++  on-agent
  |=  [=wire =sign:agent:gall]
  ^-  (quip card _this)
  `this
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?+  wire  `this
      [%dns-verify @ ~]
    =/  wire-key  i.t.wire
    ?.  ?=([%iris %http-response %finished *] sign-arvo)
      ~&  >>>  '%mail-registry: unexpected arvo sign on dns-verify'
      `this(pending (~(del by pending) wire-key))
    =/  pend  (~(get by pending) wire-key)
    ?~  pend
      ~&  >>>  '%mail-registry: no pending registration for wire'
      `this
    =.  pending  (~(del by pending) wire-key)
    ::  extract response body: full-file is (unit mime), mime is [mite octs]
    =/  dat  full-file.client-response.sign-arvo
    ?~  dat
      ~&  >>>  '%mail-registry: DNS lookup failed for {(trip domain.u.pend)} (no response)'
      `this
    =/  bod=octs  +.u.dat
    =/  body-cord=@t  q.bod
    =/  json-parsed  (de:json:html body-cord)
    ?~  json-parsed
      ~&  >>>  '%mail-registry: failed to parse DNS JSON for {(trip domain.u.pend)}'
      `this
    ::  extract Answer array, find TXT records containing @p
    |^
    =/  expected=@t  (scot %p ship.u.pend)
    =/  answers  (extract-txt-answers u.json-parsed)
    =/  matched=?
      %+  lien  answers
      |=  txt=@t
      =/  trimmed  (crip (trim (trip txt)))
      =(trimmed expected)
    ?:  matched
      ~&  >  '%mail-registry: DNS verified {(trip domain.u.pend)} → {(trip expected)}'
      (register-verified u.pend)
    ~&  >>>  '%mail-registry: DNS verification FAILED for {(trip domain.u.pend)} (expected {(trip expected)})'
    `this
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
      =/  entries=(list json)  p.u.ans
      %-  zing
      %+  turn  entries
      |=  entry=json
      ^-  (list @t)
      ?.  ?=([%o *] entry)  ~
      ::  check type=16 (TXT record)
      =/  typ  (~(get by p.entry) 'type')
      ?~  typ  ~
      ?.  ?=([%n *] u.typ)  ~
      ?.  =('16' p.u.typ)  ~
      =/  dat  (~(get by p.entry) 'data')
      ?~  dat  ~
      ?.  ?=([%s *] u.dat)  ~
      ::  strip surrounding quotes if present
      =/  raw=tape  (trip p.u.dat)
      =/  cleaned=tape
        ?:  &((gte (lent raw) 2) =((snag 0 raw) '"') =((snag (dec (lent raw)) raw) '"'))
          (slag 1 (snip raw))
        raw
      :~  (crip cleaned)
      ==
    ::
    ++  register-verified
      |=  pend=pending-reg
      ^-  (quip card _this)
      =/  ent=registry-entry
        [domain.pend auto-approve.pend user-count.pend now.bowl]
      =/  new-data  (~(put by data) ship.pend ent)
      :_  this(data new-data)
      ?:  enabled
        :~  [%give %fact ~[/registry] %json !>((registry-to-json new-data))]
        ==
      ~
    --
  ==
::
++  on-fail
  |=  [=term =tang]
  ^-  (quip card _this)
  ~&  >>>  'mail-registry on-fail: {<term>}'
  `this
--
