-- 1.1
CREATE TABLE employees(
    employee_id SERIAL Primary KEY,
    first_name TEXT,
    last_name TEXT,
    age INT CHECK(age BETWEEN 18 and 65),
    salary numeric CHECK(salary>0)
);

INSERT INTO employees (first_name, last_name, age, salary)
VALUES ('John', 'Doe', 30, 3500),
       ('Anna', 'Smith', 50, 4200),
       ('ssss','wds',18,2000);

-- 1.2
CREATE TABLE products_catalog(
    product_id SERIAL PRIMARY KEY,
    product_name TEXT,
    regular_price NUMERIC,
    discount_price NUMERIC,
    CONSTRAINT valid_discount CHECK (
        regular_price > 0 AND discount_price > 0 and discount_price < regular_price
    )
);

INSERT into products_catalog(product_name, regular_price, discount_price)
VALUES ('Laptop', 1000,900),
       ('Phone', 800, 600);


-- 1.3
CREATE TABLE bookings(
    booking_id SERIAL PRIMARY KEY,
    check_in_date DATE,
    check_out_date date,
    num_guests INT,
    CHECK ( num_guests BETWEEN 1 and 10),
    CHECK ( check_out_date > check_in_date)
);

INSERT INTO bookings(check_in_date, check_out_date, num_guests)
VALUES('2025-05-01', '2025-05-05', 4),
      ('2025-06-10', '2025-06-15',2);

-- 2.1
CREATE TABLE customers(
    customer_id SERIAL NOT NULL PRIMARY KEY,
    email TEXT NOT NULL,
    phone TEXT,
    registration_date DATE NOT NULL
);

INSERT INTO customers(email, phone, registration_date)
VALUES ('a@gmail.com', '777123456', '2025-01-01'),
       ('b@gmail.com', NULL, '2025-02-02');

--2.2
CREATE TABLE inventory(
    item_id SERIAL PRIMARY KEY,
    item_name TEXT NOT NULL,
    quantity INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC NOT NULL CHECK (unit_price > 0),
    last_updated TIMESTAMP NOT NULL
);

INSERT INTO inventory (item_name, quantity, unit_price, last_updated)
VALUES ('Keyboard', 20,15.5, NOW()),
       ('Mouse', 40, 10.0, NOW());

-- 3.1 / 3.3
CREATE TABLE users(
  user_id SERIAL PRIMARY KEY,
  username TEXT,
  email TEXT,
  created_at TIMESTAMP,
  CONSTRAINT unique_username UNIQUE (username),
  CONSTRAINT unique_email UNIQUE (email)
);

INSERT INTO users (username, email, created_at)
VALUES ('johnny', 'johnny@mail.com', NOW()),
       ('maria', 'maria@mail.com', NOW());

-- 3.2
CREATE TABLE course_enrollments(
    enrollment_id SERIAL PRIMARY KEY,
    student_id INT,
    course_code TEXT,
    semester TEXT,
    CONSTRAINT unique_student_course UNIQUE (student_id, course_code, semester)
);

INSERT INTO course_enrollments (student_id, course_code, semester)
VALUES (1,'CS101', 'Fall2025'),
       (1,'CS102', 'Fall2025');

--4.1
CREATE TABLE departments (
    dept_id INT PRIMARY KEY,
    dept_name TEXT NOT NULL,
    location TEXT
);

INSERT INTO departments VALUES(1, 'HR', 'Astana'),
                              (2,'IT', 'Almaty'),
                              (3, 'Finance', 'Astana');

--4.2
CREATE TABLE student_courses(
    student_id INT,
    course_id INT,
    enrollment_date DATE,
    grade TEXT,
    primary key (student_id, course_id)
);

CREATE TABLE employees_dept (
    emp_id SERIAL PRIMARY KEY,
    emp_name TEXT NOT NULL,
    dept_id INT REFERENCES departments(dept_id),
    hire_date DATE
);

INSERT INTO employees_dept(emp_name, dept_id, hire_date)
values ('Alice', 1, '2025-01-01'),
       ('Bob', 2, '2025-02-01');

