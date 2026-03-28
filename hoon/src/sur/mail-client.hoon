|%
::  default-gateway: publisher ship, set on install
::
++  default-gateway  ~mister-poster-midnev
::  default-registry: ship running %mail-registry agent
::
++  default-registry  ~master-poster-midnev
::  contact: urbit ship or external email
::
+$  contact
  $%  [%urbit p=@p]
      [%ext p=@t]
  ==
::  message: a single mail message
::
+$  message
  $:  id=@uv
      from=contact
      to=contact
      cc=(list contact)
      reply-to=(unit contact)
      subject=@t
      body=@t
      sent-at=@da
      route=(list @p)
  ==
::  mail-status: envelope status for UI
::
+$  mail-status
  $?  %unread
      %read
      %sending
      %sent
      %failed
  ==
::  envelope: message with client-side metadata
::
+$  envelope
  $:  msg=message
      status=mail-status
      folder=@tas
      labels=(set @tas)
      recv-addr=@t
  ==
::  action: incoming poke actions
::
+$  action
  $%  [%send to=contact cc=(list contact) bcc=(list contact) subject=@t body=@t]
      [%receive msg=message]
      [%receive-labeled msg=message labels=(set @tas) recv-addr=@t]
      [%mark-read id=@uv]
      [%mark-unread id=@uv]
      [%delete id=@uv]
      [%add-label id=@uv label=@tas]
      [%remove-label id=@uv label=@tas]
      [%set-gateway ship=@p]
      [%add-gateway ship=@p]
      [%remove-gateway ship=@p]
      [%access-response status=?(%approved %rejected)]
      [%set-is-gateway is-gw=?]
      [%alias-update gw=@p aliases=(list [@t ?])]
      [%alias-error msg=@t]
      [%payment-request alias=@t amount=@ud wallet=@t]
      [%send-failed id=@uv reason=@t]
  ==
::  update: outgoing facts to subscribers
::
+$  update
  $%  [%new-mail envelope]
      [%status-change id=@uv status=mail-status]
      [%labels-changed id=@uv labels=(set @tas)]
      [%deleted id=@uv]
      [%sent envelope]
      [%send-failed id=@uv reason=@t]
  ==
::  folder maps
::
+$  inbox  (map @uv envelope)
+$  sent   (map @uv envelope)
+$  trash  (map @uv envelope)
::  forwarding rule (v19+: conditions replace single label)
::
+$  fwd-rule  [to=contact conditions=@t enabled=?]
::  reg-entry: registry gateway entry (client-side copy)
::
+$  reg-entry
  $:  domain=@t
      auto-approve=?
      user-count=@ud
      last-seen=@da
  ==
::  agent state
::
+$  state-19
  $:  =inbox
      =sent
      =trash
      gateway=(unit @p)
      gateways=(set @p)
      mail-domains=(map @p @t)
      addr-labels=(map @uv (list @tas))
      gw-status=(map @p ?(%pending %approved %rejected))
      is-gw=?
      fwd-rules=(list fwd-rule)
      registry=(unit @p)
      registry-gateways=(map @p reg-entry)
      my-aliases=(map @p (list [@t ?]))
      pending-payment=(unit [alias=@t amount=@ud wallet=@t created=@da])
      gw-alias-cfg=(map @p [on=? min=@ud free-min=@ud base=@ud pay-on=?])
      recovered-from=(unit @da)
      backup-interval=@dr
      next-backup=@da
  ==
+$  state-20
  $:  =inbox
      =sent
      =trash
      gateway=(unit @p)
      gateways=(set @p)
      mail-domains=(map @p @t)
      addr-labels=(map @uv (list @tas))
      gw-status=(map @p ?(%pending %approved %rejected))
      is-gw=?
      fwd-rules=(list fwd-rule)
      registry=(unit @p)
      registry-gateways=(map @p reg-entry)
      my-aliases=(map @p (list [@t ?]))
      pending-payment=(unit [alias=@t amount=@ud wallet=@t created=@da])
      gw-alias-cfg=(map @p [on=? min=@ud free-min=@ud base=@ud pay-on=?])
      recovered-from=(unit @da)
      backup-interval=@dr
      next-backup=@da
      custom-icon-url=(unit @t)
  ==
::  current-state: alias for latest state version
::  Change this ONE line when adding a new state version.
::  All files importing *mail-client will use the new type.
::
+$  current-state  state-20
::  versioned state for on-load
::
+$  versioned-state
  $%  [%19 state-19]
      [%20 state-20]
  ==
--
