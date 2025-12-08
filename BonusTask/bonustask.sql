/*
==============================================================
                       DOCUMENTATION
==============================================================

1) OVERVIEW
-----------
This system implements a simplified banking core with:
 - ACID-compliant transfers between accounts
 - Multi-currency conversion based on real-time exchange rates
 - Daily transaction limit enforcement
 - Automatic audit logging for compliance
 - Regulatory reporting via advanced SQL views
 - Performance optimization using multiple types of indexes
 - Safe batch payroll processing with advisory locks

It covers real-world database challenges:
concurrency handling, partial rollbacks, JSONB processing,
window functions, and materialized views.

--------------------------------------------------------------

2) DATABASE STRUCTURE
---------------------
Tables:
 - customers:
       Stores customer profile, daily limits, and status.
 - accounts:
       Holds balances, currency type, activation/closure state.
 - exchange_rates:
       Used to convert foreign currency amounts to KZT.
 - transactions:
       Not only raw values but KZT-converted amount for analytics.
 - audit_log:
       Tracks all CREATE/UPDATE/DELETE and failed attempts (JSONB).

Purpose of JSONB:
 - Flexible audit storage
 - Easy advanced search using GIN index

--------------------------------------------------------------

3) STORED PROCEDURE: process_transfer
-------------------------------------
Responsibilities:
 - Validates both accounts and customer status
 - Enforces balance and daily limit
 - Locks rows (SELECT FOR UPDATE) to avoid race conditions
 - Performs conversion to KZT
 - Inserts a full transaction record
 - Logs success and failure to audit_log
 - Ensures atomicity via transactional exception handling

--------------------------------------------------------------

4) STORED PROCEDURE: process_salary_batch
-----------------------------------------
Goal:
Process many transfers in one atomic transaction while
allowing partial failures.

Key features:
 - Advisory locks prevent multiple simultaneous payrolls
 - Checks total amount before processing
 - Uses SAVEPOINT per employee:
       - success continues
       - failure rolls back only 1 payment
 - Daily limits are bypassed for salary transfers
 - Automatically refreshes materialized reporting view

--------------------------------------------------------------

5) REPORTING VIEWS
------------------
Views support analytics required by regulators.

customer_balance_summary:
 - Shows total balance per customer converted to KZT
 - Computes daily limit utilization
 - Ranks users using window functions

daily_transaction_report:
 - Aggregates by day and type
 - Uses running totals and day-over-day growth %
 - Demonstrates analytical window functions

suspicious_activity_view:
 - Detects high-value and rapid transfers
 - Uses SECURITY BARRIER to prevent data leakage

--------------------------------------------------------------

6) PERFORMANCE OPTIMIZATION
---------------------------
Indexes implemented:
 - Covering B-tree index for fastest reporting queries
 - Partial index for active accounts (reduces scan cost)
 - Expression index on LOWER(email) for case-insensitive search
 - Composite index for frequent from/to account pattern
 - GIN index for optimized JSONB audit lookups

Testing using EXPLAIN ANALYZE:
 - Demonstrates faster query plans
 - Reduces sequential scans
 - Improves latency on large datasets

--------------------------------------------------------------

7) CONCURRENCY & ACID COMPLIANCE
--------------------------------
 - SELECT ... FOR UPDATE ensures consistent balances
 - Advisory locks synchronize batch operations
 - SAVEPOINT allows partial rollback
 - Automatic logging ensures auditability
 - All procedures use transactional integrity

--------------------------------------------------------------
*/


-- ========= TABLES =========

CREATE TABLE customers(
    customer_id SERIAL PRIMARY KEY,
    iin CHAR(12) UNIQUE,
    full_name TEXT,
    phone TEXT,
    email TEXT,
    status TEXT CHECK(status IN ('active','blocked','frozen')),
    created_at TIMESTAMP DEFAULT NOW(),
    daily_limit_kzt NUMERIC(18,2)
);

CREATE TABLE accounts(
    account_id SERIAL PRIMARY KEY,
    customer_id INT REFERENCES customers(customer_id),
    account_number TEXT UNIQUE,
    currency TEXT CHECK(currency IN ('KZT','USD','EUR','RUB')),
    balance NUMERIC(18,2),
    is_active BOOLEAN DEFAULT TRUE,
    opened_at TIMESTAMP DEFAULT NOW(),
    closed_at TIMESTAMP
);

