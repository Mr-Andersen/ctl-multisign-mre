{ name = "ctl-multisign-mre-offchain"
, dependencies =
  [ "bigints", "cardano-transaction-lib", "ordered-collections", "uint" ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs" ]
}
