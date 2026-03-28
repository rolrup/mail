/-  *mail-client
/-  *mail-gateway
/+  ui=mail-ui
|%
::  render-gateway-info: info page when gateway mode is disabled
::
++  render-gateway-info
  |=  [domain=@t msg=(unit @t) our=@p]
  ^-  manx
  =/  our-name=tape  (scow %p our)
  =/  dom-text=tape  ?:(=('' domain) "yourdomain.com" (trip domain))
  ;div(class "gateway-info")
    ;h2: Gateway Mode
    ;*  ?~  msg  ~
        :~  ;div(style "background: var(--link); color: #fff; padding: 12px 16px; border-radius: 6px; margin-bottom: 16px; line-height: 1.6;")
              ;p(style "margin: 0 0 8px 0; font-weight: 600;"): DNS verification in progress...
              ;p(style "margin: 0;"): Reload the page in a few seconds. If gateway didn't enable, make sure this DNS record exists:
              ;code(style "display: block; margin-top: 8px; padding: 8px; background: rgba(0,0,0,0.2); border-radius: 4px;"): _urbit-gw.{dom-text} TXT "{our-name}"
            ==
        ==
    ;p(style "color: var(--muted); margin-bottom: 16px; line-height: 1.6;")
      ; Gateway mode turns this ship into a mail relay. When enabled, other Urbit ships
      ; can request access to send and receive external email through this gateway.
      ; You will need a Python bridge connected to handle the actual email delivery.
    ==
    ;div(style "margin-bottom: 16px;")
      ;h3(style "margin-bottom: 8px;"): 1. Set your domain
      ;form(method "post", action "/mail/gateway/set-domain", style "display: flex; gap: 8px; align-items: center; margin-bottom: 16px;")
        ;input(type "text", name "domain", value (trip domain), placeholder "Enter your domain", class "gw-search", style "width: 250px;");
        ;button(type "submit", class "gw-filter"): Save
      ==
    ==
    ;div(style "margin-bottom: 16px;")
      ;h3(style "margin-bottom: 8px;"): 2. Add DNS record
      ;p(class "help", style "margin-bottom: 8px; line-height: 1.6;"): Add a TXT record to your domain's DNS settings to prove you own it:
      ;p(class "help", style "margin-bottom: 8px; line-height: 1.6; font-size: 12px; color: var(--muted);"): You will also need to configure Cloudflare Email Routing (for inbound) and your email provider's DNS records — SPF, DKIM, MX (e.g. Mailgun, Resend, SendGrid).
      ;div(style "background: var(--info-bg); padding: 12px; border-radius: 6px; font-family: monospace; font-size: 13px; line-height: 1.8;")
        ;div
          ;span(style "color: var(--muted);"): Type:
          ;span(style "font-weight: 600;"): {" TXT"}
        ==
        ;div
          ;span(style "color: var(--muted);"): Name:
          ;span(style "font-weight: 600;"): {" _urbit-gw"}
        ==
        ;div
          ;span(style "color: var(--muted);"): Value:
          ;span(style "font-weight: 600;"): {" {our-name}"}
        ==
      ==
    ==
    ;div(style "margin-bottom: 16px;")
      ;h3(style "margin-bottom: 8px;"): 3. Enable
      ;form(method "post", action "/mail/gateway/enable")
        ;input(type "hidden", name "enabled", value "on");
        ;button(type "submit", class "btn btn-approve", style "padding: 8px 24px; font-size: 14px;"): Enable Gateway Mode
      ==
    ==
  ==
