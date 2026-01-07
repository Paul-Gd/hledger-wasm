{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy.Char8 as BLC
import qualified Data.Text as T
import qualified Data.Set as Set
import System.Environment (getArgs)
import System.IO (hFlush, stdout, stderr, hPutStrLn)
import Control.Exception (catch, SomeException)
import Control.Monad.Except (runExceptT)

import Hledger
import Hledger.Read (readJournalFile)
import Hledger.Data.Json ()

main :: IO ()
main = do
    args <- getArgs
    case args of
        (cmd:file:rest) -> processFile cmd file rest
        [cmd] -> hPutStrLn stderr $ "Command " ++ cmd ++ " requires a file path"
        _ -> do
            hPutStrLn stderr "Usage: hledger-wasm <command> <file> [args...]"
            hPutStrLn stderr "Commands: accounts, print, balance, aregister"

processFile :: String -> FilePath -> [String] -> IO ()
processFile cmd file extraArgs = (do
    result <- runExceptT $ readJournalFile definputopts file
    case result of
        Left err -> hPutStrLn stderr $ "Parse error: " ++ err
        Right j -> runCommand cmd j extraArgs
    ) `catch` handleError

runCommand :: String -> Journal -> [String] -> IO ()
runCommand cmd journal args = case cmd of
    "accounts" -> do
        let accounts = journalAccountNames journal
        BLC.putStrLn $ Aeson.encode accounts
        hFlush stdout
    
    "print" -> do
        let txns = jtxns journal
        BLC.putStrLn $ Aeson.encode txns
        hFlush stdout
    
    "balance" -> do
        -- Get balance tree with all accounts
        let accounts = journalAccountNames journal
        -- For each account, compute the balance
        let balances = map (getAccountBalance journal) (filter (not . T.null) accounts)
        BLC.putStrLn $ Aeson.encode balances
        hFlush stdout
    
    "aregister" -> case args of
        (account:_) -> do
            -- Get transactions for a specific account
            let acct = T.pack account
            let txns = filter (hasPosting acct) (jtxns journal)
            BLC.putStrLn $ Aeson.encode txns
            hFlush stdout
        [] -> hPutStrLn stderr "aregister requires an account name"
    
    "commodities" -> do
        -- Get all commodities used in the journal
        let commodities = Set.toList $ journalCommodities journal
        BLC.putStrLn $ Aeson.encode (map showCommodity commodities)
        hFlush stdout
    
    _ -> hPutStrLn stderr $ "Unknown command: " ++ cmd

-- Get balance for an account
getAccountBalance :: Journal -> T.Text -> (T.Text, MixedAmount)
getAccountBalance journal acct = 
    let postings = filter (\p -> paccount p == acct) (journalPostings journal)
        balance = sumPostings postings
    in (acct, balance)

-- Check if transaction has posting to account
hasPosting :: T.Text -> Transaction -> Bool
hasPosting acct txn = any (\p -> acct `T.isPrefixOf` paccount p) (tpostings txn)

-- Show commodity info
showCommodity :: CommoditySymbol -> T.Text
showCommodity = id

handleError :: SomeException -> IO ()
handleError e = hPutStrLn stderr $ "Error: " ++ show e
