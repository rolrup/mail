::  %mail-recovery: centralized backup agent for Urbit Mail
::
::  Stores JSON backup of all mail agents' state.
::  State type [backup=@t updated=@da] NEVER changes —
::  immune to migration failures.
::
/-  *mail-recovery
/+  default-agent, dbug
|%
+$  card  card:agent:gall
--
%-  agent:dbug
=|  rec-state
=*  state  -
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %.n) bowl)
::
++  on-init
  ^-  (quip card _this)
  ~&  >  '%mail-recovery installed'
  `this
::
++  on-save
  ^-  vase
  !>(state)
::
++  on-load
  |=  old-vase=vase
  ^-  (quip card _this)
  =/  old  (mole |.(!<(rec-state old-vase)))
  ?~  old
    ~&  >  '%mail-recovery: fresh state'
    `this
  `this(state u.old)
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?.  =(our.bowl src.bowl)  `this
  =/  act=recovery-action
    ?:  =(%mail-recovery-action mark)
      !<(recovery-action vase)
    ;;(recovery-action q.vase)
  ?-  -.act
      %save-backup
    ::  silent save
    `this(backup backup.act, updated now.bowl)
      %clear
    ~&  >  '%mail-recovery: backup cleared'
    `this(backup '', updated *@da)
  ==
::
++  on-watch  |=(path `this)
++  on-leave  on-leave:def
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  ?+  path  ~
      [%x %backup-json ~]
    ``[%noun !>(backup)]
      [%x %updated ~]
    ``[%noun !>(updated)]
      [%x %backup ~]
    ``[%noun !>(state)]
  ==
::
++  on-agent  |=([wire sign:agent:gall] `this)
++  on-arvo  |=([wire sign-arvo] `this)
++  on-fail  |=([term tang] `this)
--
