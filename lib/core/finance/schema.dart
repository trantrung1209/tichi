/// Tichi – cấu trúc cơ sở dữ liệu phần lõi tài chính (phiên bản 1).
///
/// Quy ước:
/// - Tiền lưu bằng số nguyên theo đơn vị nhỏ nhất (VND: đồng, USD: cent).
/// - Thu (INCOME): amount_minor tính theo loại tiền của ví nhận.
/// - Chi (EXPENSE) và chuyển ví (TRANSFER): amount_minor tính theo loại tiền
///   của ví nguồn.
/// - Chuyển ví luôn có destination_amount_minor (số tiền ví nhận được). Cùng
///   loại tiền thì bằng amount_minor; khác loại tiền thì do người dùng nhập.
/// - Xóa giao dịch là xóa mềm: đặt deleted_at, không xóa dòng.
library;

/// Phiên bản mới nhất của cơ sở dữ liệu. Mỗi phiên bản có một danh sách câu
/// lệnh trong [migrations]; app chạy lần lượt từ phiên bản đang có lên đây.
const int schemaVersion = 4;

const Map<int, List<String>> migrations = {
  1: schemaStatements,
  2: savingsSchemaStatements,
  3: settingsSchemaStatements,
  4: iconsAndBudgetsSchemaStatements,
};

/// Biểu tượng và màu mặc định theo loại ví.
const Map<String, String> defaultWalletIcon = {
  'CASH': 'cash',
  'BANK': 'bank',
  'EWALLET': 'phone',
  'SAVINGS': 'coins',
};

const Map<String, String> defaultWalletColor = {
  'CASH': 'green',
  'BANK': 'blue',
  'EWALLET': 'purple',
  'SAVINGS': 'gold',
};

/// Phiên bản 4: biểu tượng và màu cho ví, danh mục, mục tiêu; bảng ngân
/// sách. Dữ liệu đã có được gán biểu tượng phù hợp.
const List<String> iconsAndBudgetsSchemaStatements = [
  "ALTER TABLE wallets ADD COLUMN icon TEXT NOT NULL DEFAULT 'wallet'",
  "ALTER TABLE wallets ADD COLUMN color TEXT NOT NULL DEFAULT 'emerald'",
  "ALTER TABLE categories ADD COLUMN icon TEXT NOT NULL DEFAULT 'more'",
  "ALTER TABLE categories ADD COLUMN color TEXT NOT NULL DEFAULT 'stone'",
  "ALTER TABLE savings_goals ADD COLUMN icon TEXT NOT NULL DEFAULT 'savings'",
  '''
UPDATE wallets SET
  icon = CASE type WHEN 'CASH' THEN 'cash' WHEN 'BANK' THEN 'bank'
    WHEN 'EWALLET' THEN 'phone' WHEN 'SAVINGS' THEN 'coins' ELSE 'wallet' END,
  color = CASE type WHEN 'CASH' THEN 'green' WHEN 'BANK' THEN 'blue'
    WHEN 'EWALLET' THEN 'purple' WHEN 'SAVINGS' THEN 'gold' ELSE 'emerald' END
''',
  "UPDATE categories SET icon = 'food', color = 'orange' WHERE type = 'EXPENSE' AND name = 'Ăn uống'",
  "UPDATE categories SET icon = 'transport', color = 'blue' WHERE type = 'EXPENSE' AND name = 'Di chuyển'",
  "UPDATE categories SET icon = 'shopping', color = 'pink' WHERE type = 'EXPENSE' AND name = 'Mua sắm'",
  "UPDATE categories SET icon = 'home', color = 'teal' WHERE type = 'EXPENSE' AND name = 'Nhà ở'",
  "UPDATE categories SET icon = 'bills', color = 'purple' WHERE type = 'EXPENSE' AND name = 'Hóa đơn'",
  "UPDATE categories SET icon = 'health', color = 'red' WHERE type = 'EXPENSE' AND name = 'Sức khỏe'",
  "UPDATE categories SET icon = 'entertainment', color = 'gold' WHERE type = 'EXPENSE' AND name = 'Giải trí'",
  "UPDATE categories SET icon = 'salary', color = 'green' WHERE type = 'INCOME' AND name = 'Lương'",
  "UPDATE categories SET icon = 'bonus', color = 'gold' WHERE type = 'INCOME' AND name = 'Thưởng'",
  "UPDATE categories SET icon = 'business', color = 'blue' WHERE type = 'INCOME' AND name = 'Kinh doanh'",
  '''
CREATE TABLE budgets (
  id TEXT PRIMARY KEY,
  category_id TEXT REFERENCES categories (id),
  currency_code TEXT NOT NULL CHECK (currency_code IN ('VND', 'USD')),
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
)
''',
  "CREATE UNIQUE INDEX idx_budget_unique ON budgets (COALESCE(category_id, ''), currency_code) WHERE deleted_at IS NULL",
];