CREATE TABLE exchange_rates(
    rate_id SERIAL PRIMARY KEY,
    from_currency TEXT,
    to_currency TEXT,
    rate NUMERIC(18,6),
    valid_from TIMESTAMP,
    valid_to TIMESTAMP
);

CREATE TABLE transactions(
    transaction_id SERIAL PRIMARY KEY,
    from_account_id INT REFERENCES accounts(account_id),
    to_account_id   INT REFERENCES accounts(account_id),
    amount NUMERIC(18,2),
    currency TEXT,
    exchange_rate NUMERIC(18,6),
    amount_kzt NUMERIC(18,2),
    type TEXT,
    status TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    description TEXT
);

CREATE TABLE audit_log(
    log_id SERIAL PRIMARY KEY,
    table_name TEXT,
    record_id INT,
    action TEXT,
    old_values JSONB,
    new_values JSONB,
    changed_by TEXT,
    changed_at TIMESTAMP DEFAULT NOW(),
    ip_address TEXT
);

-- ========= TEST DATA =========

INSERT INTO customers (iin, full_name, phone, email, status, daily_limit_kzt)
VALUES
('000000000001','Alice Tan','+77010000001','alice@demo.kz','active',2000000),
('000000000002','Bob Lee','+77010000002','bob@demo.kz','active',3000000),
('000000000003','Carla Kim','+77010000003','carla@demo.kz','active',1500000),
('000000000004','David Park','+77010000004','david@demo.kz','blocked',1000000),
('000000000005','Erlan Nur','+77010000005','erlan@demo.kz','active',5000000),
('000000000006','Fatima Ali','+77010000006','fatima@demo.kz','frozen',800000),
('000000000007','George Fox','+77010000007','george@demo.kz','active',2500000),
('000000000008','Hiro Tanaka','+77010000008','hiro@demo.kz','active',4000000),
('000000000009','Ivan Petrov','+77010000009','ivan@demo.kz','active',3500000),
('000000000010','Jasmin Omar','+77010000010','jasmin@demo.kz','active',6000000);

INSERT INTO accounts (customer_id, account_number, currency, balance, is_active)
VALUES
(1,'KZ000000000000000001','KZT',1500000,TRUE),
(1,'KZ000000000000000002','USD',  5000,TRUE),
(2,'KZ000000000000000003','KZT', 800000,TRUE),
(3,'KZ000000000000000004','EUR',  2000,TRUE),
(4,'KZ000000000000000005','KZT', 300000,TRUE),
(5,'KZ000000000000000006','KZT',4000000,TRUE),
(6,'KZ000000000000000007','KZT', 700000,TRUE),
(7,'KZ000000000000000008','USD',  1500,TRUE),
(8,'KZ000000000000000009','RUB',2000000,TRUE),
(9,'KZ000000000000000010','KZT',1200000,TRUE),
(10,'KZ000000000000000011','KZT',5500000,TRUE);

INSERT INTO exchange_rates (from_currency, to_currency, rate, valid_from, valid_to)
VALUES
('USD','KZT',500, NOW() - INTERVAL '1 day', NOW() + INTERVAL '30 days'),
('EUR','KZT',550, NOW() - INTERVAL '1 day', NOW() + INTERVAL '30 days'),
('RUB','KZT',  5, NOW() - INTERVAL '1 day', NOW() + INTERVAL '30 days'),
('KZT','KZT',  1, NOW() - INTERVAL '1 day', NOW() + INTERVAL '30 days'),
('USD','KZT',470, NOW() - INTERVAL '60 day', NOW() - INTERVAL '2 day'),
('EUR','KZT',520, NOW() - INTERVAL '60 day', NOW() - INTERVAL '2 day'),
('RUB','KZT',  4, NOW() - INTERVAL '60 day', NOW() - INTERVAL '2 day'),
('KZT','KZT',  1, NOW() - INTERVAL '60 day', NOW() - INTERVAL '2 day');

INSERT INTO transactions
(from_account_id,to_account_id,amount,currency,exchange_rate,amount_kzt,
 type,status,description,created_at,completed_at)
