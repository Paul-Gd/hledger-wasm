{-# LANGUAGE OverloadedStrings #-}

module Main where

import qualified Data.Aeson as Aeson
import qualified Data.Aeson.Key as AK
import qualified Data.Aeson.KeyMap as AKM
import qualified Data.ByteString.Lazy.Char8 as BLC
import qualified Data.Text as T
import qualified Data.Set as Set
import System.Environment (getArgs)
import System.IO (hFlush, stdout, stderr, hPutStrLn)
import Control.Exception (catch, SomeException)
import Control.Monad.Except (runExceptT)
import Data.Time.Calendar (Day)

import Hledger
import Hledger.Read (readJournalFile)
import Hledger.Data.Json ()
import Hledger.Reports.AccountTransactionsReport

main :: IO ()
main = do
    args <- getArgs
    case parseArgs args of
        Left err -> hPutStrLn stderr err
        Right parsed -> processFile parsed

-- Parsed command-line arguments
data ParsedArgs = ParsedArgs
    { paCommand  :: String
    , paFile     :: FilePath
    , paPeriod   :: Maybe T.Text    -- from -p flag
    , paRest     :: [String]        -- positional args (account queries etc.)
    }

-- Parse CLI args, extracting -f and -p flags, leaving the rest as positional args.
parseArgs :: [String] -> Either String ParsedArgs
parseArgs args = go args Nothing Nothing []
  where
    go [] _ Nothing _       = Left "Usage: hledger-wasm <command> -f <file> [args...]"
    go [] Nothing (Just _) _ = Left "Usage: hledger-wasm <command> -f <file> [args...]"
    go [] (Just cmd) (Just file) rest = Right ParsedArgs
        { paCommand = cmd
        , paFile    = file
        , paPeriod  = Nothing
        , paRest    = reverse rest
        }
    go (x:xs) Nothing file rest = go xs (Just x) file rest
    go ("-f":f:xs) cmd _ rest = go xs cmd (Just f) rest
    go ("-p":p:xs) cmd file rest =
        case go xs cmd file rest of
            Left err -> Left err
            Right pa -> Right pa { paPeriod = Just (T.pack p) }
    go (x:xs) cmd file rest = go xs cmd file (x:rest)

processFile :: ParsedArgs -> IO ()
processFile pa = (do
    result <- runExceptT $ readJournalFile definputopts (paFile pa)
    case result of
        Left err -> hPutStrLn stderr $ "Parse error: " ++ err
        Right j  -> do
            today <- getCurrentDay
            let rspec = buildReportSpec today pa
            runCommand (paCommand pa) j rspec (paRest pa)
    ) `catch` handleError

-- Build a ReportSpec with the period from -p flag and positional query args.
buildReportSpec :: Day -> ParsedArgs -> ReportSpec
buildReportSpec today pa =
    case updateReportSpec ropts defreportspec { _rsDay = today } of
        Left _     -> defreportspec { _rsDay = today }
        Right spec -> spec
  where
    periodQ = case paPeriod pa of
        Nothing -> []
        Just p  -> ["date:" <> p]
    acctQ = map T.pack (paRest pa)
    allQueryTerms = periodQ ++ acctQ
    ropts = defreportopts { querystring_ = allQueryTerms }

runCommand :: String -> Journal -> ReportSpec -> [String] -> IO ()
runCommand cmd journal rspec args = case cmd of
    "accounts" -> do
        let q = _rsQuery rspec
        let accts = journalAccountNames journal
        let filtered = case q of
              Any -> accts
              _   -> filter (matchesAccount q) accts
        BLC.putStrLn $ Aeson.encode filtered
        hFlush stdout

    "print" -> do
        let j' = filterJournalTransactions (_rsQuery rspec) journal
        BLC.putStrLn $ Aeson.encode (jtxns j')
        hFlush stdout

    "balance" -> do
        let q = _rsQuery rspec
        let accts = journalAccountNames journal
        let filtered = case q of
              Any -> filter (not . T.null) accts
              _   -> filter (\a -> matchesAccount q a && not (T.null a)) accts
        let balances = map (getAccountBalance journal) filtered
        BLC.putStrLn $ Aeson.encode balances
        hFlush stdout

    "aregister" -> case args of
        (account:_) -> do
            let acct = T.pack account
            let report = accountTransactionsReport rspec journal (Acct $ toRegex' acct)
            BLC.putStrLn $ Aeson.encode (map (reportItemToJson acct) report)
            hFlush stdout
        [] -> hPutStrLn stderr "aregister requires an account name"

    "commodities" -> do
        let commodities = Set.toList $ journalCommodities journal
        BLC.putStrLn $ Aeson.encode (map showCommodity commodities)
        hFlush stdout

    _ -> hPutStrLn stderr $ "Unknown command: " ++ cmd

-- Convert an AccountTransactionsReportItem to a JSON object matching
-- standard hledger aregister -O json output shape.
reportItemToJson :: T.Text -> AccountTransactionsReportItem -> Aeson.Value
reportItemToJson _acct (torig, _tacct, _isSplit, otherAccts, change, runBal) =
    Aeson.Object $ AKM.fromList
        [ (AK.fromText "tindex",       Aeson.toJSON (tindex torig))
        , (AK.fromText "tdate",        Aeson.toJSON (show $ tdate torig))
        , (AK.fromText "tdescription", Aeson.toJSON (tdescription torig))
        , (AK.fromText "otherAccounts", Aeson.toJSON otherAccts)
        , (AK.fromText "change",       Aeson.toJSON change)
        , (AK.fromText "balance",      Aeson.toJSON runBal)
        ]

getAccountBalance :: Journal -> T.Text -> (T.Text, MixedAmount)
getAccountBalance journal acct =
    let postings = filter (\p -> paccount p == acct) (journalPostings journal)
        bal = mixedAmountStripCosts $ sumPostings postings
    in (acct, bal)

showCommodity :: CommoditySymbol -> T.Text
showCommodity = id

handleError :: SomeException -> IO ()
handleError e = hPutStrLn stderr $ "Error: " ++ show e
