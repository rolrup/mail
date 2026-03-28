/-  *mail-client
/-  *mail-gateway
/+  ui=mail-ui
|%
::  render-settings: gateway settings page
::
++  render-settings
  |=  [our=@p gw=(unit @p) gws=(set @p) doms=(map @p @t) gwst=(map @p ?(%pending %approved %rejected)) fwds=(list fwd-rule) reg-gws=(map @p reg-entry) reg=(unit @p) aliases=(map @p (list [@t ?])) pp=(unit [alias=@t amount=@ud wallet=@t created=@da]) msg=(unit @t) is-gw=? gw-als=(map @p [on=? min=@ud free-min=@ud base=@ud pay-on=?]) icon-url=(unit @t)]
  ^-  manx
  =/  ship-name=tape  (slag 1 (scow %p our))
  =/  addrs=(list [gw=@p dom=@t])
    %+  skim  ~(tap by doms)
    |=  [g=@p d=@t]
    !=('' d)
  ;div(class "compose-form")
    ;h2: Settings
    ;div(style "margin-bottom: 20px; display: flex; gap: 10px; align-items: center; flex-wrap: wrap;")
      ;button(id "push-toggle", class "btn", type "button"): Enable notifications
      ;a(href "/mail/backup", class "btn btn-secondary"): Backup & Restore
      ;a(href "/mail/donate", class "btn btn-secondary"): Support Urbit Mail
    ==
    ;div(style "background: var(--info-bg); padding: 15px; border-radius: 4px; margin-bottom: 20px;")
      ;p(style "font-size: 14px; color: var(--th-text);"): Your email addresses:
      ;*  ?~  addrs
            :~  ;p(style "color: var(--muted); margin-top: 4px;"): (no domains available yet)
            ==
          %+  turn  addrs
          |=  [g=@p d=@t]
          =/  addr=tape  (weld ship-name (weld "@" (trip d)))
          ;div(style "display: flex; align-items: center; gap: 8px; margin-top: 6px; flex-wrap: wrap;")
            ;span(class "sigil-wrap", data-patp (scow %p g));
            ;span(style "font-size: 16px; font-weight: bold; color: var(--link);"): {addr}
            ;button(class "copy-btn", data-copy addr): copy
            ;span(style "font-size: 11px; color: var(--muted); white-space: nowrap;"): via {(scow %p g)}
          ==
      ;*  =/  alias-addrs=(list [gw=@p a=@t dom=tape])
            %-  zing
            %+  turn  ~(tap by aliases)
            |=  [gw=@p als=(list [@t ?])]
            =/  d=(unit @t)  (~(get by doms) gw)
            =/  dt=tape  ?~(d "" (trip u.d))
            =/  active=(list @t)  (murn als |=([n=@t ac=?] ?:(ac `n ~)))
            ^-  (list [gw=@p a=@t dom=tape])
            ?:(=(~ dt) ~ (turn active |=(a=@t [gw a dt])))
          %+  turn  alias-addrs
          |=  [g=@p a=@t dom=tape]
          =/  addr=tape  (weld (trip a) (weld "@" dom))
          ;div(style "display: flex; align-items: center; gap: 8px; margin-top: 6px; flex-wrap: wrap;")
            ;span(class "ext-icon"): @
            ;span(style "font-size: 16px; font-weight: bold; color: var(--link);"): {addr}
            ;button(class "copy-btn", data-copy addr): copy
            ;span(style "font-size: 11px; color: var(--muted); white-space: nowrap;"): alias via {(scow %p g)}
          ==
    ==
    ;div(style "margin-top: 20px; margin-bottom: 16px; display: flex; gap: 0; border-bottom: 2px solid var(--border);")
      ;button(class "settings-tab active", data-tab "account", type "button", style "padding: 8px 20px; border: none; background: none; cursor: pointer; font-size: 14px; border-bottom: 2px solid var(--link); margin-bottom: -2px; color: var(--text); font-weight: 600;"): 🔧 Account
      ;button(class "settings-tab", data-tab "aliases", type "button", style "padding: 8px 20px; border: none; background: none; cursor: pointer; font-size: 14px; border-bottom: 2px solid transparent; margin-bottom: -2px; color: var(--muted);"): 🏷 Aliases
      ;button(class "settings-tab", data-tab "discovery", type "button", style "padding: 8px 20px; border: none; background: none; cursor: pointer; font-size: 14px; border-bottom: 2px solid transparent; margin-bottom: -2px; color: var(--muted);"): 🔍 Discovery
    ==
    ;div(class "settings-tab-panel", data-tab "account")
    ;div(style "padding-top: 5px;")
      ;h3(style "margin-bottom: 10px;"): Gateways
      ;p(class "help", style "margin-bottom: 10px;"): Ships that relay email. Used for both receiving and sending. The default gateway is used when composing new messages.
      ;*  ?:  =(~ gws)
            :~  ;p(style "color: var(--muted);"): No gateways configured
            ==
          %+  turn  ~(tap in gws)
          |=  g=@p
          =/  dom=(unit @t)  (~(get by doms) g)
          =/  is-default=?  ?~(gw %.n =(g u.gw))
          =/  st=(unit ?(%pending %approved %rejected))  (~(get by gwst) g)
          =/  dom-text=tape  ?~(dom "" ?:(=('' u.dom) "" (trip u.dom)))
          =/  has-dom=?  !=(~ dom-text)
          ;div(style "display: flex; align-items: center; margin-bottom: 8px; gap: 10px; padding: 10px 12px; background: var(--info-bg); border-radius: 6px;")
            ;span(class "sigil-wrap", data-patp (scow %p g));
            ;div(style "flex: 1; min-width: 0;")
              ;*  ?.  has-dom
                    :~  ;div
                          ;span(style "font-size: 13px;"): {(scow %p g)}
                        ==
                        ;div
                          ;span(style "font-size: 11px; color: var(--color-warning);"): (no domain)
                        ==
                    ==
                  :~  ;div
                        ;span(style "font-size: 15px; font-weight: 600;"): {dom-text}
                      ==
                      ;div
                        ;span(style "font-size: 11px; color: var(--muted);"): {(scow %p g)}
                      ==
                  ==
            ==
            ;*  ?~  st  ~
                :~  ;span(class "status-badge {(weld "status-" (trip u.st))}"): {(trip u.st)}
                ==
            ;*  =/  show-retry=?
                  ?|  ?&(?=(^ st) ?|(?=(%pending u.st) ?=(%rejected u.st)))
                      ?&(?=(^ st) ?=(%approved u.st) !has-dom)
                  ==
                ?.  show-retry  ~
                :~  ;form(method "post", action "/mail/re-request", style "display:inline")
                      ;input(type "hidden", name "ship", value (scow %p g));
                      ;button(type "submit", class "btn btn-secondary", style "padding: 4px 10px; font-size: 12px;"): {?:(has-dom "Re-request" "Refresh")}
                    ==
                ==
            ;*  ?:  is-default
                  :~  ;span(style "font-size: 11px; background: var(--link); color: #fff; padding: 2px 8px; border-radius: 10px;"): default
                  ==
                :~  ;form(method "post", action "/mail/settings", style "display:inline")
                      ;input(type "hidden", name "gateway", value (scow %p g));
                      ;button(type "submit", class "btn-source"): set default
                    ==
                ==
            ;form(method "post", action "/mail/remove-gateway", style "display:inline")
              ;input(type "hidden", name "ship", value (scow %p g));
              ;button(type "submit", class "btn btn-danger", style "padding: 4px 10px; font-size: 12px;"): Remove
            ==
          ==
      ;div(style "margin-top: 10px; display: flex; gap: 8px; align-items: center; flex-wrap: wrap;")
        ;form(method "post", action "/mail/add-gateway", style "display: flex; gap: 8px; align-items: center;")
          ;input(type "text", name "ship", placeholder "~sampel-palnet", required "", style "width: 250px; margin: 0;");
          ;button(type "submit", class "btn", style "padding: 6px 14px;"): Add Gateway
        ==
        ;span(style "color: var(--muted); font-size: 13px;"): or
        ;a(href "#", class "btn btn-secondary settings-tab-link", data-tab "discovery", style "padding: 6px 14px; font-size: 13px;"): Browse Registry
      ==
    ==
    ;div(style "margin-top: 30px; padding-top: 20px; border-top: 1px solid var(--border);")
      ;h3(style "margin-bottom: 10px;"): App Icon
      ;p(class "help", style "margin-bottom: 10px;"): Custom icon for PWA. Note: already installed PWA may need reinstall to update.
      ;div(style "display: flex; align-items: center; gap: 16px; flex-wrap: wrap;")
        ;img(src ?~(icon-url "/mail/icon-192.png" (trip u.icon-url)), onerror "this.src='/mail/icon-192.png'", style "width: 48px; height: 48px; border-radius: 8px; border: 1px solid var(--border);");
        ;form(method "post", action "/mail/set-icon", style "display: flex; gap: 8px; align-items: center; flex-wrap: wrap;")
          ;input(type "url", name "url", placeholder "https://example.com/icon.png", value ?~(icon-url "" (trip u.icon-url)), style "width: 280px; max-width: 100%; margin: 0;");
          ;button(type "submit", class "btn", style "padding: 6px 14px; font-size: 13px;"): Set Icon
        ==
        ;*  ?~  icon-url  ~
            :~  ;form(method "post", action "/mail/remove-icon", style "display: inline;")
                  ;button(type "submit", class "btn btn-secondary", style "padding: 6px 14px; font-size: 13px;"): Reset
                ==
            ==
      ==
    ==
    ;div(style "margin-top: 30px; padding-top: 20px; border-top: 1px solid var(--border);")
      ;h3(style "margin-bottom: 10px;"): Forwarding
      ;p(class "help", style "margin-bottom: 10px;"): Forward incoming mail to these addresses. Leave conditions empty to forward all mail.
      ;*  ?:  =(~ fwds)
            :~  ;p(style "color: var(--muted);"): No forwarding rules configured.
            ==
          %+  turn  fwds
          |=  r=fwd-rule
          =/  addr=tape  (format-contact:ui to.r)
          =/  lab-text=tape  ?:(=('' conditions.r) "all mail" (trip conditions.r))
          ;div(style "display: flex; align-items: center; margin-bottom: 8px; gap: 10px; padding: 10px 12px; background: var(--info-bg); border-radius: 6px; flex-wrap: wrap;")
            ;*  ?:  ?=([%urbit *] to.r)
                  :~  ;span(class "sigil-wrap", data-patp (scow %p p.to.r));
                  ==
                :~  ;span(class "ext-icon"): @
                ==
            ;div(style "flex: 1; min-width: 0;")
              ;div
                ;span(style "font-size: 14px; font-weight: 600;"): {addr}
              ==
              ;div
                ;span(style "font-size: 11px; color: var(--muted);"): {lab-text}
              ==
            ==
            ;form(method "post", action "/mail/toggle-fwd-rule", style "display:inline")
              ;input(type "hidden", name "key", value (scow %uv (sham [to.r conditions.r])));
              ;button(type "submit", class ?:(enabled.r "btn btn-approve" "btn btn-secondary"), style "padding: 4px 10px; font-size: 12px;"): {?:(enabled.r "ON" "OFF")}
            ==
            ;form(method "post", action "/mail/remove-fwd-rule", style "display:inline")
              ;input(type "hidden", name "key", value (scow %uv (sham [to.r conditions.r])));
              ;button(type "submit", class "btn btn-danger", style "padding: 4px 10px; font-size: 12px;"): Remove
            ==
          ==
      ;form(method "post", action "/mail/add-fwd-rule", style "margin-top: 10px; display: flex; gap: 8px; align-items: center; flex-wrap: wrap;")
        ;input(type "text", name "to", placeholder "~sampel-palnet or user@email.com", required "", pattern "~[a-z-]+|[^@ ]+@[^@ ]+\\.[^@ ]+", title "Enter a valid ~ship or email address", style "width: 250px; margin: 0;");
        ;input(type "text", name "conditions", placeholder "label, @alias, -exclude", style "width: 200px; margin: 0;");
        ;button(type "submit", class "btn", style "padding: 6px 14px;"): Add Rule
      ==
      ;p(style "font-size: 11px; color: var(--muted); margin-top: 4px;"): Conditions: label name, @alias, prefix with - to exclude. Comma-separated. Empty = forward all.
    ==
    ;div(style "margin-top: 24px; padding-top: 16px; border-top: 1px solid var(--border);")
      ;h3(style "margin-bottom: 8px;"): Run Your Own Gateway
      ;p(style "font-size: 13px; color: var(--muted); margin-bottom: 10px;"): Turn this ship into a mail relay for other Urbit ships. Requires a domain and a Python bridge.
      ;+  ?:  is-gw
            ;p(style "font-size: 13px; color: var(--color-success); font-weight: 600;"): Gateway mode is active. Manage it from the Gateway tab in navigation.
          ;a(href "/mail/gateway", class "btn btn-secondary", style "padding: 6px 16px; font-size: 13px;"): Set Up Gateway
    ==
    ==
    ;div(class "settings-tab-panel", data-tab "aliases", style "display: none;")
      ;h3(style "margin-bottom: 10px;"): Email Aliases
      ;p(class "help", style "margin-bottom: 10px;"): Custom email addresses like john@domain instead of ~ship-name@domain. Allowed: a-z, 0-9, hyphen, underscore. No dots.
      ;*  =/  flat=(list [gw=@p a=@t active=? dom=tape])
            %-  zing
            %+  turn  ~(tap by aliases)
            |=  [gw=@p als=(list [@t ?])]
            =/  d=(unit @t)  (~(get by doms) gw)
            =/  dt=tape  ?~(d "" (trip u.d))
            ^-  (list [gw=@p a=@t active=? dom=tape])
            (turn als |=([a=@t ac=?] [gw a ac dt]))
          ?~  flat
            :~  ;p(style "color: var(--muted);"): No aliases configured.
            ==
          %+  turn  flat
          |=  [gw=@p a=@t active=? dom=tape]
          =/  addr=tape  ?:(=(~ dom) (trip a) (weld (trip a) (weld "@" dom)))
          =/  row-style=tape  ?:(active "display: flex; align-items: center; margin-bottom: 8px; gap: 10px; padding: 10px 12px; background: var(--info-bg); border-radius: 6px;" "display: flex; align-items: center; margin-bottom: 8px; gap: 10px; padding: 10px 12px; background: var(--info-bg); border-radius: 6px; opacity: 0.5;")
          ;div(style row-style)
            ;div(style "flex: 1;")
              ;div
                ;span(style "font-size: 15px; font-weight: 600;"): {addr}
                ;*  ?.  active
                      :~  ;span(style "font-size: 11px; color: var(--color-error); margin-left: 8px;"): (disabled)
                      ==
                    ~
              ==
              ;div
                ;span(style "font-size: 11px; color: var(--muted);"): via {(scow %p gw)}
              ==
            ==
            ;*  ?:  active
                  :~  ;form(method "post", action "/mail/disable-alias", style "display:inline")
                        ;input(type "hidden", name "alias", value (trip a));
                        ;input(type "hidden", name "gateway", value (scow %p gw));
                        ;button(type "submit", class "btn btn-secondary", style "padding: 4px 10px; font-size: 12px;"): Disable
                      ==
                  ==
                :~  ;form(method "post", action "/mail/enable-alias", style "display:inline")
                      ;input(type "hidden", name "alias", value (trip a));
                      ;input(type "hidden", name "gateway", value (scow %p gw));
                      ;button(type "submit", class "btn btn-approve", style "padding: 4px 10px; font-size: 12px;"): Enable
                    ==
                ==
          ==
      ;*  =/  err-msgs=(map @t tape)
            %-  my
            :~  ['alias-invalid' "Invalid alias: only a-z, 0-9, hyphen, underscore. Cannot match a ship name."]
                ['alias-requested' "Alias requested! Reload the page in a few seconds to see it."]
                ['invite-redeemed' "Invite code submitted! Reload the page in a few seconds."]
                ['payment-pending' "Payment request sent! See payment instructions below."]
                ['payment-verifying' "Payment submitted for verification. Reload in a few seconds."]
            ==
          =/  err-text=(unit tape)
            ?~  msg  ~
            (~(get by err-msgs) u.msg)
          ?~  err-text  ~
          =/  is-err=?  ?=([~ %'alias-invalid'] msg)
          :~  ;p(style "margin-bottom: 8px; padding: 8px 12px; border-radius: 4px; font-size: 13px; background: {?:(is-err "var(--color-error)" "var(--color-success)")}; color: #fff;"): {u.err-text}
          ==
      ::  pending payment link
      ;*  ?~  pp  ~
          :~  ;div(style "margin-bottom: 16px; padding: 12px; background: var(--info-bg); border-radius: 6px;")
                ;p(style "margin: 0 0 8px 0; font-weight: 600;"): Payment pending for alias "{(trip alias.u.pp)}"
                ;a(href "/mail/buy-alias", class "btn", style "padding: 6px 14px;"): Complete Payment
              ==
          ==
      ::  unified alias form — compute default config from gateways
      ;+  =/  def-cfg=[on=? min=@ud free-min=@ud base=@ud pay-on=?]
            =/  cfgs  ~(val by gw-als)
            =/  active  (skim cfgs |=(c=[on=? min=@ud free-min=@ud base=@ud pay-on=?] on.c))
            ?~  active  [%.n 5 10 5.000.000.000.000.000 %.n]
            i.active
          ;div(style "margin-top: 16px; padding: 16px; background: var(--card); border: 1px solid var(--border); border-radius: 8px;")
        ;h4(style "margin: 0 0 8px 0;"): Get a New Alias
        ;p(style "font-size: 12px; color: var(--muted); margin-bottom: 4px;"): a-z, 0-9, hyphen, underscore. No dots or spaces.
        ;p(id "alias-rules", style "font-size: 12px; color: var(--muted); margin-bottom: 12px;"): {?:(pay-on.def-cfg "{(a-co:co free-min.def-cfg)}+ chars = free. {(a-co:co min.def-cfg)} to {(a-co:co (dec free-min.def-cfg))} chars = paid (ETH)." "{(a-co:co free-min.def-cfg)}+ chars only. Paid aliases not available on this gateway.")}
        ;form(id "alias-form", method "post", action "/mail/request-alias", data-free-min-len (a-co:co free-min.def-cfg), data-min-len (a-co:co min.def-cfg), data-base-price (a-co:co base.def-cfg), style "display: flex; gap: 8px; align-items: center; flex-wrap: wrap;")
          ;input(type "text", name "alias", placeholder "my-alias", required "", pattern "[a-z0-9][a-z0-9_-]*", title "a-z, 0-9, hyphen, underscore. No dots.", style "width: 200px; margin: 0;", autocomplete "off");
          ;select(id "alias-gateway", name "gateway", style "margin: 0; padding: 6px 8px;")
            ;*  %+  turn
                %+  skim  ~(tap in gws)
                |=  g=@p
                ?&  ?=(^ (~(get by doms) g))
                    ?~(c=(~(get by gw-als) g) %.y on.u.c)
                ==
                |=  g=@p
                =/  d=@t  (need (~(get by doms) g))
                =/  cfg=[on=? min=@ud free-min=@ud base=@ud pay-on=?]
                  (fall (~(get by gw-als) g) [%.y 5 10 5.000.000.000.000.000 %.n])
                ;option(value (scow %p g), data-min (a-co:co min.cfg), data-free-min (a-co:co free-min.cfg), data-base (a-co:co base.cfg), data-pay ?:(pay-on.cfg "1" "0")): {(trip d)}
          ==
          ;button(id "alias-submit", type "submit", class "btn", style "padding: 6px 16px;"): Request
          ;span(id "alias-price", style "font-size: 13px; font-weight: 600;");
        ==
      ==
      ::  invite code (collapsible)
      ;details(style "margin-top: 12px;")
        ;summary(style "cursor: pointer; font-size: 13px; color: var(--link);"): Have an invite code?
        ;form(method "post", action "/mail/redeem-invite", style "display: flex; gap: 8px; align-items: center; flex-wrap: wrap; margin-top: 8px;")
          ;input(type "text", name "code", placeholder "alias@~gateway:signature", required "", style "width: 300px; margin: 0;");
          ;button(type "submit", class "btn", style "padding: 6px 14px;"): Redeem
        ==
        ;p(style "font-size: 11px; color: var(--muted); margin-top: 4px;"): Gateway is detected from the invite code automatically.
      ==
    ==
    ;div(class "settings-tab-panel", data-tab "discovery", style "display: none;")
      ;h3(style "margin-bottom: 10px;"): Public Gateways
      ;p(class "help", style "margin-bottom: 10px;"): Gateways registered in the public registry. Click Add to add one to your gateway list.
      ;div(style "margin-bottom: 12px; display: flex; gap: 8px; align-items: center; flex-wrap: wrap;")
        ;span(style "font-size: 13px; color: var(--th-text);"): Registry:
        ;*  ?~  reg  ~
            :~  ;span(class "sigil-wrap", data-patp (scow %p u.reg));
            ==
        ;span(style "font-weight: 600;"): {?~(reg "(none)" (scow %p u.reg))}
        ;form(method "post", action "/mail/set-registry", style "display: flex; gap: 8px; align-items: center;")
          ;input(type "text", name "ship", placeholder "~sampel-palnet", style "width: 220px; margin: 0; font-size: 13px; padding: 4px 8px;");
          ;button(type "submit", class "btn", style "padding: 4px 12px; font-size: 12px;"): Change
        ==
      ==
      ;*  ?:  =(~ reg-gws)
            :~  ;p(style "color: var(--muted);"): No public gateways available. The registry may be offline or empty.
            ==
          %+  turn  ~(tap by reg-gws)
          |=  [ship=@p ent=reg-entry]
          =/  already=?  (~(has in gws) ship)
          ;div(style "display: flex; align-items: center; margin-bottom: 8px; gap: 10px; padding: 10px 12px; background: var(--info-bg); border-radius: 6px; flex-wrap: wrap;")
            ;span(class "sigil-wrap", data-patp (scow %p ship));
            ;div(style "flex: 1; min-width: 0;")
              ;*  ?:  =('' domain.ent)
                    :~  ;span(style "font-size: 13px;"): {(scow %p ship)}
                    ==
                  :~  ;div
                        ;span(style "font-size: 15px; font-weight: 600;"): {(trip domain.ent)}
                      ==
                      ;div
                        ;span(style "font-size: 11px; color: var(--muted);"): {(scow %p ship)}
                      ==
                  ==
            ==
            ;*  ?:  auto-approve.ent
                  :~  ;span(style "font-size: 11px; background: var(--color-success); color: #fff; padding: 2px 8px; border-radius: 10px;"): auto-approve
                  ==
                ~
            ;span(style "font-size: 11px; color: var(--muted);"): {(a-co:co user-count.ent)} users
            ;*  ?:  already
                  :~  ;span(style "font-size: 11px; color: var(--muted); font-style: italic;"): (already added)
                  ==
                :~  ;form(method "post", action "/mail/add-gateway", style "display:inline")
                      ;input(type "hidden", name "ship", value (scow %p ship));
                      ;button(type "submit", class "btn btn-approve", style "padding: 4px 12px; font-size: 12px;"): + Add
                    ==
                ==
          ==
    ==
  ==
::  render-donate: donation/support page
::
++  render-donate
  ^-  manx
  ;div(class "compose-form")
    ;h2: Support Urbit Mail
    ;p(style "line-height: 1.7; margin-bottom: 12px;"): Urbit Mail is open-source, self-hostable, no subscriptions, no ads, no tracking. You own your mail, your server, your data. That's the point.
    ;p(style "line-height: 1.7; margin-bottom: 12px;"): Building this takes real work. If you use it and it saves you from another Gmail/Protonmail dependency — consider throwing something in. One-time, whatever feels right. No recurring nonsense.
    ;p(style "line-height: 1.7; margin-bottom: 12px;"): Gateway operators earn from paid short aliases to cover their server costs. Your support here goes directly to development — new features, fixes, and keeping the project alive.
    ;div(style "display: flex; gap: 20px; flex-wrap: wrap; margin-top: 24px;")
      ;div(style "flex: 1; min-width: 200px; background: var(--input-bg); border: 1px solid var(--border); border-radius: 10px; padding: 20px; text-align: center;")
        ;h3(style "margin: 0 0 12px 0; font-size: 15px;"): Bitcoin
        ;img(src "https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=bitcoin%3Abc1qvasxg5ywln5pc33a00x5p2cneeck3l2dlmhuvy", alt "BTC QR", style "border-radius: 6px; margin-bottom: 12px;");
        ;div(style "font-size: 11px; word-break: break-all; color: var(--muted); margin-bottom: 8px;"): bc1qvasxg5ywln5pc33a00x5p2cneeck3l2dlmhuvy
        ;button(class "btn btn-secondary copy-btn", data-copy "bc1qvasxg5ywln5pc33a00x5p2cneeck3l2dlmhuvy", style "font-size: 12px; padding: 4px 14px;"): Copy Address
      ==
      ;div(style "flex: 1; min-width: 200px; background: var(--input-bg); border: 1px solid var(--border); border-radius: 10px; padding: 20px; text-align: center;")
        ;h3(style "margin: 0 0 12px 0; font-size: 15px;"): Ethereum
        ;img(src "https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=ethereum%3A0x923583C8C50244605452504Ef51dc5666ad97806", alt "ETH QR", style "border-radius: 6px; margin-bottom: 12px;");
        ;div(style "font-size: 11px; word-break: break-all; color: var(--muted); margin-bottom: 8px;"): 0x923583C8C50244605452504Ef51dc5666ad97806
        ;button(class "btn btn-secondary copy-btn", data-copy "0x923583C8C50244605452504Ef51dc5666ad97806", style "font-size: 12px; padding: 4px 14px;"): Copy Address
      ==
      ;div(style "flex: 1; min-width: 200px; background: var(--input-bg); border: 1px solid var(--border); border-radius: 10px; padding: 20px; text-align: center;")
        ;h3(style "margin: 0 0 12px 0; font-size: 15px;"): Solana
        ;img(src "https://api.qrserver.com/v1/create-qr-code/?size=160x160&data=solana%3A9yn5Nw73WN4fuAcjPRjHUL1EqzMRMpyERfnkuRykMndL", alt "SOL QR", style "border-radius: 6px; margin-bottom: 12px;");
        ;div(style "font-size: 11px; word-break: break-all; color: var(--muted); margin-bottom: 8px;"): 9yn5Nw73WN4fuAcjPRjHUL1EqzMRMpyERfnkuRykMndL
        ;button(class "btn btn-secondary copy-btn", data-copy "9yn5Nw73WN4fuAcjPRjHUL1EqzMRMpyERfnkuRykMndL", style "font-size: 12px; padding: 4px 14px;"): Copy Address
      ==
    ==
    ;p(style "margin-top: 30px; color: var(--muted); font-size: 13px; line-height: 1.6;"): $5, $20, 0.01 ETH, 0.1 SOL — whatever works. It all counts.
  ==
::  render-backup: backup and restore page
::
++  render-backup
  |=  [inbox-count=@ud sent-count=@ud trash-count=@ud auto-backup-time=@da backup-interval=@dr]
  ^-  manx
  ;div(class "compose-form")
    ;h2: Backup & Restore
    ;p(style "margin-bottom: 20px; color: var(--muted);"): Your data is automatically backed up every hour. You can also download or restore manually.
    ;div(style "background: var(--info-bg); padding: 16px; border-radius: 8px; margin-bottom: 24px;")
      ;h3(style "margin-bottom: 8px;"): Current Data
      ;p(style "font-size: 14px;"): Inbox: {(a-co:co inbox-count)} messages, Sent: {(a-co:co sent-count)} messages, Trash: {(a-co:co trash-count)} messages
      ;p(style "font-size: 13px; color: var(--muted); margin-top: 4px;"): Backup includes all messages, gateway settings, forwarding rules, and labels.
    ==
    ;div(style "background: var(--card); border: 1px solid var(--border); padding: 16px; border-radius: 8px; margin-bottom: 24px;")
      ;h3(style "margin-bottom: 8px;"): Auto-Backup
      ;p(style "font-size: 14px; margin-bottom: 8px;"): Last backup: {?:(=(auto-backup-time *@da) "never" (scag 19 (scow %da auto-backup-time)))}
      ;p(style "font-size: 13px; color: var(--muted); margin-bottom: 12px;"): Automatic backups run every hour and are stored in the recovery agent.
      ;div(style "display: flex; gap: 8px; flex-wrap: wrap; align-items: center;")
        ;form(method "post", action "/mail/create-backup")
          ;button(type "submit", class "btn", style "padding: 6px 16px;"): Create Backup Now
        ==
        ;form(method "post", action "/mail/restore-from-agent")
          ;button(type "submit", class "btn btn-secondary", style "padding: 6px 16px;", onclick "return confirm('Restore from auto-backup? Current data will be replaced.')"): Restore from Auto-Backup
        ==
      ==
      ;+  =/  cur-min=@ud  (max 1 (div backup-interval ~m1))
          ;form(method "post", action "/mail/set-backup-interval", style "margin-top: 12px; display: flex; gap: 8px; align-items: center; flex-wrap: wrap;")
            ;label(style "font-size: 13px; color: var(--muted);"): Interval:
            ;input(type "number", name "minutes", min "5", max "1440", value (a-co:co cur-min), style "width: 70px; padding: 4px 8px; margin: 0;");
            ;span(style "font-size: 13px; color: var(--muted);"): min
            ;button(type "submit", class "btn btn-secondary", style "padding: 4px 12px; font-size: 13px;"): Save
          ==
    ==
    ;div(style "margin-bottom: 32px;")
      ;h3(style "margin-bottom: 12px;"): Download Backup
      ;form(method "post", action "/mail/backup-download")
        ;button(type "submit", class "btn"): Download as JSON file
      ==
    ==
    ;div
      ;h3(style "margin-bottom: 12px;"): Restore from File
      ;p(style "color: var(--muted); font-size: 13px; margin-bottom: 12px;"): Upload a previously downloaded JSON backup file.
      ;form(method "post", action "/mail/restore", id "restore-form", enctype "text/plain")
        ;input(type "file", id "backup-file", accept ".json", style "margin-bottom: 12px; font-size: 14px;");
        ;button(type "submit", class "btn btn-danger"): Restore from file
      ==
    ==
  ==
::  render-help: help and documentation page
::
++  render-help
  ^-  manx
  ;div(class "compose-form help-page")
    ;h2: Help
    ;h3: Getting Started
    ;p: Urbit Mail lets you send and receive email through your sovereign Urbit ship.
    ;p: Your email address follows the format:
    ;p
      ;code: shipname@gateway-domain
    ==
    ;p: To find your current address, visit the Settings page — all your active addresses are listed there.
    ;h3: Setting Up a Gateway
    ;ol
      ;li: Go to Settings
      ;li: Enter a gateway ship address (e.g. ~mister-poster-midnev)
      ;li: Click Add Gateway
      ;li: Wait for approval (some gateways auto-approve)
      ;li: Your email address appears in Settings once the gateway has a domain configured
    ==
    ;h3: Sending and Receiving
    ;p: To send to an Urbit ship, enter the ship name in the To field (e.g. ~sampel-palnet). The message is delivered directly via Ames — no gateway needed.
    ;p: To send to an external email address, enter email@domain in the To field. The message is routed through your configured gateway.
    ;p(style "color: var(--muted); font-size: 13px;"): Note: default gateways use a free email API tier (100 messages/day, 3,000/month shared across all users). Outgoing delivery may be delayed during peak usage. If demand grows, these limits will be raised.
    ;p: Incoming email arrives automatically when your gateway relays it to your ship.
    ;h3: Comets
    ;p: Comets (128-bit ship names like ~doznec-rallod-...) can receive mail but cannot send messages. This is a deliberate restriction — comets are anonymous and free to create, which makes them unsuitable as verified senders.
    ;p: To send mail, use a planet, star, or galaxy.
    ;h3: Delivery Status
    ;p: After sending, messages show a delivery status:
    ;ul
      ;li
        ;strong: sending
        ;span:  — message dispatched, waiting for delivery confirmation
      ==
      ;li
        ;strong: sent
        ;span:  — message delivered to the recipient's ship
      ==
      ;li
        ;strong: failed
        ;span:  — delivery timed out (5 min) or was rejected. If the recipient comes online later, it may still be delivered and the status will update automatically.
      ==
    ==
    ;h3: Dojo Commands
    ;p: You can also manage mail from the command line (dojo):
    ;p
      ;code: +mail!mail/inbox
    ==
    ;p
      ;code: +mail!mail/sent
    ==
    ;p
      ;code: +mail!mail/unread
    ==
    ;p
      ;code: +mail!mail/labels
    ==
    ;p: To send a message from dojo:
    ;p
      ;code: :mail-client &mail-action [%send [%urbit ~sampel-palnet] ~ ~ 'Subject' 'Body text']
    ==
    ;p: To send to an external email:
    ;p
      ;code: :mail-client &mail-action [%send [%ext 'user@example.com'] ~ ~ 'Subject' 'Body text']
    ==
    ;h3: Labels
    ;p: Labels help you organize your mail. Add them from the message view or compose form. Click a label name in the sidebar to filter your inbox. Labels are colored automatically.
    ;p: You can also embed labels directly into your email address using dot notation:
    ;p
      ;code: shipname.label@gateway-domain
    ==
    ;p: For example, use a unique address for each service you sign up for. Mail sent to that address will be automatically tagged with the label. Multiple labels work too:
    ;p
      ;code: shipname.shopping.receipts@gateway-domain
    ==
    ;h3: PWA — Add to Home Screen
    ;p: Urbit Mail can be installed as a progressive web app for a full-screen experience.
    ;p
      ;strong: iPhone:
      ; Safari, tap Share, then Add to Home Screen.
    ==
    ;p
      ;strong: Android:
      ; Chrome, tap the menu (three dots), then Add to Home Screen.
    ==
    ;h3: Tips
    ;ul
      ;li: Click your ship name in the navbar to copy it to clipboard
      ;li: Click any email address in a message to copy it
      ;li: The compose form auto-saves drafts as you type
      ;li: Use the sun/moon icon in the navbar to toggle dark and light theme
    ==
    ;h3: Gateway DNS Verification
    ;p: To register a gateway in the public registry, add a DNS TXT record to prove domain ownership:
    ;p
      ;code: _urbit-gw.yourdomain.com  TXT  "~your-ship-name"
    ==
    ;p: The registry will verify this record via DNS-over-HTTPS before accepting registration. Gateways without valid TXT records will be rejected.
    ;h3: Running a Gateway Registry
    ;p: Any ship can run a public gateway registry. Install %mail, then enable the registry agent:
    ;p
      ;code: :mail-registry &mail-registry-action [%set-enabled %.y]
    ==
    ;p: Gateways auto-register when enabled and auto-verify via DNS. Other ships can subscribe to your registry by changing their registry setting in the client.
    ;h3: Credits
    ;p: Push notifications powered by
    ;p
      ;a(href "https://github.com/will-hanlen/urbit-web-push", target "_blank", rel "noopener"): urbit-web-push
      ;span:  by ~migrev-dolseg — W3C Web Push protocol implemented entirely in Hoon.
    ==
  ==
--
