{-# LANGUAGE TemplateHaskell #-}

module MultiSign (script) where

import PlutusTx.Prelude

import Ledger (PaymentPubKeyHash (unPaymentPubKeyHash))
import Plutus.V2.Ledger.Api (Script, ScriptContext (scriptContextTxInfo), getPubKeyHash, fromCompiledCode)
import Plutus.V2.Ledger.Contexts (txSignedBy)
import PlutusTx (fromBuiltinData)
import PlutusTx qualified (compile)

import Data.Result (err, foldResult)
import PlutusTx.Show

type MultiSignParams = [PaymentPubKeyHash]

{-# INLINEABLE mkValidator #-}
mkValidator :: MultiSignParams -> ScriptContext -> Bool
mkValidator signers ctx =
  traceIfFalse errMessage (length signersPresent >= minSigners)
  where
    signersPresent, signersUnique :: [PaymentPubKeyHash]
    signersPresent = filter (txSignedBy (scriptContextTxInfo ctx) . unPaymentPubKeyHash) signersUnique
    signersUnique = nub signers

    minSigners :: Integer
    minSigners = max 1 $ length signersUnique `divide` 2

    errMessage = mconcat
      [ "Not enough signatures ("
      , show (length signersPresent)
      , "/"
      , show minSigners
      , "): ["
      , intercalate "," $ show . getPubKeyHash . unPaymentPubKeyHash <$> signersPresent
      , "]"
      ]

intercalate :: Monoid a => a -> [a] -> a
intercalate sep = go mempty where
  go acc [] = acc
  go acc [x] = acc <> x
  go acc (x : xs) = go (acc <> x <> sep) xs

{-# INLINEABLE mkValidator' #-}
mkValidator' :: BuiltinData -> BuiltinData -> BuiltinData -> BuiltinData -> ()
mkValidator' params _datum _redeemer context =
  foldResult traceError check $
    mkValidator
      <$> maybe (err "Failed to parse params") pure (fromBuiltinData params)
      <*> maybe (err "Failed to parse context") pure (fromBuiltinData context)

script :: Script
script = fromCompiledCode $$(PlutusTx.compile [||mkValidator'||])
