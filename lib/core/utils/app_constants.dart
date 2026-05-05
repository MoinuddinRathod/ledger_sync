
const String LEDGER_SYNC_DB = "ledger_sync_db.db";
const String TABLE_ACCOUNTS = "accounts";
const String ACCOUNT_ID = "account_id";
const String ACCOUNT_NAME = "account_name";
const String ACCOUNT_PIN = "pin";
const String CREATED_AT = "created_at";
const String UPDATED_AT = "updated_at";
const String DELETED_AT = "deleted_at";
const String IS_DEFAULT = "is_default";
const String IS_LOGGED_IN = "is_logged_in";
const String TXN_MASTER_ACCOUNT_ID = "master_account_id";
const String HAS_COMPLETED_ONBOARDING = "has_completed_onboarding";
const String AMOUNT = "amount";
const String TXN_REF = "txn_ref";
// ------- bank accounts table ------- //
const String TABLE_BANK_ACCOUNTS = "bank_accounts";

// COLUMNS
const String BANK_ACCOUNT_ID = "bank_account_id";
const String BANK_NAME = "bank_name";
const String BANK_ACCOUNT_NUMBER = "bank_account_number";
const String ACCOUNT_HOLDER_NAME = "account_holder_name";
const String ACCOUNT_TYPE = "account_type"; // saving, current
const String CURRENT_BALANCE = "current_balance";
const String DATE_ADDED = "date_added";
const String LAST_FOUR_DIGITS = "last_four_digits";

// ---------- cash wallet ---------- //
const String TABLE_CASH_WALLET = "cash_wallet";
const String CASH_WALLET_ID = "cash_wallet_id";
const String CASH_WALLET_CURRENT_BALANCE = "current_balance";

// ---------- cash wallet transactions ---------- //
const String TABLE_CASH_WALLET_TRANSACTIONS = "cash_wallet_transactions";
const String CASH_WALLET_TRANSACTION_ID = "cash_wallet_transaction_id";
const String CASH_WALLET_TRANSACTION_ACCOUNT_ID = "account_id";
const String CASH_WALLET_TRANSACTION_TYPE =
    "transaction_type"; // debit or credit
const String TRANSACTION_NOTE = "transaction_note";
const String CASH_WALLET_TRANSACTION_AMOUNT = "amount";
const String CASH_WALLET_TRANSACTION_TAG_ID = "tag_id";
const String CASH_WALLET_TRANSACTION_BANK_ACCOUNT_ID =
    "cash_wallet_transaction_bank_account_id";
const String CASH_WALLET_IS_MANUAL = "is_manual";

// ---------- virtual entries ---------- //
const String TABLE_VIRTUAL_ENTRIES = "virtual_entries";
const String VIRTUAL_ENTRY_ID = "virtual_entry_id";
const String VE_ACCOUNT_ID = "account_id";
const String VE_TAG_ID = "tag_id";
const String VE_ENTRY_TYPE = "entry_type"; // Receivable or Payable
const String VE_AMOUNT = "amount";
const String VE_NOTE = "note";
const String VE_DATE_ADDED = "date_added";
const String VE_CREATED_AT = "created_at";
const String VE_UPDATED_AT = "updated_at";
const String VE_DELETED_AT = "deleted_at";
const String VE_STATUS = "ve_status"; // 'pending' or 'resolved'
const String VE_MATCHED_TXN_ID = "ve_matched_txn_id"; // FK to transactions
const String VE_DUE_DATE =
    "ve_due_date"; // Optional due date for the virtual entry

// ---------- tags ---------- //
const String TABLE_TAGS = "tags";
// columns
const String TAG_ID = "tag_id";
const String TAG_NAME = "tag_name";
const String TAG_KEYWORDS = "tag_keywords";
const String TAG_PRIORITY =
    "tag_priority"; // 1 == bank account level 2 == party level 3 == global
const String TAG_BANK_ACCOUNT_ID =
    "tag_bank_account_id"; // FOREIGN KEY IF TAG IS ACCOUNT LEVEL
