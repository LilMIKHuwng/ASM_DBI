Create database Products

Use Products;

Create Table Customers(
	customers_id int identity(1,1) Primary Key not null,
	first_name varchar(255) not null,
	last_name varchar(255) not null,
	address varchar(255),
);

Create Table Customers_Phone(
	customer_id int foreign key references Customers(customers_id),
	phone_number varchar(255),
	Primary Key(customer_id, phone_number),
);

Create table Products(
	product_id int identity(1,1) Primary Key not null,
	product_name varchar(255) not null,
	description varchar(255) not null,
	price decimal(10,2) not null,
);

Create table Bills(
	order_id int identity(1,1) Primary Key not null,
	order_date date not null,
	total_amount decimal(10,2) not null,
	customer_id int foreign key references Customers(customers_id),
);

-- cho phép total_amount được null từ table Bills
ALTER TABLE Bills
ALTER COLUMN total_amount decimal(10,2) NULL;

Create table Warehouse(
	warehouse_id int identity(1,1) Primary Key not null,
	warehouse_name varchar(255) not null,
	address varchar(255) not null,
);

Create table Bills_Products(
	order_id int foreign key references Bills(order_id) not null,
	product_id int foreign key references Products(product_id) not null,
	warehouse_id int foreign key references Warehouse(warehouse_id) not null,
	quantity_buy int not null,
	price_buy decimal(10,2) not null,
	total_price decimal(10,2) NULL
	Primary Key(order_id, product_id, warehouse_id),
);

DROP TABLE Bills_Products;

Create table Warehouse_Products(
	warehouse_id int foreign key references Warehouse(warehouse_id) not null,
	product_id int foreign key references Products(product_id) not null,
	quantity_in_stock int not null,
	Primary Key(warehouse_id, product_id),
);

-- Tạo trigger sau (AFTER INSERT) cho bảng Bills_Products
CREATE TRIGGER CalculateTotalPrice
ON Bills_Products
AFTER INSERT, Update
AS
BEGIN
    UPDATE BP
    SET total_price = I.quantity_buy * I.price_buy
    FROM Bills_Products AS BP
    INNER JOIN inserted AS I ON BP.order_id = I.order_id AND BP.product_id = I.product_id
END;

DROP TRIGGER CalculateTotalPrice;

-- Tạo trigger sau (AFTER INSERT) cho bảng Bills_Products
CREATE TRIGGER UpdateBillsTotals
ON Bills_Products
AFTER INSERT, Update
AS
BEGIN
    -- Tạo một CTE để tính tổng total_price cho mỗi order_id
    WITH TotalPriceCTE AS (
        SELECT order_id, SUM(total_price) AS order_total
        FROM Bills_Products
        WHERE order_id IN (SELECT DISTINCT order_id FROM inserted)
        GROUP BY order_id
    )

    -- Cập nhật total_amount trong bảng Bills bằng giá trị từ CTE
    UPDATE B
    SET total_amount = TP.order_total
    FROM Bills AS B
    INNER JOIN TotalPriceCTE AS TP ON B.order_id = TP.order_id
END;

DROP TRIGGER UpdateBillsTotals;

-- Tạo trigger kiểm tra order_date
CREATE TRIGGER CheckOrderDate
ON Bills
After INSERT, UPDATE
AS
BEGIN
    DECLARE @CurrentDate DATE;
	DECLARE @insertDate DATE;
    SET @CurrentDate = GETDATE();
    
	select @insertDate = i.order_date
	from inserted i

    IF (@insertDate > @CurrentDate)
    BEGIN
        print('Order date is greater than the current date')
		Rollback transaction
    END
END;

-- Tạo trigger kiểm tra price_buy
CREATE TRIGGER CheckPriceBuy
ON Bills_Products
After INSERT, UPDATE
AS
BEGIN
	DECLARE @price int;
	DECLARE @price_buy int;
	DECLARE @product_id int;

	select @product_id = i.product_id,
		   @price_buy = i.price_buy
	from inserted i

	select @price = p.price
	from products p
	where p.product_id = @product_id

    IF ( @price_buy < @price)
    BEGIN
        print('Price buy is lower than price_product')
		Rollback transaction
    END
END;