-- 5.2
create table authors(
  author_id SERIAl PRIMARY KEY ,
  author_name TEXT NOT NULL ,
  country TEXT
);

create table publishers(
  publisher_id SERIAL PRIMARY KEY,
  publisher_name TEXT NOT NULL,
  city TEXT
);

create table books(
  book_id SERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  author_id INT REFERENCES authors,
  publisher_id INT REFERENCES publishers,
  publication_year INT,
  isbn TEXT UNIQUE
);

INSERT INTO authors (author_name, country) VALUES ('J.K. Rowling', 'UK'), ('George Orwell', 'UK');
INSERT INTO publishers (publisher_name, city) VALUES ('Bloomsbury', 'London'), ('Secker & Warburg', 'London');
INSERT INTO books (title, author_id, publisher_id, publication_year, isbn)
VALUES ('Harry Potter', 1, 1, 1997, '9780747532743'),
       ('1984', 2, 2, 1949, '9780451524935');

--5.3
CREATE TABLE categories(
    category_id SERIAL PRIMARY KEY,
    category_name TEXT NOT NULL
);

CREATE TABLE products_fk(
    product_id SERIAL PRIMARY KEY ,
    product_name TEXT NOT NULL,
    category_id INT REFERENCES categories(category_id) ON DELETE RESTRICT
);
create table orders(
    order_id SERIAL PRIMARY KEY ,
    order_date DATE NOT NULL
);

CREATE TABLE order_items (
  item_id SERIAL PRIMARY KEY,
  order_id INT REFERENCES orders(order_id) ON DELETE CASCADE,
  product_id INT REFERENCES products_fk(product_id),
  quantity INT CHECK (quantity > 0)
);

INSERT INTO categories (category_name) VALUES ('Electronics');
INSERT INTO products_fk (product_name, category_id) VALUES ('Phone', 1);
INSERT INTO orders (order_date) VALUES ('2025-05-01');
INSERT INTO order_items (order_id, product_id, quantity) VALUES (1, 1, 2);

--6.1
CREATE TABLE customers_ecom(
    customer_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    registration_date DATE NOT NULL
);

create table products_ecom(
  product_id SERIAL PRIMARY KEY ,
  name TEXT NOT NULL,
  description text,
  price numeric check ( price >=  0 ),
  stock_quantity INT CHECK ( stock_quantity > 0 )
);

CREATE TABLE orders_ecom(
    order_id SERIAL PRIMARY KEY,
    customer_id int references customers_ecom(customer_id) on delete cascade,
    order_date DATE not null,
    total_amount numeric check ( total_amount>= 0 ),
    status text check ( status in ('pending','processing','delivered', 'cancelled'))
);

create table order_details(
    order_detail_id serial primary key,
    order_id int references orders_ecom(order_id) on DELETE CASCADE,
    product_id int references products_ecom(product_id),
    quantity Int check ( quantity>0 ),
    unit_price numeric check (unit_price > 0)
);

INSERT INTO customers_ecom (name, email, phone, registration_date)
VALUES ('Alice', 'alice@mail.com', '777123', '2025-01-01'),
       ('Bob', 'bob@mail.com', '777124', '2025-02-01'),
       ('Carol', 'carol@mail.com', '777125', '2025-03-01'),
       ('Dan', 'dan@mail.com', '777126', '2025-04-01'),
       ('Eve', 'eve@mail.com', '777127', '2025-05-01');

INSERT INTO products_ecom (name, description, price, stock_quantity)
VALUES ('Laptop', '15-inch laptop', 1200, 10),
       ('Phone', 'Smartphone', 700, 25),
       ('Headphones', 'Wireless', 150, 50),
       ('Monitor', '27-inch', 300, 15),
       ('Mouse', 'Wireless mouse', 25, 100);

INSERT INTO orders_ecom (customer_id, order_date, total_amount, status)
VALUES (1, '2025-06-01', 1500, 'pending'),
       (2, '2025-06-02', 700, 'shipped');

INSERT INTO order_details (order_id, product_id, quantity, unit_price)
VALUES (1, 1, 1, 1200),
       (1, 3, 2, 150),
       (2, 2, 1, 700);



