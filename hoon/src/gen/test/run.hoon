::  +test/run: run all mail-client tests
::
::  Usage: =dir /=mail-client=  then  +test/run
::
/-  *mail-client
/-  *mail-gateway
/+  mc=mail-client, ui=mail-ui
:-  %say
|=  *
:-  %tang
|^
=/  results=(list [name=tape ok=?])  ~
::
~&  >  '=== mail-client test suite ==='
~&  >  ''
::
::  --- contact roundtrip ---
~&  >  '--- contact roundtrip ---'
=.  results  (snoc results (check "urbit contact roundtrip" =(c1 (json-to-contact:mc (contact-to-json:mc c1)))))
=.  results  (snoc results (check "ext contact roundtrip" =(c2 (json-to-contact:mc (contact-to-json:mc c2)))))
::
::  --- email validation ---
~&  >  '--- email validation ---'
=.  results  (snoc results (check "valid email" (is-valid-email:mc 'user@example.com')))
=.  results  (snoc results (check "valid email dots" (is-valid-email:mc 'a.b@domain.co.uk')))
=.  results  (snoc results (check "invalid: no @" !(is-valid-email:mc 'invalid')))
=.  results  (snoc results (check "invalid: too short" !(is-valid-email:mc 'a@b')))
=.  results  (snoc results (check "invalid: empty" !(is-valid-email:mc '')))
::
::  --- envelope roundtrip ---
~&  >  '--- envelope roundtrip ---'
=.  results
  =/  j=json  (envelope-to-json:mc env1)
  =/  pair=[@ envelope]  (json-to-envelope:mc j)
  =/  restored=envelope  +.pair
  (snoc results (check "envelope roundtrip" =(env1 restored)))
::
::  --- state backup roundtrip (empty) ---
~&  >  '--- state backup roundtrip ---'
=.  results
  =/  j=json  (state-to-json:mc empty-state)
  =/  restored=state-15  (json-to-state:mc j)
  (snoc results (check "empty state roundtrip" =(empty-state restored)))
::
::  --- state backup roundtrip (with data) ---
~&  >  '--- state with data roundtrip ---'
=.  results
  =/  orig=state-15  rich-state
  =/  j=json  (state-to-json:mc orig)
  =/  r=state-15  (json-to-state:mc j)
  =/  ok=?
    ?&  =(gateway.orig gateway.r)
        =(gateways.orig gateways.r)
        =(mail-domains.orig mail-domains.r)
        =(gw-status.orig gw-status.r)
        =(is-gw.orig is-gw.r)
        =(my-aliases.orig my-aliases.r)
        =(~(wyt by inbox.orig) ~(wyt by inbox.r))
    ==
  (snoc results (check "rich state roundtrip" ok))
::
::  --- wei/eth display ---
~&  >  '--- wei/eth display ---'
=.  results  (snoc results (check "0 wei display" =("0.000000000" (wei-to-eth-display:ui 0))))
=.  results  (snoc results (check "1 ETH display" =("1.000000000" (wei-to-eth-display:ui 1.000.000.000.000.000.000))))
=.  results  (snoc results (check "0.005 ETH display" =("0.005000000" (wei-to-eth-display:ui 5.000.000.000.000.000))))
=.  results  (snoc results (check "0.005 ETH price" =("0.0050" (wei-to-eth-price:ui 5.000.000.000.000.000))))
=.  results  (snoc results (check "0.0001 ETH price" =("0.0001" (wei-to-eth-price:ui 100.000.000.000.000))))
::
::  --- url encode/decode ---
~&  >  '--- url encode/decode ---'
=.  results
  =/  original=tape  "hello world&foo=bar"
  =/  encoded=tape  (url-encode:mc original)
  =/  decoded=tape  (url-decode:mc encoded)
  (snoc results (check "url roundtrip" =(original decoded)))
::
::  --- form parsing ---
~&  >  '--- form parsing ---'
=.  results
  =/  body=@t  'name=hello&value=world'
  =/  form=(map @t @t)  (parse-form-body:mc `(as-octs:mimes:html body))
  (snoc results (check "form parse" ?&(=('hello' (~(got by form) 'name')) =('world' (~(got by form) 'value')))))
::
::  --- fwd-rule roundtrip ---
~&  >  '--- fwd-rule roundtrip ---'
=.  results
  =/  rule=fwd-rule  [to=[%ext 'fwd@test.com'] label=`%work enabled=%.y]
  (snoc results (check "fwd-rule roundtrip" =(rule (json-to-fwd-rule:mc (fwd-rule-to-json:mc rule)))))
::
::  --- parse contacts ---
~&  >  '--- parse contacts ---'
=.  results  (snoc results (check "parse 2 contacts" =(2 (lent (parse-contacts:mc '~zod, user@mail.com')))))
=.  results  (snoc results (check "parse empty" =(0 (lent (parse-contacts:mc '')))))
::
::  === Summary ===
::
=/  pass=@ud  (lent (skim results |=([* ok=?] ok)))
=/  fail=@ud  (lent (skip results |=([* ok=?] ok)))
~&  >  ''
~&  >  '==========================='
~&  >  "  {(a-co:co pass)} passed, {(a-co:co fail)} failed"
~&  >  '==========================='
?:  =(0 fail)
  ~&  >  'ALL TESTS PASSED'
  ~
~&  >>>  'SOME TESTS FAILED'
%+  turn  (skip results |=([* ok=?] ok))
|=  [name=tape *]
leaf+"FAIL: {name}"
::
::  === Test helpers and fixtures ===
::
++  check
  |=  [name=tape ok=?]
  ^-  [tape ?]
  ?:  ok
    ~&  >  "  ok: {name}"
    [name %.y]
  ~&  >>>  "  FAIL: {name}"
  [name %.n]
::
++  c1  ^-  contact  [%urbit ~zod]
++  c2  ^-  contact  [%ext 'user@example.com']
++  msg1
  ^-  message
  :*  0v1a2b3
      [%urbit ~zod]
      [%ext 'bob@mail.com']
      `(list contact)`~[[%urbit ~bus]]
      *(unit contact)
      'Test Subject'
      'Hello world'
      ~2024.1.1
      `(list @p)`~
  ==
++  env1
  ^-  envelope
  [msg1 %unread %inbox (silt `(list @tas)`~[%work %urgent]) 'zod@test.com']
++  empty-state
  ^-  state-15
  :*  *(map @uv envelope)
      *(map @uv envelope)
      *(map @uv envelope)
      `~zod
      (silt ~[~zod])
      (my ~[[~zod 'test.com']])
      *(map @uv (list @tas))
      (my ~[[~zod %approved]])
      %.n
      ~
      `~zod
      *(map @p reg-entry)
      *(map @p (list [@t ?]))
      ~
  ==
++  rich-state
  ^-  state-15
  :*  (my ~[[0v1a2b4 env1]])
      *(map @uv envelope)
      *(map @uv envelope)
      `~bus
      (silt ~[~zod ~bus])
      (my ~[[~zod 'mail.com'] [~bus 'other.com']])
      (my ~[[0v1a2b4 ~[%test %work]]])
      (my ~[[~zod %approved] [~bus %pending]])
      %.y
      ~[[to=[%ext 'fwd@mail.com'] label=`%work enabled=%.y]]
      `~zod
      *(map @p reg-entry)
      (my ~[[~zod ~[['myalias' %.y] ['disabled' %.n]]]])
      ~
  ==
--