-- Tạo trigger kiểm tra quantity_buy
CREATE TRIGGER CheckQuantityBuy
ON Bills_Products
After INSERT, UPDATE
AS
BEGIN
    DECLARE @quantity_in_stock int;
    DECLARE @quantity_buy int;
    DECLARE @product_id int;
    DECLARE @warehouse_id int;

    SELECT @product_id = i.product_id,
           @warehouse_id = i.warehouse_id,
           @quantity_buy = i.quantity_buy
    FROM inserted i;

    SELECT @quantity_in_stock = wp.quantity_in_stock
    FROM Warehouse_Products wp
    WHERE wp.product_id = @product_id AND wp.warehouse_id = @warehouse_id;

    IF (@quantity_buy > @quantity_in_stock)
    BEGIN
        print('Quantity buy is greater than quantity in stock')
        ROLLBACK TRANSACTION;
    END
END;

DROP TRIGGER CheckQuantityBuy;


INSERT INTO Customers (first_name, last_name, address) VALUES
('Lam', 'Hung', 'HCM'),
('Nguyen', 'Thang', 'HCM'),
('Vo', 'Nhan', 'DN');

-- tạo Procedure để insert cho Customers
CREATE PROCEDURE InsertCustomer
    @first_name VARCHAR(255),
    @last_name VARCHAR(255),
    @address VARCHAR(255)
AS
BEGIN
    INSERT INTO Customers (first_name, last_name, address) VALUES (@first_name, @last_name, @address);
END;

EXEC InsertCustomer 'Nguyen', 'Quan', 'HN';

INSERT INTO Customers_Phone (customer_id, phone_number) VALUES
(1, '0941616499'),
(1, '0343977279'),
(3, '0941782499'),
(2, '0941616499');

INSERT INTO Products(product_name, description, price) VALUES
('Sting', 'Drinks', 10000),
('Sandwich', 'Fast Foods', 15000),
('Breads', 'Foods', 3000),
('Milk Tea', 'Drinks', 30000);

INSERT INTO Products(product_name, description, price) VALUES
('Coka', 'Drinks', 10000);

INSERT INTO Warehouse ( warehouse_name, address) VALUES
( 'TD', 'HCM'),
('BT', 'HCM'),
('Q3', 'DN');

INSERT INTO Warehouse_Products(warehouse_id , product_id, quantity_in_stock) VALUES
( 1, 1 , 50),
( 1, 3 , 70),
( 2, 2 , 50),
( 2, 3 , 90),
( 3, 4 , 100),
( 3, 1 , 20);

-- Thêm dữ liệu vào bảng Bills, phải cung cấp giá trị total_amount ban đầu là 0
INSERT INTO Bills (order_date, total_amount, customer_id) VALUES
('2023-10-15', 0, 1),
('2023-10-16', 0, 2),
('2023-10-20', 0, 1),
('2023-10-14', 0, 3),
('2023-10-17', 0, 3);

-- Thêm dữ liệu vào bảng Bills_Products, không cần cung cấp giá trị cho total_price
INSERT INTO Bills_Products (order_id, product_id, quantity_buy, price_buy, warehouse_id) VALUES
(1, 1, 5, 12000, 1),
(1, 2, 3, 20000, 2),
(2, 3, 2, 5000, 2),
(3, 1, 4, 12000, 3),
(3, 2, 2, 20000, 2),
(4, 4, 5, 35000, 3),
(4, 2, 4, 20000, 2),
(5, 1, 4, 12000, 1),
(5, 4, 2, 35000, 3),
(3, 3, 1, 5000, 1);

-- All
Select * From Customers;
Select * From Customers_Phone;
Select * From Products;
Select * From Warehouse;
Select * From Warehouse_Products;
Select * From Bills;
Select * From Bills_Products;

-- Update 
UPDATE Products
SET product_name = 'Sting Energy Drink'
WHERE product_name = 'Sting';

UPDATE Warehouse_Products
SET quantity_in_stock = 120
WHERE warehouse_id = 1 AND product_id = 3;

-- Delete
delete from Products ;
	-- ALTER TABLE Products AUTO_INCREMENT = 1;
DBCC CHECKIDENT ('Products', RESEED, 0);

