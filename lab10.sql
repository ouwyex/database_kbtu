CREATE TABLE IF NOT EXISTS accounts (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL UNIQUE,
  balance NUMERIC(10,2) DEFAULT 0.00
);

CREATE TABLE IF NOT EXISTS products (
  id SERIAL PRIMARY KEY,
  shop VARCHAR(100) NOT NULL,
  product VARCHAR(100) NOT NULL,
  price NUMERIC(10,2) NOT NULL
);

TRUNCATE accounts, products RESTART IDENTITY;

INSERT INTO accounts (name, balance) VALUES
 ('Alice', 1000.00),
 ('Bob', 500.00),
 ('Wally', 750.00);

INSERT INTO products (shop, product, price) VALUES
 ('Joe''s Shop', 'Coke', 2.50),
 ('Joe''s Shop', 'Pepsi', 3.00),
 ('Joe''s Shop', 'Fanta', 3.00);

BEGIN;
UPDATE accounts SET balance = balance - 100.00 WHERE name = 'Alice';
UPDATE accounts SET balance = balance + 100.00 WHERE name = 'Bob';
COMMIT;

BEGIN;
UPDATE accounts SET balance = balance - 500.00 WHERE name = 'Alice';
SELECT name, balance FROM accounts WHERE name = 'Alice';
ROLLBACK;
SELECT name, balance FROM accounts WHERE name = 'Alice';

BEGIN;
UPDATE accounts SET balance = balance - 100.00 WHERE name = 'Alice';
SAVEPOINT sp1;
UPDATE accounts SET balance = balance + 100.00 WHERE name = 'Bob';
ROLLBACK TO sp1;
UPDATE accounts SET balance = balance + 100.00 WHERE name = 'Wally';
COMMIT;

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT * FROM products WHERE shop = 'Joe''s Shop';
COMMIT;

BEGIN TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT * FROM products WHERE shop = 'Joe''s Shop';
COMMIT;

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT MAX(price) AS max_price, MIN(price) AS min_price FROM products WHERE shop = 'Joe''s Shop';
COMMIT;

INSERT INTO products (shop, product, price) VALUES ('Joe''s Shop', 'Sprite', 4.00);

DO $$
BEGIN
  IF EXISTS(SELECT 1 FROM accounts WHERE name = 'Bob') THEN
    PERFORM 1;
  END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION transfer_if_sufficient(p_from VARCHAR, p_to VARCHAR, p_amount NUMERIC)
RETURNS VOID AS $$
DECLARE
  v_balance NUMERIC;
BEGIN
  PERFORM pg_advisory_xact_lock(1);
  SELECT balance INTO v_balance FROM accounts WHERE name = p_from FOR UPDATE;
  IF v_balance IS NULL THEN
    RAISE EXCEPTION 'Account not found';
  END IF;
  IF v_balance < p_amount THEN
    RAISE EXCEPTION 'Insufficient funds';
  END IF;
  UPDATE accounts SET balance = balance - p_amount WHERE name = p_from;
  UPDATE accounts SET balance = balance + p_amount WHERE name = p_to;
END;
$$ LANGUAGE plpgsql;

BEGIN;
SELECT transfer_if_sufficient('Bob', 'Wally', 200.00);
COMMIT;

BEGIN;
INSERT INTO products (shop, product, price) VALUES ('New Shop', 'Gatorade', 2.80);
SAVEPOINT sp_ins;
UPDATE products SET price = 3.50 WHERE shop = 'New Shop' AND product = 'Gatorade';
SAVEPOINT sp_upd;
DELETE FROM products WHERE shop = 'New Shop' AND product = 'Gatorade';
ROLLBACK TO sp_ins;
COMMIT;

INSERT INTO accounts (name, balance) VALUES ('Shared', 100.00) ON CONFLICT (name) DO NOTHING;

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT balance FROM accounts WHERE name = 'Shared' FOR UPDATE;
UPDATE accounts SET balance = balance - 80.00 WHERE name = 'Shared' AND balance >= 80.00;
COMMIT;

BEGIN TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT balance FROM accounts WHERE name = 'Shared' FOR UPDATE;
UPDATE accounts SET balance = balance - 30.00 WHERE name = 'Shared' AND balance >= 30.00;
COMMIT;

TRUNCATE products;
INSERT INTO products (shop, product, price) VALUES ('S1','A',10.00),('S1','B',20.00);

BEGIN;
UPDATE products SET price = price + 100 WHERE product = 'A';
DELETE FROM products WHERE product = 'B';
COMMIT;

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT MAX(price) AS maxp, MIN(price) AS minp FROM products WHERE shop = 'S1';
COMMIT;
