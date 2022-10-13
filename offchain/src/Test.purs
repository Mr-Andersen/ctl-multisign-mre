module Test where

import Contract.Prelude

import Contract.Address (PaymentPubKeyHash, ownPaymentPubKeyHash)
import Contract.Log (logInfo')
import Contract.Monad (Contract, launchAff_, liftContractM, liftedM, liftedE)
import Contract.ScriptLookups (mkUnbalancedTx) as Lookups
import Contract.Transaction (awaitTxConfirmed, balanceTx, signTransaction, submit)
import Contract.Value (lovelaceValueOf)
import Contract.Wallet (withKeyWallet)
import Data.BigInt (fromInt) as BigInt
import Data.UInt (fromInt) as UInt
import Plutip.Server (runPlutipContract)
import Plutip.Types (PlutipConfig)

import MultiSign (init, get) as MultiSign
import Utils (signWith, (<#))

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
    logInfo' $ "Alice:  " <> show (aliceHash <# unwrap)
    bobHash <- withKeyWallet bob ownPaymentPubKeyHash'
    logInfo' $ "Bob:    " <> show (bobHash <# unwrap)
    claireHash <- withKeyWallet claire ownPaymentPubKeyHash'
    logInfo' $ "Claire: " <> show (claireHash <# unwrap)

    withKeyWallet alice do
      let
        wallets = [ alice, bob, claire ]

      -- 1. Initialize the script

      signers <- for wallets (_ `withKeyWallet` ownPaymentPubKeyHash')
      MultiSign.init (lovelaceValueOf $ BigInt.fromInt 1_000_000) signers

      -- 2. Check multisignature

      { lookups, constraints } <- MultiSign.get signers

      ubTx <- liftedE $ Lookups.mkUnbalancedTx lookups constraints
      logInfo' "Made unbalanced Tx"

      bTx <- liftedE $ map unwrap <$> balanceTx ubTx
      logInfo' "Balanced successfully"

      tx <- liftContractM "Unable to sign transaction" =<< signTransaction bTx
      txSigned <- signWith wallets tx
      logInfo' "Signed successfully"
      
      submit (wrap txSigned) >>= awaitTxConfirmed

      pure unit

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