delete from Bills ;
DBCC CHECKIDENT ('Bills', RESEED, 0);

delete from Bills_Products;

delete from Warehouse_Products;

alter table Products
Drop PK__Products__47027DF598D9CAB6;

ALTER TABLE Customers
DROP COLUMN address;

-- Select
-- Lọc ra các sản phẩm có price < 20000
SELECT *
FROM Products
WHERE price < 20000;

-- Lọc ra các khách hàng đến từ HCM
SELECT *
FROM Customers
WHERE address = 'HCM';

-- count
-- Đếm số khách hàng đến từ các address khác nhau
Select Count(customers_id) As [Number of Country], address from Customers Group By address;

-- having 
-- Tìm các nơi có nhiều hơn 2 khách hàng
Select Count(customers_id) As [Number of Country], address from Customers Group By address having Count(customers_id)>=2;

-- top
-- chọn ra 2 khách hàng sắp xếp giảm dần theo id đứng đầu
Select  Top 2 * From Customers Order By customers_id desc;

-- inner join
-- Lọc thông tin về sản phẩm và số lượng sản phẩm có sẵn trong kho (Warehouse) với điều kiện kho có tên "BT"
SELECT P.product_name, P.description, W.address, WP.quantity_in_stock
FROM Products AS P
inner JOIN Warehouse_Products AS WP ON P.product_id = WP.product_id
inner JOIN Warehouse AS W ON WP.warehouse_id = W.warehouse_id
WHERE W.warehouse_name = 'BT';

-- Lọc ra sản phẩm và thông tin sản phẩm được mua bởi khách có 2 số cuối của sdt là 79
SELECT DISTINCT P.product_name, P.description
FROM Products AS P
inner JOIN Bills_Products AS BP ON P.product_id = BP.product_id
inner JOIN Bills AS B ON BP.order_id = B.order_id
inner JOIN Customers AS C ON B.customer_id = C.customers_id
inner JOIN Customers_Phone AS CP ON C.customers_id = CP.customer_id
WHERE RIGHT(CP.phone_number, 2) = '79';

-- Tính tổng tiền tất cả các hóa đơn mà các khách hàng đã mua
SELECT C.first_name, C.last_name, C.address, SUM(B.total_amount) AS total_spent
FROM Customers AS C
JOIN Bills AS B ON C.customers_id = B.customer_id
GROUP BY C.first_name, C.last_name, C.address;

-- sub query
-- Lọc ra các sản phẩm có giá lớn hơn giá TB của tất cả các sản phẩm
SELECT product_name, price
FROM Products
WHERE price > (SELECT AVG(price) FROM Products);

-- Lọc ra các khách hàng có total_amount lớn hơn 10000
SELECT first_name, last_name
FROM Customers
WHERE customers_id IN (
    SELECT customer_id
    FROM Bills
    WHERE total_amount > 10000
);

-- Lọc ra các sản phẩm có giá bán thấp hơn giá bán trung bình của sản phẩm có tên là 'Coka':
SELECT product_name, price
FROM Products
WHERE price < (SELECT AVG(price) FROM Products WHERE product_name = 'Coka');

-- Lọc ra các khách hàng có tổng giá trị hóa đơn (total_amount) lớn hơn tổng giá trị hóa đơn của khách hàng có tên 'Lam Hung':
SELECT first_name, last_name
FROM Customers
WHERE (SELECT SUM(total_amount) FROM Bills WHERE customer_id = Customers.customers_id) >
      (SELECT SUM(total_amount) FROM Bills WHERE customer_id = (SELECT customers_id FROM Customers WHERE first_name = 'Lam' AND last_name = 'Hung'));


-- self join
-- Chọn ra khách hàng có chung address khách hàng và khách hàng 1 phải có id nhỏ hơn id khách hàng 2 
SELECT C1.first_name AS customer1_first_name, C1.last_name AS customer1_last_name, 
       C2.first_name AS customer2_first_name, C2.last_name AS customer2_last_name
FROM Customers AS C1
INNER JOIN Customers AS C2 ON C1.address = C2.address
WHERE C1.customers_id < C2.customers_id;

