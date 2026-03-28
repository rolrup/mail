/-  *mail-client
|%
::  gateway-action: actions from Python bridge and admin
::
+$  gateway-action
  $%  [%delivered id=@uv]       :: bridge confirms email sent
      [%set-domain domain=@t]   :: set the mail domain
      [%send-labeled msg=message labels=(list @tas)]  :: outbound with labels
      [%request-access ~]       :: ship requests gateway access
      [%approve-access ship=@p] :: admin approves ship
      [%reject-access ship=@p]  :: admin rejects ship
      [%remove-access ship=@p]  :: admin removes ship from whitelist
      [%add-to-whitelist ship=@p]  :: admin manually adds ship as approved
      [%set-auto-approve auto=?]  :: toggle auto-approve mode
      [%set-enabled enabled=?]   :: enable/disable gateway mode
      [%set-public public=?]     :: toggle public registry listing
      ::  alias actions
      [%request-alias alias=@t]        :: ship requests free alias
      [%disable-alias alias=@t]        :: owner disables (does not delete)
      [%enable-alias alias=@t]         :: owner re-enables
      [%redeem-invite code=@t]         :: activate invite code
      [%block-alias alias=@t]          :: admin blocks alias
      [%unblock-alias alias=@t]        :: admin unblocks alias
      [%unreserve-alias alias=@t]      :: admin unreserves (cancels invite)
      [%generate-invite alias=@t]      :: admin generates invite code
      [%set-alias-config cfg=alias-cfg]  :: admin sets alias config
      ::  payment actions
      [%request-paid-alias alias=@t]        :: ship requests paid alias
      [%verify-payment alias=@t tx-hash=@t] :: ship submits tx hash
      [%cancel-payment alias=@t]            :: ship cancels pending payment
      [%check-payments ~]                    :: trigger Etherscan scan for pending payments
      [%set-payment-config wallet=@t price=@ud key=@t enabled=?]  :: admin configures
      [%delivery-failed id=@uv ship=@p reason=@t]  :: bridge reports failed delivery
  ==
::  whitelist types
::
+$  wl-status  ?(%pending %approved %rejected)
+$  wl-entry
  $:  status=wl-status
      in=@ud
      out=@ud
      requested=@da
  ==
::  alias types
::
+$  alias-status  ?(%active %disabled %blocked %reserved)
+$  alias-entry
  $:  owner=@p
      status=alias-status
      created=@da
      invite-code=@t
  ==
+$  alias-cfg
  $:  aliases-enabled=?    :: aliases feature on/off for this gateway
      min-len=@ud          :: absolute minimum alias length (e.g. 5)
      free-min-len=@ud     :: min length for free aliases (e.g. 10)
      free-limit=@ud       :: max free aliases per ship (e.g. 5)
      ::  payment settings
      payment-enabled=?    :: crypto payment on/off
      payment-wallet=@t    :: ETH address (0x...)
      base-price=@ud       :: base price in wei
      etherscan-key=@t     :: Etherscan API key
  ==
::  pending-payment: tracks a pending alias purchase
::
+$  pending-payment
  $:  alias=@t
      ship=@p
      amount=@ud            :: unique amount in wei
      created=@da
  ==
::  gateway state
::
+$  gateway-state-9
  $:  pending=(set @uv)
      domain=@t
      whitelist=(map @p wl-entry)
      auto-approve=?
      enabled=?
      out-log=(list @da)
      public=?
      aliases=(map @t alias-entry)
      alias-config=alias-cfg
      invite-secret=@
      pending-payments=(map @t pending-payment)
  ==
::
+$  versioned-gateway-state
  $%  [%9 gateway-state-9]
  ==
--