::  render-gateway-admin: gateway whitelist management page
::
++  render-gateway-admin
  |=  [whitelist=(map @p wl-entry) auto-approve=? domain=@t page=@ud per-page=@ud status-filter=(unit @tas) search=(unit @t) out-today=@ud out-month=@ud public=? acfg=alias-cfg gw-aliases=(map @t alias-entry) invite-code=(unit @t) alias-filter=(unit @tas) alias-search=(unit @t) alias-page=@ud payments=(map @t pending-payment)]
  ^-  manx
  ::  alias filtering/pagination
  =/  all-aliases=(list [name=@t ent=alias-entry])  ~(tap by gw-aliases)
  =/  filtered-aliases=(list [name=@t ent=alias-entry])
    ?~  alias-filter  all-aliases
    (skim all-aliases |=([* e=alias-entry] =(status.e u.alias-filter)))
  =.  filtered-aliases
    ?~  alias-search  filtered-aliases
    =/  q=tape  (cass (trip u.alias-search))
    %+  skim  filtered-aliases
    |=  [n=@t e=alias-entry]
    ?|  !=(~ (find q (cass (trip n))))
        !=(~ (find q (cass (scow %p owner.e))))
    ==
  =/  alias-total=@ud  (lent filtered-aliases)
  =/  alias-per-page=@ud  20
  =/  alias-total-pages=@ud  ?:(=(0 alias-total) 1 (add (div alias-total alias-per-page) ?:(=(0 (mod alias-total alias-per-page)) 0 1)))
  =/  alias-skip=@ud  (mul (dec alias-page) alias-per-page)
  =/  alias-paged=(list [name=@t ent=alias-entry])  (scag alias-per-page (slag alias-skip filtered-aliases))
  =/  alias-base=tape
    %+  weld  "/mail/gateway"
    %+  weld  ?~(alias-filter "" (weld "?af=" (trip u.alias-filter)))
    ?~  alias-search  ""
    (weld ?~(alias-filter "?" "&") (weld "aq=" (url-enc:ui (trip u.alias-search))))
  ::  whitelist filtering
  =/  all-entries=(list [@p wl-entry])  ~(tap by whitelist)
  ::  apply status filter
  =/  filtered=(list [@p wl-entry])
    ?~  status-filter  all-entries
    (skim all-entries |=([* e=wl-entry] =(status.e u.status-filter)))
  ::  apply search filter
  =.  filtered
    ?~  search  filtered
    =/  q=tape  (cass (trip u.search))
    (skim filtered |=([s=@p *] !=(~ (find q (cass (scow %p s))))))
  =/  sorted=(list [@p wl-entry])
    %+  sort  filtered
    |=  [[* a=wl-entry] [* b=wl-entry]]
    (gth requested.a requested.b)
  =/  total-all=@ud  (lent all-entries)
  =/  total=@ud  (lent filtered)
  =/  pending-count=@ud
    (lent (skim all-entries |=([* e=wl-entry] =(status.e %pending))))
  =/  total-pages=@ud  ?:(=(0 total) 1 (add (div total per-page) ?:(=(0 (mod total per-page)) 0 1)))
  =/  skip=@ud  (mul (dec page) per-page)
  =/  paged=(list [@p wl-entry])  (scag per-page (slag skip sorted))
  ::  build base url with filters for pagination
  =/  base-url=tape
    %+  weld  "/mail/gateway"
    %+  weld  ?~(status-filter "" (weld "?filter=" (trip u.status-filter)))
    ?~  search  ""
    (weld ?~(status-filter "?" "&") (weld "q=" (url-enc:ui (trip u.search))))
  =/  total-in=@ud
    %-  ~(rep by whitelist)
    |=  [[* e=wl-entry] acc=@ud]
    (add acc in.e)
  =/  total-out=@ud
    %-  ~(rep by whitelist)
    |=  [[* e=wl-entry] acc=@ud]
    (add acc out.e)
  ;div(class "compose-form")
    ;h2: Gateway Admin
    ;div(style "margin-bottom: 16px; display: flex; gap: 12px; align-items: center; flex-wrap: wrap;")
      ;div(style "display: flex; gap: 8px; align-items: center;")
        ;span(style "color: var(--muted); font-size: 13px;"): Domain:
        ;form(method "post", action "/mail/gateway/set-domain", style "display: flex; gap: 6px; align-items: center;")
          ;input(type "text", name "domain", value (trip domain), placeholder "Enter your domain", class "gw-search", style "width: 180px;");
          ;button(type "submit", class "gw-filter"): Save
        ==
      ==
      ;div(style "display: flex; align-items: center; gap: 8px;")
        ;span(style "font-size: 13px; color: var(--muted);"): Registry:
        ;span(style "font-size: 13px; font-weight: 600; color: {?:(public "var(--color-success)" "var(--muted)")};"): {?:(public "listed" "unlisted")}
        ;form(method "post", action "/mail/gateway/set-public", style "display:inline")
          ;input(type "hidden", name "public", value ?:(public "off" "on"));
          ;button(type "submit", class "btn btn-secondary", style "padding: 4px 10px; font-size: 12px;"): {?:(public "Make private" "Make public")}
        ==
      ==
      ;form(method "post", action "/mail/gateway/enable", style "margin-left: auto;")
        ;input(type "hidden", name "enabled", value "off");
        ;button(type "submit", class "btn btn-reject", style "padding: 6px 14px;"): Disable Gateway
      ==
    ==
    ;div(style "margin-bottom: 16px; display: flex; gap: 0; border-bottom: 2px solid var(--border);")
      ;button(class "gw-tab active", data-tab "whitelist", type "button", style "padding: 8px 20px; border: none; background: none; cursor: pointer; font-size: 14px; border-bottom: 2px solid var(--link); margin-bottom: -2px; color: var(--text); font-weight: 600;"): 🚀 Ships ({(a-co:co total-all)})
      ;button(class "gw-tab", data-tab "aliases", type "button", style "padding: 8px 20px; border: none; background: none; cursor: pointer; font-size: 14px; border-bottom: 2px solid transparent; margin-bottom: -2px; color: var(--muted);"): 🏷 Aliases ({(a-co:co ~(wyt by gw-aliases))})
    ==
    ;div(class "gw-tab-panel", data-tab "whitelist")
    ;div(style "color: var(--th-text); margin-bottom: 15px; display: flex; gap: 20px; flex-wrap: wrap; align-items: center;")
      ;span: {(a-co:co total-all)} ships, {(a-co:co pending-count)} pending
      ;span(style "color: var(--muted);"): {(a-co:co total-in)} in / {(a-co:co total-out)} out (all time)
    ==
    ;div(style "color: var(--th-text); margin-bottom: 15px; display: flex; gap: 20px; flex-wrap: wrap; align-items: center;")
      ;span: Outbound today: {(a-co:co out-today)} / 100
      ;span: This month: {(a-co:co out-month)} / 3,000
    ==
    ;div(style "margin-bottom: 20px; display: flex; gap: 16px; align-items: center; flex-wrap: wrap;")
      ;form(method "post", action "/mail/gateway/add", style "display: flex; gap: 8px; align-items: center;")
        ;input(type "text", name "ship", placeholder "~sampel-palnet", required "", style "width: 250px; max-width: 100%; margin: 0; padding: 8px 10px; border: 1px solid var(--input-border); border-radius: 3px; background: var(--input-bg); color: var(--text);");
        ;button(type "submit", class "btn", style "padding: 6px 14px;"): Add Ship
      ==
      ;form(method "post", action "/mail/gateway/auto-approve", style "display: flex; gap: 8px; align-items: center;")
        ;input(type "hidden", name "auto", value ?:(auto-approve "off" "on"));
        ;button(type "submit", class ?:(auto-approve "btn btn-approve" "btn btn-reject"), style "padding: 6px 14px;")
          ;+  ?:  auto-approve
                ;span: Auto-approve: ON (click to disable)
              ;span: Auto-approve: OFF (click to enable)
        ==
      ==
      ;*  ?.  (gth pending-count 0)  ~
          :~  ;form(method "post", action "/mail/gateway/approve-all", style "display:inline")
                ;button(type "submit", class "btn btn-approve", style "padding: 6px 14px;"): Approve All ({(a-co:co pending-count)})
              ==
          ==
    ==
    ;div(style "margin-bottom: 12px; display: flex; gap: 4px; align-items: center; flex-wrap: wrap;")
      ;a(href "/mail/gateway", class "gw-filter{?:(=(~ status-filter) " active" "")}"): All
      ;a(href ?~(search "/mail/gateway?filter=pending" "/mail/gateway?filter=pending&q={(url-enc:ui (trip u.search))}"), class "gw-filter{?:(?=([~ %pending] status-filter) " active" "")}"): Pending
      ;a(href ?~(search "/mail/gateway?filter=approved" "/mail/gateway?filter=approved&q={(url-enc:ui (trip u.search))}"), class "gw-filter{?:(?=([~ %approved] status-filter) " active" "")}"): Approved
      ;a(href ?~(search "/mail/gateway?filter=rejected" "/mail/gateway?filter=rejected&q={(url-enc:ui (trip u.search))}"), class "gw-filter{?:(?=([~ %rejected] status-filter) " active" "")}"): Rejected
      ;*  ?.  ?=(^ status-filter)  ~
          :~  ;a(href ?~(search "/mail/gateway" "/mail/gateway?q={(url-enc:ui (trip u.search))}"), style "font-size: 13px; color: var(--muted); margin-left: 4px;"): reset
          ==
      ;form(method "get", action "/mail/gateway", style "display: flex; gap: 4px; align-items: center; margin-left: auto;")
        ;*  ?~  status-filter  ~
            :~  ;input(type "hidden", name "filter", value (trip u.status-filter));
            ==
        ;input(type "text", name "q", placeholder "~ship...", value ?~(search "" (trip u.search)), class "gw-search", style "width: 140px;");
        ;button(type "submit", class "gw-filter"): Search
        ;*  ?.  ?=(^ search)  ~
            :~  ;a(href ?~(status-filter "/mail/gateway" "/mail/gateway?filter={(trip u.status-filter)}"), style "font-size: 13px; color: var(--color-error); margin-left: 4px;"): Clear
            ==
      ==
    ==
    ;*  ?:  =(~ all-entries)
          :~  ;p(style "color: var(--muted);"): No ships in whitelist.
          ==
        :~  ;div(style "overflow-x: auto;")
            ;table(class "gateway-table")
              ;thead
                ;tr
                  ;th: Ship
                  ;th: Status
                  ;th: In
                  ;th: Out
                  ;th: Requested
                  ;th: Actions
                ==
              ==
              ;tbody
                ;*  %+  turn  paged
                    |=  [ship=@p entry=wl-entry]
                    ;tr
                      ;td(style "display: flex; align-items: center; gap: 6px;")
                        ;span(class "sigil-wrap", data-patp (scow %p ship));
                        ;span: {(scow %p ship)}
                      ==
                      ;td
                        ;span(class "status-badge {(weld "status-" (trip status.entry))}"): {(trip status.entry)}
                      ==
                      ;td: {(a-co:co in.entry)}
                      ;td: {(a-co:co out.entry)}
                      ;td(class "date", data-da (scow %da requested.entry)): {(scag 18 (scow %da requested.entry))}
                      ;td
                        ;*  ?-  status.entry
                                %pending
                              :~  ;form(method "post", action "/mail/gateway/approve", style "display:inline")
                                    ;input(type "hidden", name "ship", value (scow %p ship));
                                    ;button(type "submit", class "btn-approve"): Approve
                                  ==
                                  ;form(method "post", action "/mail/gateway/reject", style "display:inline; margin-left: 4px;")
                                    ;input(type "hidden", name "ship", value (scow %p ship));
                                    ;button(type "submit", class "btn-reject"): Reject
                                  ==
                              ==
                                %approved
                              :~  ;form(method "post", action "/mail/gateway/remove", style "display:inline")
                                    ;input(type "hidden", name "ship", value (scow %p ship));
                                    ;button(type "submit", class "btn btn-danger", style "padding: 4px 10px; font-size: 12px;"): Remove
                                  ==
                              ==
                                %rejected
                              :~  ;form(method "post", action "/mail/gateway/remove", style "display:inline")
                                    ;input(type "hidden", name "ship", value (scow %p ship));
                                    ;button(type "submit", class "btn btn-danger", style "padding: 4px 10px; font-size: 12px;"): Remove
                                  ==
                              ==
                            ==
                      ==
                    ==
              ==
            ==
          ==
        ==
    ;+  (render-pagination:ui page total-pages base-url "")
    ==
    ;div(class "gw-tab-panel", data-tab "aliases", style "display: none;")
      ;h3(style "margin-bottom: 10px;"): Email Aliases
      ;div(style "display: flex; align-items: center; gap: 8px; margin-bottom: 12px;")
        ;span(style "font-size: 13px; color: var(--muted);"): Aliases:
        ;span(style "font-size: 13px; font-weight: 600; color: {?:(aliases-enabled.acfg "var(--color-success)" "var(--muted)")};"): {?:(aliases-enabled.acfg "enabled" "disabled")}
        ;form(method "post", action "/mail/gateway/set-aliases-enabled", style "display:inline")
          ;input(type "hidden", name "enabled", value ?:(aliases-enabled.acfg "off" "on"));
          ;button(type "submit", class "btn btn-secondary", style "padding: 4px 10px; font-size: 12px;"): {?:(aliases-enabled.acfg "Disable" "Enable")}
        ==
        ;span(style "font-size: 11px; color: var(--muted);"): {(a-co:co ~(wyt by gw-aliases))} aliases registered
      ==
      ;div(style "margin-bottom: 16px; padding: 16px; background: var(--info-bg); border-radius: 6px;")
        ;h4(style "margin-bottom: 12px;"): Alias Configuration
        ;div(class "alias-cfg-grid", style "display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 16px;")
          ;div(style "padding: 12px; background: var(--bg); border-radius: 6px; border: 1px solid var(--border);")
            ;h5(style "margin: 0 0 10px 0; font-size: 13px;"): Length Rules
            ;form(method "post", action "/mail/gateway/set-alias-config")
              ;div(style "display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; margin-bottom: 10px;")
                ;div(style "display: flex; flex-direction: column;")
                  ;label(style "font-size: 11px; color: var(--muted); margin-bottom: 4px;"): Min length
                  ;input(type "number", name "min-len", value (a-co:co min-len.acfg), min "1", style "width: 100%; margin: 0; padding: 6px 8px; box-sizing: border-box;");
                ==
                ;div(style "display: flex; flex-direction: column;")
                  ;label(style "font-size: 11px; color: var(--muted); margin-bottom: 4px;"): Free min length
                  ;input(type "number", name "free-min-len", value (a-co:co free-min-len.acfg), min "1", style "width: 100%; margin: 0; padding: 6px 8px; box-sizing: border-box;");
                ==
                ;div(style "display: flex; flex-direction: column;")
                  ;label(style "font-size: 11px; color: var(--muted); margin-bottom: 4px;"): Free limit/ship
                  ;input(type "number", name "free-limit", value (a-co:co free-limit.acfg), min "0", style "width: 100%; margin: 0; padding: 6px 8px; box-sizing: border-box;");
                ==
              ==
              ;button(type "submit", class "btn", style "padding: 6px 14px; font-size: 12px;"): Save Rules
            ==
            ;p(style "font-size: 11px; color: var(--muted); margin-top: 8px; margin-bottom: 0;"): Aliases shorter than free min length require invite or payment.
          ==
          ;div(style "padding: 12px; background: var(--bg); border-radius: 6px; border: 1px solid var(--border);")
            ;div(style "display: flex; align-items: center; gap: 8px; margin-bottom: 10px;")
              ;h5(style "margin: 0; font-size: 13px;"): ETH Payment
              ;span(style "font-size: 11px; font-weight: 600; padding: 2px 8px; border-radius: 10px; background: {?:(payment-enabled.acfg "var(--color-success)" "var(--muted)")}; color: #fff;"): {?:(payment-enabled.acfg "on" "off")}
            ==
            ;form(method "post", action "/mail/gateway/set-payment-config")
              ;div(style "display: flex; flex-direction: column; gap: 8px; margin-bottom: 10px;")
                ;div(style "display: flex; flex-direction: column;")
                  ;label(style "font-size: 11px; color: var(--muted); margin-bottom: 4px;"): Wallet address
                  ;input(type "text", name "wallet", value (trip payment-wallet.acfg), placeholder "0x...", style "width: 100%; margin: 0; padding: 6px 8px; box-sizing: border-box; font-size: 12px; font-family: monospace;");
                ==
                ;div(style "display: grid; grid-template-columns: 1fr 1fr; gap: 10px;")
                  ;div(style "display: flex; flex-direction: column;")
                    ;label(style "font-size: 11px; color: var(--muted); margin-bottom: 4px;"): Base price (ETH)
                    ;input(type "text", id "pay-price-eth-input", value (wei-to-eth-price:ui ?:(=(0 base-price.acfg) 5.000.000.000.000.000 base-price.acfg)), placeholder "0.0050", style "width: 100%; margin: 0; padding: 6px 8px; box-sizing: border-box; font-family: monospace;");
                    ;input(type "hidden", name "price", id "pay-price-wei", value ?:(=(0 base-price.acfg) "5000000000000000" (a-co:co base-price.acfg)));
                    ;span(id "pay-price-hint", style "font-size: 10px; color: var(--muted); margin-top: 2px;"): precision: 0.0001 ETH (4 decimals)
                  ==
                  ;div(style "display: flex; flex-direction: column;")
                    ;label(style "font-size: 11px; color: var(--muted); margin-bottom: 4px;"): Etherscan API key
                    ;input(type "text", name "key", value (trip etherscan-key.acfg), placeholder "API key", style "width: 100%; margin: 0; padding: 6px 8px; box-sizing: border-box; font-size: 12px;");
                  ==
                ==
              ==
              ;button(type "submit", class "btn", style "margin-top: 10px; padding: 6px 14px; font-size: 12px;"): Save Payment Config
            ==
            ;form(method "post", action "/mail/gateway/toggle-payments", style "margin-top: 8px;")
              ;button(type "submit", class ?:(payment-enabled.acfg "btn-approve" "btn-reject"), style "padding: 6px 14px; font-size: 12px;"): {?:(payment-enabled.acfg "Payments ON (click to disable)" "Payments OFF (click to enable)")}
            ==
          ==
        ==
        ;div(style "padding: 12px; background: var(--bg); border-radius: 6px; border: 1px solid var(--border);")
          ;h5(style "margin: 0 0 8px 0; font-size: 13px;"): Pricing by Alias Length
          ;div(style "overflow-x: auto;")
          ;table(style "border-collapse: collapse; font-size: 12px; width: 100%; max-width: 800px; margin: 0 auto;")
            ;thead
              ;tr(style "border-bottom: 1px solid var(--border);")
                ;th(style "text-align: left; padding: 4px 8px; color: var(--muted); font-weight: 600;"): Length
                ;th(style "text-align: left; padding: 4px 8px; color: var(--muted); font-weight: 600;"): Type
                ;th(style "text-align: center; padding: 4px 8px; color: var(--muted); font-weight: 600;"): Multiplier
                ;th(style "text-align: right; padding: 4px 8px; color: var(--muted); font-weight: 600;"): Price
              ==
            ==
            ;tbody(id "price-table-body")
              ;*  =/  rows=(list manx)  ~
                  =/  len=@ud  min-len.acfg
                  |-  ^-  (list manx)
                  ?:  (gth len (add free-min-len.acfg 2))
                    (flop rows)
                  =/  is-free=?  (gte len free-min-len.acfg)
                  =/  type-text=tape  ?:(is-free "Free" "Paid")
                  =/  exp=@ud  ?:(is-free 0 (sub free-min-len.acfg +(len)))
                  =/  mult=@ud  ?:(is-free 0 (bex exp))
                  =/  tier-price=@ud  ?:(is-free 0 (mul base-price.acfg mult))
                  =/  mult-text=tape  ?:(is-free "-" (weld (a-co:co mult) "x"))
                  =/  price-text=tape
                    ?:  is-free  "free"
                    (weld (wei-to-eth-price:ui tier-price) " ETH")
                  =/  row=manx
                    ;tr(class ?:(is-free "" "paid-row"), style "border-bottom: 1px solid var(--border);", data-len (a-co:co len), data-free ?:(is-free "1" "0"), data-exp (a-co:co exp))
                      ;td(style "padding: 4px 8px;"): {(a-co:co len)} chars
                      ;td(style "padding: 4px 8px;"): {type-text}
                      ;td(style "padding: 4px 8px; text-align: center;"): {mult-text}
                      ;td(style "padding: 4px 8px; text-align: right; font-family: monospace;", class "price-cell"): {price-text}
                    ==
                  $(len +(len), rows [row rows])
            ==
          ==
          ==
          ;p(style "font-size: 11px; color: var(--muted); margin-top: 6px; margin-bottom: 0;"): Price = base * 2^(free_min_len - length - 1). Format: 0.xxxxyyyyy where xxxx=price, yyyyy=random ID.
        ==
      ==
      ;*  ?:  =(~ payments)  ~
          :~  ;div(style "margin-bottom: 16px; padding: 12px; background: var(--info-bg); border-radius: 6px;")
                ;h4(style "margin-bottom: 8px;"): Pending Payments ({(a-co:co ~(wyt by payments))})
                ;*  %+  turn  ~(tap by payments)
                    |=  [name=@t pp=pending-payment]
                    ;div(style "display: flex; align-items: center; gap: 8px; padding: 6px 0; border-bottom: 1px solid var(--border); flex-wrap: wrap;")
                      ;span(style "font-weight: 600;"): {(trip name)}
                      ;span(style "font-size: 11px; color: var(--muted);"): → {(scow %p ship.pp)}
                      ;span(style "font-size: 11px; color: var(--muted);"): {(wei-to-eth-display:ui amount.pp)} ETH
                      ;span(class "pp-timer", data-created (scow %da created.pp), style "font-size: 11px; color: var(--color-error); font-weight: 600;");
                    ==
              ==
          ==
      ;div(style "margin-bottom: 16px;")
        ;h4(style "margin-bottom: 8px;"): Generate Invite Code
        ;form(method "post", action "/mail/gateway/generate-invite", style "display: flex; gap: 8px; align-items: center;")
          ;input(type "text", name "alias", placeholder "alias-name", required "", pattern "[a-z0-9][a-z0-9_-]*", title "a-z, 0-9, hyphen, underscore. No dots.", style "width: 180px; margin: 0;");
          ;button(type "submit", class "btn", style "padding: 6px 14px;"): Generate
        ==
      ==
      ;*  ?~  invite-code  ~
          =/  inv=tape  (trip u.invite-code)
          ?:  =("error:" (scag 6 inv))
            =/  err-msg=tape  (slag 6 inv)
            :~  ;div(style "margin-bottom: 16px; background: var(--color-error); color: #fff; padding: 12px 16px; border-radius: 6px;")
                  ;p(style "margin: 0; font-weight: 600;"): {err-msg}
                ==
            ==
          :~  ;div(style "margin-bottom: 16px; background: var(--color-success); color: #fff; padding: 12px 16px; border-radius: 6px;")
                ;p(style "margin: 0 0 8px 0; font-weight: 600;"): Invite code generated:
                ;code(style "display: block; padding: 8px; background: rgba(0,0,0,0.2); border-radius: 4px; word-break: break-all; user-select: all;"): {inv}
                ;button(class "copy-btn", data-copy (trip u.invite-code), style "margin-top: 8px;"): Copy
              ==
          ==
      ;h4(style "margin-bottom: 8px;"): Alias List
      ;div(style "margin-bottom: 12px; display: flex; gap: 4px; align-items: center; flex-wrap: wrap;")
        ;a(href "/mail/gateway#aliases", class "gw-filter{?:(=(~ alias-filter) " active" "")}"): All ({(a-co:co (lent all-aliases))})
        ;a(href "/mail/gateway?af=active#aliases", class "gw-filter{?:(?=([~ %active] alias-filter) " active" "")}"): Active
        ;a(href "/mail/gateway?af=reserved#aliases", class "gw-filter{?:(?=([~ %reserved] alias-filter) " active" "")}"): Reserved
        ;a(href "/mail/gateway?af=disabled#aliases", class "gw-filter{?:(?=([~ %disabled] alias-filter) " active" "")}"): Disabled
        ;a(href "/mail/gateway?af=blocked#aliases", class "gw-filter{?:(?=([~ %blocked] alias-filter) " active" "")}"): Blocked
        ;form(method "get", action "/mail/gateway", style "display: flex; gap: 4px; align-items: center; margin-left: auto;")
          ;input(type "text", name "aq", placeholder "alias or ~ship...", value ?~(alias-search "" (trip u.alias-search)), class "gw-search", style "width: 160px;");
          ;button(type "submit", class "gw-filter", onclick "this.form.action='/mail/gateway#aliases'"): Search
          ;*  ?.  ?=(^ alias-search)  ~
              :~  ;a(href ?~(alias-filter "/mail/gateway#aliases" "/mail/gateway?af={(trip u.alias-filter)}#aliases"), style "font-size: 13px; color: var(--color-error); margin-left: 4px;"): Clear
              ==
        ==
      ==
      ;*  ?:  =(~ alias-paged)
            :~  ;p(style "color: var(--muted);"): {?:(=(~ all-aliases) "No aliases registered yet." "No matching aliases.")}
            ==
          %+  turn  alias-paged
          |=  [name=@t ent=alias-entry]
          ;div(style "display: flex; align-items: center; margin-bottom: 6px; gap: 8px; padding: 8px 12px; background: var(--info-bg); border-radius: 6px;")
            ;span(class "sigil-wrap", data-patp (scow %p owner.ent));
            ;div(style "flex: 1; min-width: 0;")
              ;div(style "font-weight: 600;")
                ;span: {(trip name)}
                ;span(class "alias-domain"): @{(trip domain)}
              ==
              ;div(style "font-size: 11px; color: var(--muted);"): {(scow %p owner.ent)}
            ==
            ;span(class "status-badge {(weld "status-" (trip status.ent))}", style "flex-shrink: 0;"): {(trip status.ent)}
            ;div(style "display: flex; gap: 4px; flex-shrink: 0;")
              ;*  ?:  =(%reserved status.ent)
                    :~  ;button(class "copy-btn", data-copy (trip invite-code.ent), style "padding: 4px 10px; font-size: 12px;"): Copy code
                        ;form(method "post", action "/mail/gateway/unreserve-alias", style "display:inline")
                          ;input(type "hidden", name "alias", value (trip name));
                          ;button(type "submit", class "btn btn-danger", style "padding: 4px 10px; font-size: 12px;"): Cancel
                        ==
                    ==
                  ?:  =(%blocked status.ent)
                    :~  ;form(method "post", action "/mail/gateway/unblock-alias", style "display:inline")
                          ;input(type "hidden", name "alias", value (trip name));
                          ;button(type "submit", class "btn btn-approve", style "padding: 4px 10px; font-size: 12px;"): Unblock
                        ==
                    ==
                  :~  ;form(method "post", action "/mail/gateway/block-alias", style "display:inline")
                        ;input(type "hidden", name "alias", value (trip name));
                        ;button(type "submit", class "btn btn-danger", style "padding: 4px 10px; font-size: 12px;"): Block
                      ==
                  ==
            ==
          ==
      ;+  (render-pagination:ui alias-page alias-total-pages (weld alias-base ?~(alias-filter ?~(alias-search "?ap=" "&ap=") "&ap=")) "#aliases")
    ==
  ==
