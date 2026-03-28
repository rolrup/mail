/-  *push
|%
+$  push-state
  $:  config=(unit push-config)
      subs=(map @p (map @ta subscription))
  ==
+$  versioned-push-state
  $%  [%0 push-state]
  ==
--