/// Phiên bản 3: cài đặt của app (loại tiền hiển thị, tỷ giá nhập tay).
const List<String> settingsSchemaStatements = [
  '''
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  updated_at INTEGER NOT NULL
)
''',
];

/// Số chữ số thập phân của từng loại tiền được hỗ trợ ở v1.
const Map<String, int> currencyExponent = {'VND': 0, 'USD': 2};

const List<String> schemaStatements = [
  '''
CREATE TABLE wallets (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('CASH', 'BANK', 'EWALLET', 'SAVINGS')),
  currency_code TEXT NOT NULL CHECK (currency_code IN ('VND', 'USD')),
  opening_balance_minor INTEGER NOT NULL DEFAULT 0 CHECK (opening_balance_minor >= 0),
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
  created_at INTEGER NOT NULL
)
''',
  '''
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('INCOME', 'EXPENSE')),
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
  created_at INTEGER NOT NULL
)
''',
  '''
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL UNIQUE,
  type TEXT NOT NULL CHECK (type IN ('INCOME', 'EXPENSE', 'TRANSFER')),
  source_wallet_id TEXT REFERENCES wallets (id),
  destination_wallet_id TEXT REFERENCES wallets (id),
  category_id TEXT REFERENCES categories (id),
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
  destination_amount_minor INTEGER CHECK (destination_amount_minor IS NULL OR destination_amount_minor > 0),
  transaction_date TEXT NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL,
  deleted_at INTEGER,
  CHECK (
    (type = 'INCOME'
      AND source_wallet_id IS NULL
      AND destination_wallet_id IS NOT NULL
      AND destination_amount_minor IS NULL)
    OR (type = 'EXPENSE'
      AND source_wallet_id IS NOT NULL
      AND destination_wallet_id IS NULL
      AND destination_amount_minor IS NULL)
    OR (type = 'TRANSFER'
      AND source_wallet_id IS NOT NULL
      AND destination_wallet_id IS NOT NULL
      AND source_wallet_id <> destination_wallet_id
      AND destination_amount_minor IS NOT NULL
      AND category_id IS NULL)
  )
)
''',
  'CREATE INDEX idx_tx_date ON transactions (transaction_date)',
  'CREATE INDEX idx_tx_source ON transactions (source_wallet_id, transaction_date)',
  'CREATE INDEX idx_tx_destination ON transactions (destination_wallet_id, transaction_date)',
  'CREATE INDEX idx_tx_category ON transactions (category_id, transaction_date)',
];

