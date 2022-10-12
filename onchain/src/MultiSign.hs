{-# LANGUAGE TemplateHaskell #-}

module MultiSign (script) where

import PlutusTx.Prelude

import Ledger (PaymentPubKeyHash (unPaymentPubKeyHash))
import Plutus.V2.Ledger.Api (Script, ScriptContext (scriptContextTxInfo), fromCompiledCode)
import Plutus.V2.Ledger.Contexts (txSignedBy)
import PlutusTx (fromBuiltinData)
import PlutusTx qualified (compile)
import PlutusTx.Builtins (divideInteger)

import Data.Result (err, foldResult)

type MultiSignParams = [PaymentPubKeyHash]

mkValidator :: MultiSignParams -> ScriptContext -> Bool
mkValidator signers ctx =
  traceIfFalse "Not enough signatures" (length signersPresent >= minSigners)
  where
    signersPresent, signersUnique :: [PaymentPubKeyHash]
    signersPresent = filter (txSignedBy (scriptContextTxInfo ctx) . unPaymentPubKeyHash) signersUnique
    signersUnique = nub signers

    minSigners :: Integer
    minSigners = max 1 $ length signersUnique `divideInteger` 2

{-# INLINEABLE mkValidator' #-}
mkValidator' :: BuiltinData -> BuiltinData -> BuiltinData -> BuiltinData -> ()
mkValidator' params _datum _redeemer context =
  foldResult traceError check $
    mkValidator
      <$> maybe (err "Failed to parse params") pure (fromBuiltinData params)
      <*> maybe (err "Failed to parse context") pure (fromBuiltinData context)

script :: Script
script = fromCompiledCode $$(PlutusTx.compile [||mkValidator'||])
