SET timezone = 'America/Chicago';

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE suppliers (
    supplier_id BIGSERIAL PRIMARY KEY,
    supplier_name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE zip_codes (
    zip_code VARCHAR(10) PRIMARY KEY,
    city VARCHAR(70) NOT NULL,
    state VARCHAR(2) NOT NULL
);

CREATE TABLE customers (
    customer_id BIGSERIAL PRIMARY KEY,
    customer_name VARCHAR(80) UNIQUE NOT NULL,
    street_numb VARCHAR(12) NOT NULL,
    street_name VARCHAR(50) NOT NULL,
    zip_code VARCHAR(10) NOT NULL 
             REFERENCES zip_codes(zip_code)
);

CREATE TABLE manufacturers (
    manufacturer_id BIGSERIAL PRIMARY KEY,
    manufacturers VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE preferments (
    preferment_id BIGSERIAL PRIMARY KEY,
    preferment VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE ingredients (
    ingredient_id BIGSERIAL PRIMARY KEY,
    ingredient_name VARCHAR(80) NOT NULL,
    manufacturer_id BIGINT NOT NULL 
                    REFERENCES manufacturers(manufacturer_id),
    is_flour BOOLEAN NOT NULL
);

CREATE TABLE ingredient_suppliers (
    ingredient_supplier_id UUID PRIMARY KEY DEFAULT uuid_generate_v1(),
    ingredient_id BIGINT NOT NULL 
                  REFERENCES ingredients(ingredient_id),
    supplier_id BIGINT NOT NULL 
                REFERENCES suppliers(supplier_id),
    manufacturer_id BIGINT NOT NULL 
                    REFERENCES manufacturers(manufacturer_id),
    grams_per_unit NUMERIC (6, 1) NOT NULL,
    cost_per_unit NUMERIC (5, 2) NOT NULL
);

CREATE TABLE doughs (
    dough_id BIGSERIAL PRIMARY KEY,
    dough_name VARCHAR(70) UNIQUE NOT NULL,
    lead_time_days INTEGER NOT NULL
);

CREATE TABLE dough_preferments (
    dough_id INTEGER NOT NULL 
             REFERENCES doughs(dough_id),
    preferment_id INTEGER NOT NULL 
                  REFERENCES preferments(preferment_id),
    ingredient_id INTEGER NOT NULL 
                  REFERENCES ingredients(ingredient_id),
    percent_of_ingredient_total NUMERIC (4,2),
    PRIMARY KEY (dough_id, preferment_id, ingredient_id)
);

CREATE TABLE shapes (
    shape_id BIGSERIAL PRIMARY KEY,
    shape_name VARCHAR(70) UNIQUE NOT NULL
);

CREATE TABLE special_orders (
    special_order_id BIGSERIAL PRIMARY KEY,
    delivery_date DATE NOT NULL,
    customer_id INTEGER NOT NULL 
                REFERENCES customers(customer_id),
    dough_id INTEGER NOT NULL 
             REFERENCES doughs(dough_id),
    shape_id INTEGER NOT NULL 
             REFERENCES shapes(shape_id),
    amt INTEGER NOT NULL,
    order_created_at TIMESTAMPTZ DEFAULT now()
);

-- Doughs may be divided into multiple shapes with different weights
CREATE TABLE dough_shape_weights (
    dough_id BIGINT NOT NULL 
             REFERENCES doughs(dough_id),
    shape_id BIGINT NOT NULL 
             REFERENCES shapes(shape_id),
    dough_shape_grams INTEGER NOT NULL,
    PRIMARY KEY (dough_id, shape_id)
);

CREATE TABLE dough_ingredients (
    dough_id BIGINT NOT NULL REFERENCES doughs(dough_id),
    ingredient_id BIGINT NOT NULL REFERENCES ingredients(ingredient_id),
    bakers_percent NUMERIC (4, 1) NOT NULL,
    PRIMARY KEY (dough_id, ingredient_id)
);

CREATE TABLE dough_instructions (
    dough_instruction_id BIGSERIAL PRIMARY KEY,
    dough_id BIGINT NOT NULL REFERENCES doughs(dough_id),
    instructions VARCHAR(150) UNIQUE NOT NULL
);

CREATE OR REPLACE VIEW COGS AS
    SELECT i.ingredient_name AS ingredient, 
    ins.cost_per_unit * 1000 / ins.grams_per_unit AS "COGS/kg"
    FROM ingredients AS i
    JOIN ingredient_suppliers AS ins ON ins.ingredient_id = i.ingredient_id;


CREATE OR REPLACE VIEW bkrs_percent_sum AS SELECT sum(bakers_percent) / 100
    FROM dough_ingredients;

CREATE OR REPLACE VIEW quantity AS 
SELECT so.amt, d.dough_name, s.shape_name, dsw.dough_shape_grams AS grams
  FROM dough_shape_weights AS dsw
       JOIN doughs AS d
       ON d.dough_id = dsw.dough_id

       JOIN shapes AS s
       ON s.shape_id = dsw.shape_id

       JOIN special_orders as so
       ON so.dough_id = dsw.dough_id;

--query the bakers %, ingredient and grams for each item in this formula
CREATE OR REPLACE VIEW formula 
    AS SELECT d.dough_id, di.bakers_percent AS "bakers %", 
    i.ingredient_name as ingredient,
    ROUND((di.bakers_percent / 100) * (SELECT amt FROM quantity) 
    * dsw.dough_shape_grams / (SELECT * FROM bkrs_percent_sum))
    AS grams
    FROM doughs AS d
    JOIN dough_ingredients AS di ON di.dough_id = d.dough_id
    JOIN dough_shape_weights AS dsw ON dsw.dough_id = d.dough_id
    JOIN ingredients AS i ON i.ingredient_id = di.ingredient_id
    ORDER BY i.is_flour DESC, di.bakers_percent DESC;

--------------------------------------------------------------------------------

            --doughs
INSERT INTO doughs (dough_name, lead_time_days) 
     VALUES ('cranberry walnut Sourdough', 2),
            ('pizza dough', 1),
            ('rugbrod', 2),
            ('Kamut Sourdough', 2)
;

            --suppliers
INSERT INTO suppliers (supplier_name) 
     VALUES ('Madison Sourdough'),
            ('Meadlowlark Organics'),
            ('Woodmans'),
            ('Willy St Coop')
;

            --manufacturers
INSERT INTO manufacturers (manufacturers) 
     VALUES ('Madison Sourdough'),
            ('Meadlowlark Organics'),
            ('King Arthur'),
            ('Woodmans'),
            ('Redmond'),
            ('diy')
;

            --ingredients
INSERT INTO ingredients (ingredient_name, manufacturer_id, is_flour) 
     VALUES ('Bolted Red Fife Flour', 2, TRUE),
            ('Kamut Flour', 1, TRUE),
            ('Rye Flour', 1, TRUE),
            ('All Purpose Flour', 3, TRUE),
            ('Bread Flour', 3, TRUE),
            ('water', 4, FALSE),
            ('High Extraction Flour', 1, TRUE),
            ('Sea Salt', 5, FALSE),
            ('leaven', 6, FALSE)
;

            --shapes
INSERT INTO shapes (shape_name) 
     VALUES ('12" Boule'),
            ('4" pan loaves'),
            ('16" pizza')
;

            --dough_shape_weights
INSERT INTO dough_shape_weights (dough_id, shape_id, dough_shape_grams)
     VALUES (4, 1, 1600),
            (3, 2, 1280)
;

            --dough_ingredients
INSERT INTO dough_ingredients (dough_id, ingredient_id, bakers_percent) 
     VALUES (4, 2, 40),
            (4, 4, 30),
            (4, 7, 30),
            (4, 6, 80),
            (4, 8, 1.9)
;

            --dough_instructions
INSERT INTO dough_instructions (dough_id, instructions) 
     VALUES (4, 'bake at 450 with lid on for 30 min;
            410 lid off for 25 min'),
            (4, 'put cold sheet pan under dutch oven at half way point')
;

            --ingredient_suppliers
INSERT INTO ingredient_suppliers (ingredient_id, supplier_id, 
            manufacturer_id, grams_per_unit, cost_per_unit) 
     VALUES (6, 3, 4, 3785, .30),
            (1, 2, 2, 907, 5.50),
            (2, 1, 1, 907, 4.50),
            (3, 1, 1, 907, 4.50),
            (7, 1, 1, 907, 4.50),
            (4, 3, 3, 2268, 2.50),
            (5, 3, 3, 2268, 2.50),
            (8, 4, 5, 737, 2.50)
;

            --zip_codes
INSERT INTO zip_codes (zip_code, city, state) 
     VALUES (53705, 'Madison', 'WI'),
            (53703, 'Madison', 'WI')
;

            --customers
INSERT INTO customers (customer_name, street_numb, street_name, zip_code) 
     VALUES ('lohrentz', '2906', 'Barlow St', '53705')
;

            --special_orders
INSERT INTO special_orders (delivery_date, customer_id, dough_id, 
            shape_id, amt, order_created_at) 
     VALUES ((SELECT now()::date + interval '2 days'), 1, 4, 1, 1, 
            (SELECT now())),

            ((SELECT now()::date + interval '2 days'), 1, 3, 2, 1, 
            (SELECT now()))
;


            --preferments
INSERT INTO preferments (preferment) 
     VALUES ('sour'),
            ('poolish'),
            ('soaker')
;

            --dough_preferments
INSERT INTO dough_preferments (dough_id, preferment_id, ingredient_id, 
            percent_of_ingredient_total) 
     VALUES (4, 1, 4, 33 ),
            (4, 1, 7, 33 ),
            (4, 1, 6, 20 )
;