/// Phiên bản 2: Savings Center.
///
/// - Mục tiêu không giữ tiền; nó ghi lại phần nào trong ví tiết kiệm thuộc
///   về nó.
/// - savings_contributions.transaction_id có giá trị: tiền chuyển thật từ ví
///   khác vào. Để trống: chia tiền "Chưa gắn mục tiêu" có sẵn trong ví tiết
///   kiệm cho mục tiêu, không có chuyển ví.
/// - savings_withdrawals luôn gắn với một lần chuyển ví ra ngoài.
/// - request_id chống tạo trùng khi bấm nút nhiều lần.
/// - Mục tiêu bị xóa (deleted_at) không còn được tính, nên tiền của nó tự trở
///   về "Chưa gắn mục tiêu".
const List<String> savingsSchemaStatements = [
  '''
CREATE TABLE savings_goals (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  target_amount_minor INTEGER NOT NULL CHECK (target_amount_minor > 0),
  savings_wallet_id TEXT NOT NULL REFERENCES wallets (id),
  start_date TEXT NOT NULL,
  target_date TEXT NOT NULL,
  priority INTEGER NOT NULL DEFAULT 1 CHECK (priority IN (0, 1, 2)),
  status TEXT NOT NULL DEFAULT 'ACTIVE'
    CHECK (status IN ('ACTIVE', 'PAUSED', 'COMPLETED', 'ARCHIVED')),
  reminder_enabled INTEGER NOT NULL DEFAULT 0 CHECK (reminder_enabled IN (0, 1)),
  reminder_time TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER,
  CHECK (target_date >= start_date)
)
''',
  '''
CREATE TABLE savings_contributions (
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL UNIQUE,
  goal_id TEXT NOT NULL REFERENCES savings_goals (id),
  transaction_id TEXT UNIQUE REFERENCES transactions (id),
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
  contribution_date TEXT NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL
)
''',
  '''
CREATE TABLE savings_withdrawals (
  id TEXT PRIMARY KEY,
  request_id TEXT NOT NULL UNIQUE,
  goal_id TEXT NOT NULL REFERENCES savings_goals (id),
  transaction_id TEXT NOT NULL UNIQUE REFERENCES transactions (id),
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
  withdrawal_date TEXT NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL
)
''',
  'CREATE INDEX idx_goals_wallet ON savings_goals (savings_wallet_id)',
  'CREATE INDEX idx_contrib_goal ON savings_contributions (goal_id)',
  'CREATE INDEX idx_contrib_date ON savings_contributions (contribution_date)',
  'CREATE INDEX idx_withdraw_goal ON savings_withdrawals (goal_id)',
];

/// Số tiền đã tiết kiệm của một mục tiêu: các lần góp còn hiệu lực trừ các
/// lần rút còn hiệu lực. Lần góp hoặc rút mà giao dịch gốc đã bị xóa thì
/// không tính.
const String goalSavedSql = '''
SELECT
  COALESCE((SELECT SUM(c.amount_minor) FROM savings_contributions c
    LEFT JOIN transactions t ON t.id = c.transaction_id
    WHERE c.goal_id = ?1 AND (c.transaction_id IS NULL OR t.deleted_at IS NULL)), 0)
  - COALESCE((SELECT SUM(w.amount_minor) FROM savings_withdrawals w
    JOIN transactions t ON t.id = w.transaction_id
    WHERE w.goal_id = ?1 AND t.deleted_at IS NULL), 0)
  AS saved
''';

/// Số dư của một ví, tính từ số dư đầu và các giao dịch chưa bị xóa.
const String walletBalanceSql = '''
SELECT w.opening_balance_minor
  + COALESCE((SELECT SUM(t.amount_minor) FROM transactions t
      WHERE t.type = 'INCOME' AND t.destination_wallet_id = w.id
        AND t.deleted_at IS NULL), 0)
  + COALESCE((SELECT SUM(t.destination_amount_minor) FROM transactions t
      WHERE t.type = 'TRANSFER' AND t.destination_wallet_id = w.id
        AND t.deleted_at IS NULL), 0)
  - COALESCE((SELECT SUM(t.amount_minor) FROM transactions t
      WHERE t.type IN ('EXPENSE', 'TRANSFER') AND t.source_wallet_id = w.id
        AND t.deleted_at IS NULL), 0)
  AS balance
FROM wallets w
WHERE w.id = ?
''';