const String TAG_USER_ID =
    "tag_user_id"; // FOREIGN KEY IF TAG IS USER (PARTY) LEVEL

const String TAG_CREATED_AT = "tag_created_at";
const String TAG_UPDATED_AT = "tag_updated_at";
const String TAG_DELETED_AT = "tag_deleted_at";

const String TABLE_TRANSACTIONS = 'transactions';

// ------------------ Columns ------------------ //

const String TXN_ID = "txn_id"; // optional but recommended (PK)

const String TXN_DATE = "txn_date";
const String TXN_ACCOUNT_ID = "txn_account_id"; // bank account id
const String TXN_TAG_ID = "txn_tag_id";

const String TXN_AMOUNT = "txn_amount";
const String TXN_TYPE = "txn_type"; // 'dr' or 'cr'
const String TXN_NARRATION = "txn_narration";
const String TXN_IS_MANUAL = "txn_is_manual";

const String TABLE_IMPORT_SESSIONS = 'import_sessions';
const String IMPORT_SESSION_ID = 'import_session_id';
const String IMPORT_BANK_ACCOUNT_NUMBER = 'bank_account_number';
const String IMPORT_OPENING_BALANCE = 'opening_balance';
const String IMPORT_FROM_DATE = 'from_date';
const String IMPORT_TO_DATE = 'to_date';
const String IMPORT_CREATED_AT = 'created_at';

////////////////////////////////////////////////////////////////////
/////////// -------  OLD CONSTANTS ----------------------- /////////
////////////////////////////////////////////////////////////////////
// ------- table statements -------- //

// ------- bank statement accounts table ------- //
const String TABLE_BANK_STATEMENT_ACCOUNTS = "bank_statement_accounts";
const String BSA_ID = "bsa_id";
const String BSA_ACCOUNT_NUMBER = "account_number";
const String BSA_ACCOUNT_NAME = "account_name";
const String BSA_BANK = "bank";
const String BSA_MAPPING_TYPE = "mapping_type"; // 'MA' or 'Party'
const String BSA_MAPPING_ID = "mapping_id";
const String BSA_MAPPING_NAME = "mapping_name";

// ------- transactions table (old - kept for migration) ------- //
const String TRANSACTION_ID = "transaction_id";
const String TRANSACTION_VOUCHER_NO = "voucher_no";
const String TRANSACTION_VOUCHER_TYPE = "voucher_type";
const String TRANSACTION_DATE = "date";
const String TRANSACTION_NARRATION = "narration";
const String TRANSACTION_CREATED_AT = "created_at";

// ------- transaction entries table ------- //
const String TABLE_TRANSACTION_ENTRIES = "transaction_entries";
const String TRANSACTION_ENTRY_ID = "transaction_entry_id";
const String TRANSACTION_ENTRY_TRANSACTION_ID = "transaction_id";
const String TRANSACTION_ENTRY_ACCOUNT_ID = "account_id";
const String TRANSACTION_ENTRY_TYPE = "type";
const String TRANSACTION_ENTRY_AMOUNT = "amount";

// ------- master accounts table (old - kept for migration) ------- //

const String MASTER_ACCOUNT_ID = "id";
const String MASTER_ACCOUNT_NAME = "name";
const String MASTER_ACCOUNT_TYPE = "type";
const String MASTER_ACCOUNT_KEYWORDS = "keywords"; // JSON array
const String MASTER_ACCOUNT_CREATED_AT = "created_at";

// ============================================================
// NEW TABLES - v5 Migration
// ============================================================

// ------- master_accounts (new) ------- //
const String TABLE_MASTER_ACCOUNTS_NEW = "master_accounts";
const String MA_ID = "id";
const String MA_NAME = "name";
const String MA_TYPE = "type"; // cash, bank, party, expense, income
const String MA_ALIAS = "alias"; // comma-separated keywords
const String MA_OPENING_BALANCE = "opening_balance";
const String MA_PHONE = "phone"; // for party type
const String MA_CREATED_AT = "created_at";
const String MA_UPDATED_AT = "updated_at";
const String MA_IS_ACTIVE = "is_active";