VALUES
(1,3,100000,'KZT',1,100000,'transfer','completed','Rent',NOW()-INTERVAL '5 day',NOW()-INTERVAL '5 day'),
(3,1, 50000,'KZT',1, 50000,'transfer','completed','Refund',NOW()-INTERVAL '4 day',NOW()-INTERVAL '4 day'),
(1,6, 20000,'KZT',1, 20000,'transfer','completed','Groceries',NOW()-INTERVAL '3 day',NOW()-INTERVAL '3 day'),
(2,8,   100,'USD',500,50000,'transfer','completed','Gift',NOW()-INTERVAL '2 day',NOW()-INTERVAL '2 day'),
(8,1,    50,'USD',500,25000,'transfer','completed','Present',NOW()-INTERVAL '1 day',NOW()-INTERVAL '1 day'),
(5,9,150000,'KZT',1,150000,'transfer','completed','Supplies',NOW()-INTERVAL '7 day',NOW()-INTERVAL '7 day'),
(9,5, 90000,'KZT',1, 90000,'transfer','completed','Return',NOW()-INTERVAL '6 day',NOW()-INTERVAL '6 day'),
(10,1,300000,'KZT',1,300000,'transfer','completed','Contract',NOW()-INTERVAL '2 day',NOW()-INTERVAL '2 day'),
(1,10,120000,'KZT',1,120000,'transfer','completed','Services',NOW()-INTERVAL '1 day',NOW()-INTERVAL '1 day'),
(6,4,  3000,'KZT',1,  3000,'transfer','completed','Test small',NOW()-INTERVAL '12 hour',NOW()-INTERVAL '12 hour');

INSERT INTO audit_log (table_name,record_id,action,old_values,new_values,changed_by,ip_address)
VALUES
('customers',1,'INSERT',NULL, jsonb_build_object('customer_id',1),'system','127.0.0.1'),
('customers',2,'INSERT',NULL, jsonb_build_object('customer_id',2),'system','127.0.0.1'),
('customers',3,'INSERT',NULL, jsonb_build_object('customer_id',3),'system','127.0.0.1'),
('accounts',1,'INSERT',NULL, jsonb_build_object('account_id',1),'system','127.0.0.1'),
('accounts',2,'INSERT',NULL, jsonb_build_object('account_id',2),'system','127.0.0.1'),
('accounts',3,'INSERT',NULL, jsonb_build_object('account_id',3),'system','127.0.0.1'),
('exchange_rates',1,'INSERT',NULL, jsonb_build_object('rate_id',1),'system','127.0.0.1'),
('transactions',1,'INSERT',NULL, jsonb_build_object('transaction_id',1),'system','127.0.0.1'),
('transactions',2,'INSERT',NULL, jsonb_build_object('transaction_id',2),'system','127.0.0.1'),
('transactions',3,'INSERT',NULL, jsonb_build_object('transaction_id',3),'system','127.0.0.1');

-- ========= INDEXES =========

--before
EXPLAIN ANALYZE
SELECT *
FROM transactions
WHERE created_at::date = CURRENT_DATE
  AND type = 'transfer';

/*
Seq Scan on transactions  (cost=0.00..16.60 rows=1 width=216) (actual time=0.022..0.022 rows=1 loops=1)
  Filter: ((type = 'transfer'::text) AND ((created_at)::date = CURRENT_DATE))
  Rows Removed by Filter: 9
Planning Time: 0.252 ms
Execution Time: 0.199 ms

*/

-- (b) Create index (if not exists)
CREATE INDEX IF NOT EXISTS idx_tx_created_type
ON transactions(created_at, type, amount_kzt);

-- (c) Query after index
EXPLAIN ANALYZE
SELECT *
FROM transactions
WHERE created_at::date = CURRENT_DATE
  AND type = 'transfer';

/*
Seq Scan on transactions  (cost=0.00..1.20 rows=1 width=216) (actual time=0.019..0.019 rows=1 loops=1)
  Filter: ((type = 'transfer'::text) AND ((created_at)::date = CURRENT_DATE))
  Rows Removed by Filter: 9
Planning Time: 0.713 ms
Execution Time: 0.035 ms

*/