::  render-buy-alias: dedicated paid alias purchase page
::
++  render-buy-alias
  |=  [gws=(set @p) doms=(map @p @t) gw=(unit @p) pp=(unit [alias=@t amount=@ud wallet=@t created=@da]) err=(unit @t) pending-alias=(unit @t)]
  ^-  manx
  ::  waiting state: poke sent, gateway hasn't responded yet
  ?:  ?&(?=(~ pp) ?=(^ pending-alias))
    ;div(class "compose-form", id "payment-waiting", data-alias (trip u.pending-alias))
      ;h2: Requesting price for "{(trip u.pending-alias)}"...
      ;p(style "color: var(--muted); margin: 16px 0;"): Waiting for gateway response. This usually takes a few seconds.
      ;div(style "text-align: center; margin: 24px 0;")
        ;div(style "display: inline-block; width: 32px; height: 32px; border: 3px solid var(--border); border-top-color: var(--link); border-radius: 50%; animation: spin 1s linear infinite;");
      ==
      ;div(style "margin-top: 16px;")
        ;a(href "/mail/settings#s-aliases", class "btn btn-secondary", style "padding: 6px 14px; font-size: 13px;"): Cancel
      ==
    ==
  ?~  pp
    ::  step 1: choose alias
    ;div(class "compose-form")
      ;h2: Buy a Short Alias
      ;div(style "margin-bottom: 16px; padding: 12px; background: var(--info-bg); border-radius: 6px; font-size: 13px; line-height: 1.6;")
        ;p: Aliases of 10+ characters are free (up to 5 per ship).
        ;p: Shorter aliases require an ETH payment. Price doubles for each character shorter.
        ;p(style "margin-top: 4px; font-weight: 600;"): Ethereum mainnet only. L2 payments (Arbitrum, Base, etc.) are not detected.
      ==
      ;*  ?~  err  ~
          =/  err-msgs=(map @t tape)
            %-  my
            :~  ['invalid' "Invalid alias format"]
                ['taken' "This alias is already taken"]
                ['expired' "Payment expired. Try again."]
            ==
          =/  msg=tape
            (fall (~(get by err-msgs) u.err) (trip u.err))
          :~  ;p(style "margin-bottom: 12px; padding: 8px 12px; border-radius: 4px; font-size: 13px; background: var(--color-error); color: #fff;"): {msg}
          ==
      ;form(id "alias-form", method "post", action "/mail/request-paid-alias", data-free-min-len "10", data-min-len "5", data-base-price "5000000000000000")
        ;div(style "display: flex; gap: 8px; align-items: center; flex-wrap: wrap; margin-bottom: 12px;")
          ;input(type "text", name "alias", placeholder "short-alias", required "", pattern "[a-z0-9][a-z0-9_-]*", title "a-z, 0-9, hyphen, underscore", style "width: 220px; margin: 0;", autocomplete "off");
          ;select(name "gateway", style "margin: 0; padding: 6px 8px;")
            ;*  %+  turn  ~(tap in gws)
                |=  g=@p
                =/  d=(unit @t)  (~(get by doms) g)
                ;option(value (scow %p g)): {?~(d (scow %p g) (trip u.d))}
          ==
        ==
        ;span(id "alias-price", style "font-size: 16px; font-weight: 600; margin-bottom: 16px; min-height: 24px;");
        ;button(id "alias-submit", type "submit", class "btn", style "padding: 8px 24px; font-size: 15px;"): Request Purchase
      ==
      ;div(style "margin-top: 16px;")
        ;a(href "/mail/settings", class "btn btn-secondary", style "padding: 6px 14px; font-size: 13px;"): Back to Settings
      ==
    ==
  ::  step 2: payment details
  ;div(class "compose-form", id "payment-page", data-wallet (trip wallet.u.pp), data-amount-wei (a-co:co amount.u.pp), data-amount-eth (wei-to-eth-display:ui amount.u.pp), data-alias (trip alias.u.pp), data-created (scow %da created.u.pp), data-gw ?~(gw "" (scow %p u.gw)))
    ;h2: Purchase alias "{(trip alias.u.pp)}"
    ;div(style "text-align: center; margin: 20px 0;")
      ;img(id "qr-img", src "", alt "Loading QR...", style "border-radius: 8px;");
      ;p(style "font-size: 12px; color: var(--muted); margin-top: 6px;"): Scan with your Ethereum wallet
    ==
    ;div(style "margin: 16px 0;")
      ;label(style "font-size: 12px; color: var(--muted); display: block; margin-bottom: 4px;"): Send EXACTLY:
      ;div(style "display: flex; gap: 8px; align-items: center;")
        ;code(style "padding: 10px 14px; background: var(--input-bg); border: 1px solid var(--input-border); border-radius: 4px; font-size: 18px; font-weight: 700; word-break: break-all;"): {(wei-to-eth-display:ui amount.u.pp)} ETH
        ;button(class "copy-btn", data-copy (wei-to-eth-display:ui amount.u.pp), type "button"): Copy
      ==
    ==
    ;div(style "margin: 16px 0;")
      ;label(style "font-size: 12px; color: var(--muted); display: block; margin-bottom: 4px;"): To address:
      ;div(style "display: flex; gap: 8px; align-items: center;")
        ;code(style "padding: 10px 14px; background: var(--input-bg); border: 1px solid var(--input-border); border-radius: 4px; font-size: 14px; word-break: break-all;"): {(trip wallet.u.pp)}
        ;button(class "copy-btn", data-copy (trip wallet.u.pp), type "button"): Copy
      ==
    ==
    ;p(style "font-size: 13px; color: var(--color-error); margin: 12px 0; font-weight: 600;"): The amount includes a unique identifier. Do NOT round. Send the exact amount.
    ;p(style "font-size: 12px; color: var(--muted); margin: 4px 0;"): Ethereum mainnet only. L2 payments will not be detected.
    ;div(id "payment-timer", style "font-size: 16px; font-weight: 600; margin: 16px 0;"): Expires in: --:--
    ;div(id "payment-status", style "font-size: 14px; margin: 8px 0; color: var(--muted);"): Waiting for payment... You can close this page — when payment is confirmed, your alias will appear in Settings automatically.
    ;hr(style "margin: 20px 0; border: none; border-top: 1px solid var(--border);");
    ;p(style "font-size: 13px; color: var(--muted); margin-bottom: 8px;"): Or enter transaction hash manually:
    ;form(method "post", action "/mail/verify-payment", style "display: flex; gap: 8px; align-items: center; flex-wrap: wrap;")
      ;input(type "hidden", name "alias", value (trip alias.u.pp));
      ;input(type "hidden", name "gateway", value ?~(gw "" (scow %p u.gw)));
      ;input(type "text", name "tx-hash", placeholder "0x... transaction hash", required "", style "flex: 1; min-width: 250px; margin: 0;");
      ;button(type "submit", class "btn", style "padding: 6px 14px;"): Verify Payment
    ==
    ;div(style "margin-top: 16px; display: flex; gap: 8px;")
      ;form(method "post", action "/mail/cancel-payment")
        ;button(type "submit", class "btn btn-danger", style "padding: 6px 14px;"): Cancel Purchase
      ==
      ;a(href "/mail/settings", class "btn btn-secondary", style "padding: 6px 14px;"): Back to Settings
    ==
    ;*  ?~  gw  ~
        =/  dom  (~(get by doms) u.gw)
        ?~  dom  ~
        =/  support-email=tape  (weld "admin.support.aliases@" (trip u.dom))
        =/  support-ship=tape  (scow %p u.gw)
        =/  subj-mail=tape  (weld "Alias%20" (weld (trip alias.u.pp) "%20payment%20question"))
        =/  subj-web=tape  (weld "Alias+" (weld (trip alias.u.pp) "+payment+question"))
        :~  ;p(style "margin-top: 16px; font-size: 12px; color: var(--muted);")
              ;span: Questions? Contact
              ;a(href "/mail/compose?to={support-ship}&subject={subj-web}&labels=support,aliases", target "_blank", style "margin-left: 4px;"): {support-ship}
              ;span(style "margin: 0 4px;"): or
              ;a(href "mailto:{support-email}?subject={subj-mail}", style "margin-left: 0;"): {support-email}
            ==
        ==
  ==
--
