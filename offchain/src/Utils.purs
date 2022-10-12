module Utils where

import Contract.Prelude

import Contract.Monad (Contract, liftedE, liftedM)
import Contract.PlutusData (class IsData)
import Contract.Log (logInfo')
import Contract.ScriptLookups (ScriptLookups, mkUnbalancedTx)
import Contract.Transaction (BalancedSignedTransaction, Transaction, TransactionHash, balanceAndSignTxE, signTransaction, submit)
import Contract.Wallet (KeyWallet, withKeyWallet)
import Types.TxConstraints (TxConstraints)
import Types.TypedValidator (class ValidatorTypes)

signWith
  :: forall extra t
   . Foldable t
  => t KeyWallet
  -> Transaction
  -> Contract extra Transaction
signWith = flip $
  foldM \tx wallet ->
    withKeyWallet wallet do
      liftedM "Unable to sign transaction" do
        signTransaction tx

submitLogging :: forall extra. BalancedSignedTransaction -> Contract extra TransactionHash
submitLogging bsTx = do
  txId <- submit bsTx
  logInfo' $ "Tx ID: " <> show txId
  pure txId

buildBalanceSignAndSubmitTx
  :: forall extra validator datum redeemer
   . ValidatorTypes validator datum redeemer
  => IsData datum
  => IsData redeemer
  => ScriptLookups validator
  -> TxConstraints redeemer datum
  -> Contract extra TransactionHash
buildBalanceSignAndSubmitTx lookups constraints = do
  ubTx <- liftedE $ mkUnbalancedTx lookups constraints
  submitLogging =<< liftedE (balanceAndSignTxE ubTx)

-- | Applies function to Newtype's underlying value
applyUnwrapping :: forall t a b. Newtype t a => (a -> b) -> t -> b
applyUnwrapping = (_ <<< unwrap)

infixr 7 applyUnwrapping as #>

-- | Flipped `applyUnwrapping`. Use to access fields in Haskell-like records:
-- | ```
-- | newtype A = A { field :: String }
-- |
-- | a :: A
-- |
-- | s :: String
-- | s = a <# _.field
-- | ```
applyUnwrappingReverse :: forall t a b. Newtype t a => t -> (a -> b) -> b
applyUnwrappingReverse = flip applyUnwrapping

infixl 7 applyUnwrappingReverse as <#