--before
EXPLAIN ANALYZE
SELECT *
FROM accounts
WHERE is_active = TRUE
  AND account_number = 'KZ000000000000000001';
/*
Index Scan using accounts_account_number_key on accounts  (cost=0.15..8.17 rows=1 width=109) (actual time=0.020..0.021 rows=1 loops=1)
  Index Cond: (account_number = 'KZ000000000000000001'::text)
  Filter: is_active
Planning Time: 0.127 ms
Execution Time: 0.037 ms

*/

-- (b) Create partial index
CREATE INDEX IF NOT EXISTS idx_active_accounts
ON accounts(account_number)
WHERE is_active;

-- (c) Query after index
EXPLAIN ANALYZE
SELECT *
FROM accounts
WHERE is_active = TRUE
  AND account_number = 'KZ000000000000000001';

/*
Seq Scan on accounts  (cost=0.00..1.14 rows=1 width=109) (actual time=0.009..0.010 rows=1 loops=1)
  Filter: (is_active AND (account_number = 'KZ000000000000000001'::text))
  Rows Removed by Filter: 10
Planning Time: 0.329 ms
Execution Time: 0.022 ms

*/
--before
EXPLAIN ANALYZE
SELECT *
FROM customers
WHERE LOWER(email) = LOWER('alice@demo.kz');

/*
Seq Scan on customers  (cost=0.00..15.10 rows=2 width=212) (actual time=0.009..0.013 rows=1 loops=1)
  Filter: (lower(email) = 'alice@demo.kz'::text)
  Rows Removed by Filter: 9
Planning Time: 0.469 ms
Execution Time: 0.021 ms

*/

-- (b) Create expression index
CREATE INDEX IF NOT EXISTS idx_email_ci
ON customers((LOWER(email)));

-- (c) Query after index
EXPLAIN ANALYZE
SELECT *
FROM customers
WHERE LOWER(email) = LOWER('alice@demo.kz');

/*
Seq Scan on customers  (cost=0.00..1.15 rows=1 width=212) (actual time=0.010..0.013 rows=1 loops=1)
  Filter: (lower(email) = 'alice@demo.kz'::text)
  Rows Removed by Filter: 9
Planning Time: 0.270 ms
Execution Time: 0.024 ms

*/
--before
EXPLAIN ANALYZE
SELECT *
FROM transactions
WHERE from_account_id = 1
  AND to_account_id   = 3;

/*
Seq Scan on transactions  (cost=0.00..1.15 rows=1 width=216) (actual time=0.008..0.009 rows=1 loops=1)
  Filter: ((from_account_id = 1) AND (to_account_id = 3))
  Rows Removed by Filter: 9
Planning Time: 0.083 ms
Execution Time: 0.019 ms

*/

-- (b) Create composite index
CREATE INDEX IF NOT EXISTS idx_tx_from_to
ON transactions(from_account_id, to_account_id);

-- (c) Query after index
EXPLAIN ANALYZE
SELECT *
FROM transactions
WHERE from_account_id = 1
  AND to_account_id   = 3;

/*
Seq Scan on transactions  (cost=0.00..1.15 rows=1 width=216) (actual time=0.010..0.012 rows=1 loops=1)
  Filter: ((from_account_id = 1) AND (to_account_id = 3))
  Rows Removed by Filter: 9
Planning Time: 0.347 ms
Execution Time: 0.024 ms

*/
--before
EXPLAIN ANALYZE
SELECT *
FROM audit_log
WHERE new_values @> '{"customer_id":1}';
/*
Seq Scan on audit_log  (cost=0.00..14.25 rows=3 width=208) (actual time=0.013..0.015 rows=1 loops=1)
"  Filter: (new_values @> '{""customer_id"": 1}'::jsonb)"
  Rows Removed by Filter: 9
Planning Time: 0.086 ms
Execution Time: 0.029 ms

*/

-- (b) Create GIN index
CREATE INDEX IF NOT EXISTS idx_audit_json_gin
ON audit_log USING gin(new_values);

-- (c) Query after index
EXPLAIN ANALYZE
SELECT *
FROM audit_log
WHERE new_values @> '{"customer_id":1}';

