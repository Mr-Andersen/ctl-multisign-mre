module Test where

import Contract.Prelude

import Contract.Address (PaymentPubKeyHash, ownPaymentPubKeyHash)
import Contract.Log (logInfo')
import Contract.Monad (Contract, launchAff_, liftContractM, liftedM, liftedE)
import Contract.ScriptLookups (mkUnbalancedTx) as Lookups
import Contract.Transaction (Transaction, awaitTxConfirmed, balanceTx, signTransaction, submit)
import Contract.Value (lovelaceValueOf)
import Contract.Wallet (KeyWallet, withKeyWallet)
import Data.BigInt (fromInt) as BigInt
import Data.UInt (fromInt) as UInt
import Plutip.Server (runPlutipContract)
import Plutip.Types (PlutipConfig)
import Record (modify) as Record
import Type.Proxy (Proxy(Proxy))

import MultiSign (init, get) as MultiSign

ownPaymentPubKeyHash' :: forall extra. Contract extra PaymentPubKeyHash
ownPaymentPubKeyHash' = liftedM "cannot get own pubkey" ownPaymentPubKeyHash

main :: Effect Unit
main = launchAff_ do
  let
    distribution =
      [ BigInt.fromInt 1_000_000_000 ]
        /\ [ BigInt.fromInt 1_000_000_000 ]
        /\ [ BigInt.fromInt 1_000_000_000 ]
  runPlutipContract config distribution \(alice /\ bob /\ claire) -> do
    logInfo' "Test.MMS.setSignatures: running"
    aliceHash <- withKeyWallet alice ownPaymentPubKeyHash'
    logInfo' $ "Alice:  " <> show (aliceHash # unwrap >>> unwrap)
    bobHash <- withKeyWallet bob ownPaymentPubKeyHash'
    logInfo' $ "Bob:    " <> show (bobHash # unwrap >>> unwrap)
    claireHash <- withKeyWallet claire ownPaymentPubKeyHash'
    logInfo' $ "Claire: " <> show (claireHash # unwrap >>> unwrap)

    withKeyWallet alice do
      let
        wallets = [ alice, bob, claire ]

      -- 1. Initialize the script

      signers <- for wallets (_ `withKeyWallet` ownPaymentPubKeyHash')
      MultiSign.init (lovelaceValueOf $ BigInt.fromInt 1_000_000) signers

      -- 2. Check multisignature

      { lookups, constraints } <- MultiSign.get signers

      ubTx <- liftedE $ Lookups.mkUnbalancedTx lookups constraints
      let
        ubTx' =
          flip applyToInner ubTx $ Record.modify (Proxy :: Proxy "unbalancedTx") $
            applyToInner $ Record.modify (Proxy :: Proxy "transaction") $
              applyToInner $ Record.modify (Proxy :: Proxy "body") $
                applyToInner $ Record.modify (Proxy :: Proxy "requiredSigners") $
                  const $ Just $ signers <#> unwrap >>> unwrap >>> wrap
      logInfo' "Made unbalanced Tx"

      bTx <- liftedE $ map unwrap <$> balanceTx ubTx'
      let
        bTx' =
          flip applyToInner bTx $ Record.modify (Proxy :: Proxy "body") $
            applyToInner $ Record.modify (Proxy :: Proxy "requiredSigners") $
              const Nothing
      logInfo' "Balanced successfully"

      tx <- liftContractM "Unable to sign transaction" =<< signTransaction bTx'
      txSigned <- signWith wallets tx
      logInfo' "Signed successfully"
      
      submit (wrap txSigned) >>= awaitTxConfirmed

      pure unit

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

applyToInner :: forall t a. Newtype t a => (a -> a) -> t -> t
applyToInner f = unwrap >>> f >>> wrap

config :: PlutipConfig
config =
  { host: "127.0.0.1"
  , port: UInt.fromInt 8082
  , logLevel: Info
  , customLogger: Nothing
  , suppressLogs: false
  , ogmiosConfig:
      { port: UInt.fromInt 1338
      , host: "127.0.0.1"
      , secure: false
      , path: Nothing
      }
  , ogmiosDatumCacheConfig:
      { port: UInt.fromInt 10000
      , host: "127.0.0.1"
      , secure: false
      , path: Nothing
      }
  , ctlServerConfig: Just
      { port: UInt.fromInt 8083
      , host: "127.0.0.1"
      , secure: false
      , path: Nothing
      }
  , postgresConfig:
      { host: "127.0.0.1"
      , port: UInt.fromInt 5433
      , user: "ctxlib"
      , password: "ctxlib"
      , dbname: "ctxlib"
      }
  }
