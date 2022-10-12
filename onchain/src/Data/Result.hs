module Data.Result (Result(..), err, foldResult) where

import PlutusTx.Prelude

data Result a
  = Ok a
  | Err BuiltinString

instance Functor Result where
  {-# INLINEABLE fmap #-}
  fmap f (Ok x) = Ok (f x)
  fmap _ (Err e) = Err e

instance Applicative Result where
  {-# INLINEABLE pure #-}
  pure = Ok
  {-# INLINEABLE (<*>) #-}
  Ok f <*> Ok x = Ok (f x)
  Err e <*> Ok _ = Err e
  Ok _ <*> Err e = Err e
  Err e1 <*> Err e2 = Err (e1 <> "; " <> e2)

{-# INLINEABLE err #-}
err :: BuiltinString -> Result a
err = Err

{-# INLINEABLE foldResult #-}
foldResult :: (BuiltinString -> b) -> (a -> b) -> Result a -> b
foldResult _ onOk (Ok x) = onOk x
foldResult onErr _ (Err e) = onErr e