/*
Seq Scan on audit_log  (cost=0.00..1.12 rows=1 width=208) (actual time=0.009..0.011 rows=1 loops=1)
"  Filter: (new_values @> '{""customer_id"": 1}'::jsonb)"
  Rows Removed by Filter: 9
Planning Time: 0.302 ms
Execution Time: 0.023 ms

*/

/*
/*
Для небольших таблиц PostgreSQL продолжает выбирать Seq Scan,
даже после создания индекса, так как стоимость полного сканирования
всё ещё ниже. На больших объёмах данных планировщик начнёт
использовать Index Scan / Bitmap Index Scan.
*/
*/

-- ========= FUNCTION: process_transfer =========

CREATE OR REPLACE FUNCTION process_transfer(
    p_from_account TEXT,
    p_to_account   TEXT,
    p_amount       NUMERIC,
    p_currency     TEXT,
    p_descr        TEXT,
    p_ignore_daily_limit BOOLEAN DEFAULT FALSE
)
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_id INT;
    v_to_id INT;
    v_from_balance NUMERIC;
    v_rate NUMERIC;
    v_amount_kzt NUMERIC;
    v_customer_id INT;
    v_daily_limit NUMERIC;
    v_today_total NUMERIC;
    v_status TEXT;
    v_tx_id INT;
BEGIN
    -- source account
    SELECT a.account_id, a.customer_id, a.balance
    INTO v_from_id, v_customer_id, v_from_balance
    FROM accounts a
    WHERE a.account_number = p_from_account
      AND a.is_active = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO audit_log(table_name,action,new_values,changed_by)
        VALUES('accounts','FAILED_FROM',jsonb_build_object('from_account',p_from_account),'process_transfer');
        RAISE EXCEPTION 'Source account not found or inactive' USING ERRCODE='A001';
    END IF;

    -- destination account
    SELECT a.account_id
    INTO v_to_id
    FROM accounts a
    WHERE a.account_number = p_to_account
      AND a.is_active = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        INSERT INTO audit_log(table_name,action,new_values,changed_by)
        VALUES('accounts','FAILED_TO',jsonb_build_object('to_account',p_to_account),'process_transfer');
        RAISE EXCEPTION 'Destination account not found or inactive' USING ERRCODE='A002';
    END IF;

    -- customer status and daily limit
    SELECT daily_limit_kzt,status
    INTO v_daily_limit, v_status
    FROM customers
    WHERE customer_id = v_customer_id;

    IF v_status <> 'active' THEN
        INSERT INTO audit_log(table_name,record_id,action,new_values,changed_by)
        VALUES('customers',v_customer_id,'FAILED_STATUS',jsonb_build_object('status',v_status),'process_transfer');
        RAISE EXCEPTION 'Customer not active' USING ERRCODE='A003';
    END IF;

    -- balance check
    IF v_from_balance < p_amount THEN
        INSERT INTO audit_log(table_name,record_id,action,new_values,changed_by)
        VALUES('accounts',v_from_id,'FAILED_FUNDS',jsonb_build_object('balance',v_from_balance,'need',p_amount),'process_transfer');
        RAISE EXCEPTION 'Insufficient funds' USING ERRCODE='A004';
    END IF;

    -- currency conversion to KZT
    IF p_currency = 'KZT' THEN
        v_rate := 1;
        v_amount_kzt := p_amount;
    ELSE
        SELECT rate
        INTO v_rate
        FROM exchange_rates
        WHERE from_currency = p_currency
          AND to_currency   = 'KZT'
          AND CURRENT_TIMESTAMP BETWEEN valid_from AND valid_to
        ORDER BY valid_from DESC
        LIMIT 1;

        IF v_rate IS NULL THEN
            RAISE EXCEPTION 'No exchange rate for % to KZT', p_currency USING ERRCODE='A006';
        END IF;

        v_amount_kzt := p_amount * v_rate;
    END IF;

    -- daily limit (only if not ignored)
    IF NOT p_ignore_daily_limit THEN
        SELECT COALESCE(SUM(amount_kzt),0)
        INTO v_today_total
        FROM transactions
        WHERE from_account_id = v_from_id
          AND created_at::date = CURRENT_DATE;

        IF (v_today_total + v_amount_kzt) > v_daily_limit THEN
            INSERT INTO audit_log(table_name,record_id,action,new_values,changed_by)
            VALUES('customers',v_customer_id,'FAILED_LIMIT',
                   jsonb_build_object('today_total',v_today_total,'current',v_amount_kzt,'limit',v_daily_limit),
                   'process_transfer');
            RAISE EXCEPTION 'Daily limit exceeded' USING ERRCODE='A005';
        END IF;
    END IF;

    -- update balances
    UPDATE accounts
    SET balance = balance - p_amount
    WHERE account_id = v_from_id;

    UPDATE accounts
    SET balance = balance + p_amount
    WHERE account_id = v_to_id;

    -- insert transaction
    INSERT INTO transactions(
        from_account_id,to_account_id,
        amount,currency,exchange_rate,amount_kzt,
        type,status,description,completed_at)
    VALUES(
        v_from_id,v_to_id,
        p_amount,p_currency,v_rate,v_amount_kzt,
        'transfer','completed',p_descr,NOW()
    )
    RETURNING transaction_id INTO v_tx_id;

    INSERT INTO audit_log(table_name,record_id,action,old_values,new_values,changed_by)
    VALUES('transactions',v_tx_id,'INSERT',NULL,
           jsonb_build_object('transaction_id',v_tx_id,'from',v_from_id,'to',v_to_id,'amount',p_amount),
           'process_transfer');

    RETURN 'SUCCESS';
