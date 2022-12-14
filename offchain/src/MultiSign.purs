module MultiSign where

import Contract.Prelude

import Contract.Address (PaymentPubKeyHash)
import Contract.Log (logInfo')
import Contract.Monad (Contract, liftContractM, liftedE, liftedM)
import Contract.PlutusData
  ( Redeemer(Redeemer)
  , toData
  , unitDatum
  )
import Contract.ScriptLookups (ScriptLookups, mkUnbalancedTx)
import Contract.ScriptLookups (validator, unspentOutputs) as Lookups
import Contract.Scripts
  ( Validator(..)
  , applyArgs
  , scriptHashAddress
  , validatorHash
  )
import Contract.TextEnvelope
  ( TextEnvelopeType(PlutusScriptV2)
  , textEnvelopeBytes
  )
import Contract.Transaction (awaitTxConfirmed, balanceAndSignTxE, submit)
import Contract.TxConstraints (TxConstraints)
import Contract.TxConstraints (DatumPresence(DatumInline), mustPayToScript, mustSpendScriptOutput) as Constraints
import Contract.Utxos (utxosAt)
import Contract.Value (Value)
import Data.Map (findMin) as Map
import Types.Scripts (plutusV2Script)

import ScriptsFFI (rawMultiSign)

type MultiSignParams = Array PaymentPubKeyHash

getValidator :: MultiSignParams -> Contract () Validator
getValidator params = do
  val <- plutusV2Script >>> Validator <$> textEnvelopeBytes
    rawMultiSign
    PlutusScriptV2
  liftedE (applyArgs val [ toData params ])

init :: Value -> MultiSignParams -> Contract () Unit
init value signers = do
  validator <- getValidator signers
  let
    valHash = validatorHash validator

    lookups :: ScriptLookups Void
    lookups = Lookups.validator validator

    constraints = Constraints.mustPayToScript valHash unitDatum Constraints.DatumInline value

  ubTx <- liftedE $ mkUnbalancedTx lookups constraints
  bsTx <- liftedE $ balanceAndSignTxE ubTx
  txId <- submit bsTx
  logInfo' $ "Tx ID: " <> show txId
  awaitTxConfirmed txId

get :: MultiSignParams -> Contract () { lookups :: ScriptLookups Void, constraints :: TxConstraints Void Void }
get signers = do
  validator <- getValidator signers
  let
    valHash = validatorHash validator
    valAddr = scriptHashAddress valHash
  valUtxos <- liftedM "Failed to get utxosAt MS" $ utxosAt valAddr
  { key: msUtxo, value: msUtxoResolved } <- liftContractM "utxosAt MS are empty" $ Map.findMin valUtxos
  let
    lookups = Lookups.validator validator
      <> Lookups.unspentOutputs valUtxos

    redeemer = Redeemer $ toData signers
    value = msUtxoResolved # unwrap >>> _.output >>> unwrap >>> _.amount
    constraints = Constraints.mustSpendScriptOutput msUtxo redeemer
      <> Constraints.mustPayToScript valHash unitDatum Constraints.DatumInline value

  pure { lookups, constraints }
