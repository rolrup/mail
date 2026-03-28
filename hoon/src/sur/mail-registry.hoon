|%
+$  registry-entry
  $:  domain=@t
      auto-approve=?
      user-count=@ud
      last-seen=@da
  ==
+$  pending-reg
  $:  ship=@p
      domain=@t
      auto-approve=?
      user-count=@ud
  ==
+$  registry-action
  $%  [%register domain=@t auto-approve=? user-count=@ud]
      [%unregister ~]
      [%set-enabled enabled=?]
  ==
+$  registry-state-0
  $:  enabled=?
      data=(map @p registry-entry)
  ==
+$  registry-state-1
  $:  enabled=?
      data=(map @p registry-entry)
      pending=(map @t pending-reg)
  ==
+$  versioned-registry-state
  $%  [%0 registry-state-0]
      [%1 registry-state-1]
  ==
--