EXCEPTION WHEN OTHERS THEN
    INSERT INTO audit_log(table_name,action,new_values,changed_by)
    VALUES('transactions','EXCEPTION',
           jsonb_build_object('from',p_from_account,'to',p_to_account,'error',SQLERRM),
           'process_transfer');
    RAISE;
END;
$$;

-- ========= VIEWS =========

CREATE OR REPLACE VIEW customer_balance_summary AS
WITH conv AS (
    SELECT a.customer_id,
           a.account_id,
           a.balance *
           (CASE WHEN a.currency='KZT' THEN 1
                 ELSE (
                     SELECT rate
                     FROM exchange_rates r
                     WHERE r.from_currency = a.currency
                       AND r.to_currency   = 'KZT'
                       AND CURRENT_TIMESTAMP BETWEEN r.valid_from AND r.valid_to
                     ORDER BY r.valid_from DESC
                     LIMIT 1
                 )
            END) AS balance_kzt
    FROM accounts a
)
SELECT c.customer_id,
       c.full_name,
       SUM(conv.balance_kzt) AS total_kzt,
       CASE
           WHEN c.daily_limit_kzt > 0
               THEN (SUM(conv.balance_kzt)/c.daily_limit_kzt)*100
           ELSE NULL
       END AS limit_util_pct,
       RANK() OVER (ORDER BY SUM(conv.balance_kzt) DESC) AS rank_by_balance
FROM customers c
JOIN conv ON conv.customer_id = c.customer_id
GROUP BY c.customer_id,c.full_name,c.daily_limit_kzt;

CREATE OR REPLACE VIEW daily_transaction_report AS
WITH base AS (
    SELECT date(created_at) AS day,
           type,
           amount_kzt
    FROM transactions
)
SELECT day,
       type,
       COUNT(*) AS tx_count,
       SUM(amount_kzt) AS total_volume,
       AVG(amount_kzt) AS avg_amount,
       SUM(SUM(amount_kzt)) OVER(ORDER BY day) AS running_total,
       LAG(SUM(amount_kzt)) OVER(ORDER BY day) AS prev_day_total,
       CASE
           WHEN LAG(SUM(amount_kzt)) OVER(ORDER BY day) IS NULL
                OR LAG(SUM(amount_kzt)) OVER(ORDER BY day) = 0
                THEN NULL
           ELSE
               (SUM(amount_kzt) - LAG(SUM(amount_kzt)) OVER(ORDER BY day))
               / LAG(SUM(amount_kzt)) OVER(ORDER BY day) * 100
       END AS growth_pct
FROM base
GROUP BY day,type
ORDER BY day,type;

