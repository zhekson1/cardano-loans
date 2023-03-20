#!/bin/sh

# A helper script for showing how to close an Offer as a lender.

## Variables
dir="../assets/loan-files/"
tmpDir="../assets/tmp/"

loanScriptFile="${dir}loan.plutus"
beaconPolicyFile="${dir}beacons.plutus"

lenderPaymentPubKeyFile="../assets/wallets/02.vkey"
lenderPaymentPubKeyHashFile="../assets/wallets/02.pkh"

beaconRedeemerFile="${dir}burnBeacons.json"
closeOfferRedeemerFile="${dir}closeOffer.json"

offerTokenName="4f66666572" # This is the hexidecimal encoding for 'Offer'.

## Export the loan validator script.
echo "Exporting the loan validator script..."
cardano-loans export-script \
  --loan-script \
  --out-file $loanScriptFile

## Export the beacon policy.
echo "Exporting the beacon policy script..."
cardano-loans export-script \
  --beacon-policy \
  --out-file $beaconPolicyFile

## Create the BurnBeaconToken beacon policy redeemer.
echo "Creating the burning redeemer..."
cardano-loans lender burn-beacons \
  --out-file $beaconRedeemerFile

## Generate the hash for the lender's payment pubkey.
echo "Calculating the hash of the lender's payment pubkey..."
cardano-cli address key-hash \
  --payment-verification-key-file $lenderPaymentPubKeyFile \
  --out-file $lenderPaymentPubKeyHashFile

## Create the CloseAsk redeemer for the loan validator.
echo "Creating the spending redeemer..."
cardano-loans lender close-offer \
  --out-file $closeOfferRedeemerFile

## Get the beacon policy id.
echo "Calculating the beacon policy id..."
beaconPolicyId=$(cardano-cli transaction policyid \
  --script-file $beaconPolicyFile)

## Helper beacon variables
offerBeacon="${beaconPolicyId}.${offerTokenName}"

## Helper Lender ID beacon variable.
lenderPaymentPubKeyHash=$(cat $lenderPaymentPubKeyHashFile)
lenderBeacon="${beaconPolicyId}.${lenderPaymentPubKeyHash}"

## Create and submit the transaction.
cardano-cli query protocol-parameters \
  --testnet-magic 1 \
  --out-file "${tmpDir}protocol.json"

cardano-cli transaction build \
  --tx-in 4966c287d06dfeedc9c302774876c3eca3327b4e8fec7bf56bb700702df388c0#0 \
  --tx-in-script-file $loanScriptFile \
  --tx-in-inline-datum-present \
  --tx-in-redeemer-file $closeOfferRedeemerFile \
  --mint "-1 ${offerBeacon} + -1 ${lenderBeacon}" \
  --mint-script-file $beaconPolicyFile \
  --mint-redeemer-file $beaconRedeemerFile \
  --required-signer-hash "$(cat $lenderPaymentPubKeyHashFile)" \
  --change-address "$(cat ../assets/wallets/02.addr)" \
  --tx-in-collateral 62d4e442d8f01e035003fc60d448289440ca9b390c71385f11a55ac07b695ee0#2 \
  --testnet-magic 1 \
  --protocol-params-file "${tmpDir}protocol.json" \
  --out-file "${tmpDir}tx.body"

cardano-cli transaction sign \
  --tx-body-file "${tmpDir}tx.body" \
  --signing-key-file ../assets/wallets/02.skey \
  --testnet-magic 1 \
  --out-file "${tmpDir}tx.signed"

cardano-cli transaction submit \
  --testnet-magic 1 \
  --tx-file "${tmpDir}tx.signed"