-- left join
-- chọn ra tất cả sản phẩm và các kho đang chứa sản phẩm đó nếu sản phẩm chưa có kho chứa thì là null
SELECT P.product_name, WP.quantity_in_stock, WP.warehouse_id
FROM Products AS P
LEFT JOIN Warehouse_Products AS WP ON P.product_id = WP.product_id;

-- Function
-- tạo hàm tính tổng tiền tất cả các hóa đơn của 1 khách hàng
CREATE FUNCTION CalculateCustomerTotalAmount(@customer_id INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
    DECLARE @total DECIMAL(10,2);
    SELECT @total = SUM(total_amount)
    FROM Bills
    WHERE customer_id = @customer_id;
    RETURN @total;
END;

DROP FUNCTION CalculateCustomerTotalAmount;

Select dbo.CalculateCustomerTotalAmount(1) as total_amount_of_cusid;


-- tạo 1 hàm tạo ra 1 table tính tổng hết các hóa đơn của từng khách hàng
CREATE FUNCTION CalculateTotalSales()
RETURNS TABLE
AS
RETURN (
    SELECT C.customers_id, C.first_name, C.last_name, SUM(B.total_amount) AS total_sales
    FROM Customers AS C
    LEFT JOIN Bills AS B ON C.customers_id = B.customer_id
    GROUP BY C.customers_id, C.first_name, C.last_name
);

Select * from CalculateTotalSales();

-- tạo 1 hàm kiểm tra độ hài lòng của khách hàng thông qua tổng tiền các hóa đơn của khách hàng đó mua
CREATE FUNCTION CustomerSatisfaction(@customer_id INT)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @satisfaction VARCHAR(20);
    DECLARE @total DECIMAL(10,2);
    
    SELECT @total = SUM(total_amount)
    FROM Bills
    WHERE customer_id = @customer_id;
    
    SET @satisfaction = CASE
        WHEN @total < 30000 THEN 'Không hài lòng'
        WHEN @total >= 30000 AND @total < 150000 THEN 'Bình thường'
        WHEN @total >= 150000 AND @total < 300000 THEN 'Hài lòng'
        ELSE 'Rất hài lòng'
    END;
    
    RETURN @satisfaction;
END;

DROP FUNCTION CustomerSatisfaction;

Select dbo.CustomerSatisfaction(3) as CustomerSatisfaction;

-- tạo Procdure để xem total_price trong khoảng nào
CREATE PROCEDURE proc_list_price (
	@min_list_price AS Decimal
	,@max_list_price AS Decimal
)
AS
	BEGIN 
		SELECT 
		product_id , total_price
		FROM Bills_Products 
		WHERE total_price BETWEEN @min_list_price AND @max_list_price
		ORDER BY total_price
		END;

EXEC proc_list_price
	@min_list_price = 50000,
	@max_list_price = 300000;

-- Tạo  procedure InsertBillsAndProducts 
CREATE PROCEDURE InsertBillsAndProducts
    @order_date DATE,
    @customer_id INT,
	@order_id int,
    @product_id INT,
    @quantity_buy INT,
    @price_buy decimal(10,2),
	@warehouse_id int
	
AS
BEGIN 
 begin try
    BEGIN TRANSACTION

    -- Thêm dữ liệu vào bảng Bills
    INSERT INTO Bills (order_date, total_amount, customer_id) VALUES
    (@order_date, 0, @customer_id);

    -- Thêm dữ liệu vào bảng Bills_Products
    INSERT INTO Bills_Products (order_id, product_id, quantity_buy, price_buy, warehouse_id) VALUES
    (@order_id, @product_id, @quantity_buy, @price_buy, @warehouse_id);

    COMMIT;
	end try
	BEGIN CATCH
        -- Nếu xảy ra lỗi, hủy bỏ giao dịch và xử lý lỗi
        ROLLBACK;
        -- Xử lý lỗi tại đây hoặc ghi log lỗi
    END CATCH;
END;

drop procedure InsertBillsAndProducts;

Exec InsertBillsAndProducts @order_date = '2023-10-25', @customer_id = 3, @order_id = 4, @product_id = 1,
@quantity_buy = 30, @price_buy = 12000, @warehouse_id = 1; 

Select * From Bills;
Select * From Bills_Products;