CREATE VIEW suspicious_activity_view
WITH (security_barrier = true) AS
SELECT t.*
FROM transactions t
WHERE t.amount_kzt > 5000000
   OR (
        SELECT COUNT(*)
        FROM transactions t2
        WHERE t2.from_account_id = t.from_account_id
          AND t2.created_at BETWEEN t.created_at - INTERVAL '1 hour'
                               AND t.created_at
      ) > 10
   OR EXISTS (
        SELECT 1
        FROM transactions t3
        WHERE t3.from_account_id = t.from_account_id
          AND t3.created_at > t.created_at - INTERVAL '1 minute'
          AND t3.created_at <= t.created_at
      );

-- ========= MATERIALIZED VIEW FOR SALARY BATCH SUMMARY =========

CREATE MATERIALIZED VIEW salary_batch_summary AS
SELECT
    date(created_at) AS pay_date,
    from_account_id  AS company_account_id,
    COUNT(*)         AS payments_count,
    SUM(amount_kzt)  AS total_amount_kzt
FROM transactions
WHERE description ILIKE 'salary%'
GROUP BY pay_date, company_account_id;

-- ========= FUNCTION: process_salary_batch =========

CREATE OR REPLACE FUNCTION process_salary_batch(
    p_company_account_number TEXT,
    p_payments JSONB           -- [{iin, amount, description}, ...]
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_company_id INT;
    v_company_balance NUMERIC;
    v_total_batch NUMERIC := 0;
    v_success INT := 0;
    v_failed  INT := 0;
    v_errors  JSONB := '[]'::jsonb;
    rec JSONB;
    v_target_acc TEXT;
    v_desc TEXT;
BEGIN
    -- advisory lock per company
    PERFORM pg_advisory_lock(hashtext(p_company_account_number));

    SELECT account_id, balance
    INTO v_company_id, v_company_balance
    FROM accounts
    WHERE account_number = p_company_account_number
      AND is_active = TRUE
    FOR UPDATE;

    IF NOT FOUND THEN
        PERFORM pg_advisory_unlock(hashtext(p_company_account_number));
        RAISE EXCEPTION 'Company account not found or inactive';
    END IF;

    -- total batch amount
    SELECT COALESCE(SUM( (elem->>'amount')::NUMERIC ),0)
    INTO v_total_batch
    FROM jsonb_array_elements(p_payments) AS t(elem);

    IF v_company_balance < v_total_batch THEN
        PERFORM pg_advisory_unlock(hashtext(p_company_account_number));
        RAISE EXCEPTION 'Insufficient funds on company account for full batch';
    END IF;

    -- process each payment with SAVEPOINT, bypassing daily limit
    FOR rec IN SELECT * FROM jsonb_array_elements(p_payments)
    LOOP
        SAVEPOINT sp_one_payment;
        BEGIN
            SELECT a.account_number
            INTO v_target_acc
            FROM accounts a
            JOIN customers c ON c.customer_id = a.customer_id
            WHERE c.iin = rec->>'iin'
              AND a.is_active = TRUE
            LIMIT 1;

            IF v_target_acc IS NULL THEN
                RAISE EXCEPTION 'No active account for IIN %', rec->>'iin';
            END IF;

            v_desc := COALESCE(rec->>'description','salary payment');
            IF v_desc NOT ILIKE 'salary%' THEN
                v_desc := 'salary ' || v_desc;
            END IF;

            PERFORM process_transfer(
                        p_company_account_number,
                        v_target_acc,
                        (rec->>'amount')::NUMERIC,
                        'KZT',
                        v_desc,
                        TRUE      -- ignore daily limit for salary
                   );

            v_success := v_success + 1;
        EXCEPTION WHEN OTHERS THEN
            v_failed := v_failed + 1;
            v_errors := v_errors || jsonb_build_object(
                                        'iin',   rec->>'iin',
                                        'error', SQLERRM
                                    );
            ROLLBACK TO SAVEPOINT sp_one_payment;
        END;
    END LOOP;

    PERFORM pg_advisory_unlock(hashtext(p_company_account_number));

    -- refresh salary summary
    REFRESH MATERIALIZED VIEW CONCURRENTLY salary_batch_summary;

    RETURN jsonb_build_object(
        'successful_count', v_success,
        'failed_count',     v_failed,
        'failed_details',   v_errors
    );
END;
$$;

