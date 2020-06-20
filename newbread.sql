\c postgres

DROP DATABASE IF EXISTS bread;

CREATE DATABASE bread;

\c bread

SET timezone = 'US/Central';

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pg_libphonenumber;

CREATE TABLE parties (
       party_id uuid default gen_random_uuid(),
       party_type text NOT NULL,
       party_name VARCHAR NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (party_id, party_type),
       CONSTRAINT party_type_i_or_o CHECK (party_type in ('i', 'o'))
);

--CREATE INDEX parties_idx On parties (party_name);
CREATE INDEX parties_party_name_trgm_idx ON parties 
 USING GIN (party_name gin_trgm_ops);

INSERT INTO parties (party_type, party_name)
VALUES 
       ('i', 'Blow'),
       ('i', 'Bar'),
       ('o', 'Madison Sourdough'),
       ('o', 'Meadowlark Organics'),
       ('o', 'Woodmans'),
       ('o', 'Willy St Coop'),
       ('o', 'Costco'),
       ('o', 'Kirkland'),
       ('o', 'King Arthur'),
       ('o', 'King Oscar'),
       ('o', 'Redmond'),
       ('o', 'LeSaffre'),
       ('o', 'Siggis'),
       ('o', 'Amazon'),
       ('o', 'Montana Flour & Grain'),
       ('o', 'New Glarus Brewery'),
       ('o', 'Eden'),
       ('o', 'Terrasoul'),
       ('o', '4th & Heart'),
       ('o', 'Ceylon Flavors'),
       ('o', 'Now'),
       ('o', 'Viva Naturals'),
       ('o', 'Red Boat'),
       ('o', 'Vitruvian'),
       ('o', 'OrgaNICK'),
       ('o', 'Willow Creek'),
       ('o', 'FGO'),
       ('o', 'The Spice Lab'),
       ('o', 'Penzeys'),
       ('o', 'Sassy Cow'),
       ('o', 'Rani Brands'),
       ('o', 'Dept of Revenue'),
       ('o', 'OFood'),
       ('o', 'Westside Farmers Market'),
       ('i', 'Latte')
;

-- For "persons", a subtype of parties
CREATE TABLE people_st (
       party_id uuid PRIMARY KEY,
       party_type text default 'i' NOT NULL,
       first_name VARCHAR NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       FOREIGN KEY (party_id, party_type) references parties (party_id, party_type),
       CONSTRAINT party_type_is_i check (party_type = 'i')) 
;

CREATE TABLE zip_codes (
       zip text PRIMARY KEY,
       city VARCHAR NOT NULL,
       state text NOT NULL,
       CONSTRAINT zip_length_5 CHECK (length(zip)=5),
       CONSTRAINT st_length_2 CHECK (length(state)=2)
);

-- For "staff, a subtype of people
CREATE TABLE staff_st (
       party_id uuid PRIMARY KEY,
       party_type text default 'i' NOT NULL,
       ssn text NOT NULL,
       hire_date DATE NOT NULL,
       is_active BOOLEAN NOT NULL,
       street_no VARCHAR NOT NULL,
       street VARCHAR NOT NULL,
       zip text NOT NULL REFERENCES zip_codes(zip),
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       FOREIGN KEY (party_id, party_type) references parties (party_id, party_type),
       FOREIGN KEY (party_id) references people_st (party_id),
       CONSTRAINT hire_date_after_1970 CHECK (hire_date > '1970-01-01'),
       CONSTRAINT hire_date_within_next_mon CHECK (hire_date < now()::date + interval '1 month'),
       CONSTRAINT ssn_length_11 CHECK (length(ssn)<=11),
       CONSTRAINT zip_length_5 CHECK (length(zip)=5),
       CONSTRAINT party_type_is_i check (party_type = 'i') 
);

-- For "organizations", a subtype of parties
CREATE TABLE organization_st (
       party_id uuid PRIMARY KEY,
       party_type text default 'o' check (party_type = 'o') NOT NULL,
       org_type text NOT NULL,
       CONSTRAINT check_org_in_list CHECK 
            (org_type in('b', 'c', 'n', 'g')),
            -- b = Business, c = coop, n = Nonprofit, g = Gov't
       FOREIGN KEY (party_id, party_type) references parties (party_id, party_type))
;

CREATE TABLE ein_numbs (
       ein VARCHAR NOT NULL PRIMARY KEY,
       party_id uuid,
       party_type text default 'o' check (party_type = 'o') NOT NULL,
       FOREIGN KEY (party_id, party_type) references parties (party_id, party_type))
;

CREATE TABLE phones (
       party_id uuid,
       phone_type text not null default 'm' check 
            (phone_type in ('w', 'h', 'f', 'b', 'm', 'e')),
            -- work, home, fax, business, mobile, emergency
       phone_no VARCHAR UNIQUE NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       primary key (party_id, phone_type)
);

CREATE TABLE emails (
       party_id uuid NOT NULL,
       email_type text not null default 'p',
            -- work, business, personal
       email VARCHAR UNIQUE NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (party_id, email_type),
       CONSTRAINT email_type_from_list check 
            (email_type in ('w', 'b', 'p'))
);

CREATE TABLE ingredients (
       ingredient_id uuid PRIMARY KEY default gen_random_uuid(),
       ingredient_name VARCHAR NOT NULL,
       is_flour BOOLEAN NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX ingredients_ingredient_name_trgm_idx ON ingredients
 USING GIN (ingredient_name gin_trgm_ops);
--CREATE INDEX ingredients_idx On ingredients (ingredient_name);

CREATE TABLE ingredient_costs (
       ingredient_id uuid NOT NULL REFERENCES ingredients (ingredient_id),
       maker_id uuid NOT NULL, 
       mio text NOT NULL check (mio in ('i', 'o')),
       seller_id uuid NOT NULL, 
       sio text NOT NULL check (sio in ('i', 'o')),
       cost numeric(10,5) NOT NULL,
       grams numeric NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (ingredient_id, maker_id, seller_id),
       FOREIGN KEY (maker_id, mio) REFERENCES parties (party_id, party_type),
       FOREIGN KEY (seller_id, sio) REFERENCES parties (party_id, party_type)
);


CREATE TABLE cost_change_log (
       ingredient_id uuid NOT NULL REFERENCES ingredients (ingredient_id),
       maker_id uuid NOT NULL, 
       mio text NOT NULL check (mio in ('i', 'o')),
       seller_id uuid NOT NULL, 
       sio text NOT NULL check (sio in ('i', 'o')),
       old_cost numeric(10,5) NOT NULL,
       new_cost numeric(10,5) NOT NULL,
       old_grams numeric NOT NULL,
       new_grams numeric NOT NULL,
       change_time TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (ingredient_id, maker_id, seller_id, change_time),
       FOREIGN KEY (maker_id, mio) REFERENCES parties (party_id, party_type),
       FOREIGN KEY (seller_id, sio) REFERENCES parties (party_id, party_type)
);


CREATE OR REPLACE FUNCTION record_if_cost_changed()
       RETURNS trigger AS
    $$
    BEGIN
          IF NEW.cost <> OLD.cost OR NEW.grams <> OLD.grams THEN
            INSERT INTO cost_change_log (
            ingredient_id,
            maker_id,
            mio,
            seller_id,
            sio,
            old_cost,
            new_cost,
            old_grams,
            new_grams,
            change_time)
        VALUES (
            OLD.ingredient_id,
            OLD.maker_id,
            OLD.mio,
            OLD.seller_id,
            OLD.sio,
            OLD.cost,
            NEW.cost,
            OLD.grams,
            NEW.grams,
            now()
        );
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;


CREATE TRIGGER cost_update
       AFTER UPDATE
          on ingredient_costs
       FOR EACH ROW
       EXECUTE PROCEDURE record_if_cost_changed();


CREATE TABLE products (
       product_id uuid PRIMARY KEY default gen_random_uuid(),
       product_name VARCHAR UNIQUE NOT NULL,
       lead_time_days INTEGER NOT NULL,
       is_dough BOOLEAN NOT NULL,
       CONSTRAINT lead_time_not_negative CHECK (lead_time_days >= 0),
       CONSTRAINT lead_time_less_than_8 CHECK (lead_time_days < 8)
);

CREATE INDEX products_product_name_trgm_idx ON products
 USING GIN (product_name gin_trgm_ops);

CREATE TABLE product_instructions (
       product_id uuid NOT NULL REFERENCES products(product_id),
       sequence integer NOT NULL,
       directions text NOT NULL,
       CONSTRAINT sequence_positive CHECK (sequence >= 0)
);

CREATE TABLE shapes (
       shape_id uuid PRIMARY KEY default gen_random_uuid(),
       shape_name VARCHAR UNIQUE NOT NULL
);

-- products may be divided into multiple shapes with different weights
CREATE TABLE product_shapes (
       product_id uuid NOT NULL REFERENCES products(product_id),
       shape_id uuid NOT NULL REFERENCES shapes(shape_id),
       grams INTEGER NOT NULL,
       CONSTRAINT grams_greater_than_0 CHECK (grams > 0),
       CONSTRAINT grams_less_than_3000 CHECK (grams < 3000),
       PRIMARY KEY (product_id, shape_id)
);

CREATE TABLE product_ingredients (
       product_id uuid NOT NULL REFERENCES products(product_id),
       ingredient_id uuid NOT NULL REFERENCES ingredients(ingredient_id),
       bakers_percent NUMERIC (5, 2) NOT NULL,
       percent_in_sour NUMERIC DEFAULT 0 NOT NULL,
       percent_in_poolish NUMERIC (5, 2) DEFAULT 0 NOT NULL,
       percent_in_soaker NUMERIC DEFAULT 0 NOT NULL,
       created TIMESTAMPTZ DEFAULT now() NOT NULL,
       modified TIMESTAMPTZ DEFAULT now() NOT NULL,
       PRIMARY KEY (product_id, ingredient_id),
       CONSTRAINT bp_positive CHECK (bakers_percent > 0),
       CONSTRAINT percent_in_sour_positive CHECK (percent_in_sour >= 0),
       CONSTRAINT percent_in_sour_max_100 CHECK (percent_in_sour <= 100),
       CONSTRAINT percent_in_poolish_positive CHECK (percent_in_poolish >= 0),
       CONSTRAINT percent_in_poolish_max_100 CHECK (percent_in_poolish <= 100),
       CONSTRAINT percent_in_soaker_positive CHECK (percent_in_soaker >= 0),
       CONSTRAINT percent_in_soaker_max_100 CHECK (percent_in_soaker <= 100)
);


CREATE TABLE product_ingredients_changes (
       product_id uuid NOT NULL REFERENCES products(product_id),
       old_ingredient_id uuid NOT NULL REFERENCES ingredients(ingredient_id),
       new_ingredient_id uuid NOT NULL REFERENCES ingredients(ingredient_id),
       old_bakers_percent NUMERIC (5, 2) NOT NULL,
       new_bakers_percent NUMERIC (5, 2) NOT NULL,
       percent_in_sour NUMERIC NOT NULL,
       percent_in_poolish NUMERIC (5, 2) NOT NULL,
       percent_in_soaker NUMERIC NOT NULL,
       created TIMESTAMPTZ DEFAULT now() NOT NULL,
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (product_id, new_ingredient_id, created),
       CONSTRAINT bp_positive CHECK (new_bakers_percent > 0),
       CONSTRAINT percent_in_sour_positive CHECK (percent_in_sour >= 0),
       CONSTRAINT percent_in_sour_max_100 CHECK (percent_in_sour <= 100),
       CONSTRAINT percent_in_poolish_positive CHECK (percent_in_poolish >= 0),
       CONSTRAINT percent_in_poolish_max_100 CHECK (percent_in_poolish <= 100),
       CONSTRAINT percent_in_soaker_positive CHECK (percent_in_soaker >= 0),
       CONSTRAINT percent_in_soaker_max_100 CHECK (percent_in_soaker <= 100)
);


CREATE OR REPLACE FUNCTION record_if_di_changed()
       RETURNS trigger AS
    $$
    BEGIN
          IF NEW.ingredient_id <> OLD.ingredient_id OR 
             NEW.bakers_percent <> OLD.bakers_percent THEN
            INSERT INTO product_ingredients_changes (
            product_id,
            old_ingredient_id,
            new_ingredient_id,
            old_bakers_percent,
            new_bakers_percent,
            percent_in_sour,
            percent_in_poolish,
            percent_in_soaker,
            modified)
        VALUES (
            OLD.product_id,
            OLD.ingredient_id,
            NEW.ingredient_id,
            OLD.bakers_percent,
            NEW.bakers_percent,
            OLD.percent_in_sour,
            OLD.percent_in_poolish,
            OLD.percent_in_soaker,
            now()
        );
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;


CREATE TRIGGER di_update
       AFTER UPDATE
          on product_ingredients
       FOR EACH ROW
       EXECUTE PROCEDURE record_if_di_changed();

CREATE TABLE dough_mods (                                                 
       mod_name VARCHAR NOT NULL, 
       product_id uuid NOT NULL REFERENCES products(product_id),
       ingredient_id uuid NOT NULL REFERENCES ingredients(ingredient_id),
       bakers_percent NUMERIC (5, 2) NOT NULL,
       percent_in_sour NUMERIC NOT NULL,
       percent_in_poolish NUMERIC (5, 2)NOT NULL,
       percent_in_soaker NUMERIC NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (mod_name, product_id, ingredient_id),
       CONSTRAINT bp_positive CHECK (bakers_percent > 0),
       CONSTRAINT percent_in_sour_positive CHECK (percent_in_sour >= 0),
       CONSTRAINT percent_in_sour_max_100 CHECK (percent_in_sour <= 100),
       CONSTRAINT percent_in_poolish_positive CHECK (percent_in_poolish >= 0),
       CONSTRAINT percent_in_poolish_max_100 CHECK (percent_in_poolish <= 100),
       CONSTRAINT percent_in_soaker_positive CHECK (percent_in_soaker >= 0),
       CONSTRAINT percent_in_soaker_max_100 CHECK (percent_in_soaker <= 100)
);

CREATE TABLE special_orders (
       delivery_date DATE NOT NULL,
       customer_id uuid NOT NULL,
       io text NOT NULL,
       product_id uuid NOT NULL REFERENCES products(product_id),
       shape_id uuid NOT NULL REFERENCES shapes(shape_id),
       amt INTEGER NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (delivery_date, customer_id, product_id, shape_id, created),
       FOREIGN KEY (customer_id, io) references parties (party_id, party_type),
       CONSTRAINT io_i_or_o CHECK (io in ('i', 'o')),
       CONSTRAINT delivery_date_present_or_future CHECK (delivery_date >= now()::date),
       CONSTRAINT delivery_date_in_next_6_mons CHECK (delivery_date < now()::date + interval '6 months'),
       CONSTRAINT amt_greater_than_0 CHECK (amt > 0)
);

CREATE TABLE days_of_week (
       dow_id SMALLINT PRIMARY KEY,
       dow_names text UNIQUE NOT NULL,
       CONSTRAINT dow_id_between_0_and_6 check (dow_id >= 0 AND dow_id <= 6),
       CONSTRAINT dow_names_3_letter_abr check (dow_names in ('Mon', 'Tue',
                 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')
));

CREATE TABLE standing_orders (
       day_of_week SMALLINT NOT NULL REFERENCES days_of_week(dow_id),
       customer_id uuid NOT NULL,
       io text NOT NULL,
       product_id uuid NOT NULL REFERENCES products(product_id),
       shape_id uuid NOT NULL REFERENCES shapes(shape_id),
       amt INTEGER NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (day_of_week, customer_id, product_id, shape_id),
       FOREIGN KEY (customer_id, io) 
                    references parties (party_id, party_type),
       CONSTRAINT dow_in_0_thru_6 check (day_of_week IN (0, 1, 2, 3, 4, 5, 6)),
       CONSTRAINT io_i_or_o CHECK (io in ('i', 'o')),
       CONSTRAINT amt_greater_than_0 CHECK (amt > 0)
);


CREATE TABLE standing_change_log (
       old_day_of_week SMALLINT NOT NULL REFERENCES days_of_week(dow_id),
       new_day_of_week SMALLINT NOT NULL REFERENCES days_of_week(dow_id),
       customer_id uuid NOT NULL,
       io text NOT NULL,
       product_id uuid NOT NULL REFERENCES products(product_id),
       shape_id uuid NOT NULL REFERENCES shapes(shape_id),
       old_amt INTEGER NOT NULL,
       new_amt INTEGER NOT NULL,
       change_time TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (new_day_of_week, customer_id, product_id, shape_id, change_time),
       FOREIGN KEY (customer_id, io) 
                    references parties (party_id, party_type),
       CONSTRAINT dow_in_0_thru_6 check (new_day_of_week IN (0, 1, 2, 3, 4, 5, 6)),
       CONSTRAINT io_i_or_o CHECK (io in ('i', 'o'))
);

CREATE OR REPLACE FUNCTION record_if_amt_changed()
       RETURNS trigger AS
    $$
    BEGIN
          IF NEW.amt <> OLD.amt OR NEW.day_of_week <> OLD.day_of_week THEN
            INSERT INTO standing_change_log (
            old_day_of_week,
            new_day_of_week,
            customer_id,
            io,
            product_id,
            shape_id,
            old_amt,
            new_amt,
            change_time)
        VALUES (
            OLD.day_of_week,
            NEW.day_of_week,
            OLD.customer_id,
            OLD.io,
            OLD.product_id,
            OLD.shape_id,
            OLD.amt,
            NEW.amt,
            now()
        );
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

CREATE TRIGGER amt_update
       AFTER UPDATE
          on standing_orders
       FOR EACH ROW
       EXECUTE PROCEDURE record_if_amt_changed();

  --make temporary changes to standing orders
CREATE TABLE tmp_chng (
       day_of_week SMALLINT NOT NULL,
       customer_id uuid NOT NULL,
       product_id uuid NOT NULL REFERENCES products(product_id),
       shape_id uuid NOT NULL REFERENCES shapes(shape_id),
       start_date DATE NOT NULL,
       resume_date DATE,
       --percent * 100 (to be multiplied by standing order amount during tmp change period)
       percent_multiplier numeric(4,1) NOT NULL,
       created TIMESTAMPTZ DEFAULT now(),
       modified TIMESTAMPTZ DEFAULT now(),
       PRIMARY KEY (day_of_week, customer_id, product_id, shape_id, start_date),
       FOREIGN KEY (day_of_week, customer_id, product_id, shape_id)
               REFERENCES standing_orders (day_of_week, customer_id, product_id, shape_id),
       CONSTRAINT dow_in_0_thru_6 check (day_of_week IN (0, 1, 2, 3, 4, 5, 6)),
       CONSTRAINT start_date_in_next_6_mos CHECK (start_date >= now()::date AND 
                  start_date < now()::date + interval '6 months'),
       CONSTRAINT resume_in_next_6_mos CHECK (resume_date >= now()::date 
                  AND resume_date < now()::date + interval '6 months'),
       CONSTRAINT resume_after_start CHECK (resume_date > start_date),
       CONSTRAINT multiplier_not_negative CHECK (percent_multiplier >=0)
);


CREATE OR REPLACE VIEW phone_book AS 
WITH typology (party_id, phone_type_abbr, type) AS
     (SELECT party_id, phone_type,  
        CASE WHEN phone_type = 'w' THEN 'work'
             WHEN phone_type = 'h' THEN 'home'
             WHEN phone_type = 'f' THEN 'fax'
             WHEN phone_type = 'b' THEN 'business'
             WHEN phone_type = 'm' THEN 'mobile'
             WHEN phone_type = 'e' THEN 'emergency'
        END
     FROM phones),

name_join (party_id, new_name) AS
     (SELECT p.party_id, 
       CASE WHEN pe.party_type = 'i' THEN pe.first_name || ' ' || p.party_name
       ELSE p.party_name
       END 
     FROM parties AS p
     FULL JOIN people_st as pe on p.party_id = pe.party_id)


SELECT ph.party_id, nm.new_name AS name, p.party_type, t.type, ph.phone_no
  FROM phones AS ph
  JOIN name_join as nm on ph.party_id = nm.party_id
  JOIN typology AS t ON ph.party_id = t.party_id AND ph.phone_type = t.phone_type_abbr
  JOIN parties AS p on ph.party_id = p.party_id
  LEFT JOIN people_st AS pe ON ph.party_id = pe.party_id
 ORDER BY ph.party_id, t.type;


CREATE OR REPLACE VIEW staff_phones AS
WITH mob_ph (
    party_id, name, party_type, type, phone_no)
AS (
    SELECT * FROM phone_book
    WHERE type = 'mobile'
)

SELECT COALESCE (ph.name, pe.first_name) AS name, 
       s.hire_date, s.is_active, COALESCE (ph.phone_no, 'none') AS mobile
FROM staff_st as s
LEFT JOIN mob_ph as ph on s.party_id = ph.party_id
JOIN people_st AS pe on s.party_id = pe.party_id;


CREATE OR REPLACE VIEW email_list AS
  WITH et (party_id, type_code, type) AS
     (SELECT party_id, email_type,  
        CASE WHEN email_type = 'w' THEN 'work'
             WHEN email_type = 'b' THEN 'business'
             WHEN email_type = 'p' THEN 'personal'
        END
     FROM emails),

name_join (party_id, new_name) AS
     (SELECT p.party_id, 
       CASE WHEN pe.party_type = 'i' THEN pe.first_name || ' ' || p.party_name
       ELSE p.party_name
       END 
     FROM parties AS p
     FULL JOIN people_st as pe on p.party_id = pe.party_id)

SELECT e.party_id, nm.new_name AS name, et.type, e.email 
  FROM emails AS e
  JOIN name_join as nm on e.party_id = nm.party_id
  JOIN et ON e.party_id = et.party_id AND e.email_type = et.type_code
  JOIN parties AS p on e.party_id = p.party_id
  LEFT JOIN people_st as pe ON e.party_id = pe.party_id;


CREATE OR REPLACE VIEW staff_list AS 
SELECT DISTINCT s.party_id, pe.first_name, p.party_name AS last_name, 
       s.ssn, s.is_active, s.hire_date, s.street_no, s.street, 
       z.city, z.state, s.zip, ph.phone_no AS mobile
FROM staff_st AS s
JOIN people_st AS pe on s.party_id = pe.party_id
JOIN parties AS p on s.party_id = p.party_id AND s.party_type = p.party_type
FULL JOIN phone_book as ph ON s.party_id = ph.party_id
JOIN zip_codes AS z on s.zip = z.zip;

CREATE OR REPLACE VIEW people_list AS
SELECT pe.party_id, pe.first_name, p.party_name AS last_name
  FROM people_st AS pe
  JOIN parties AS p ON pe.party_id = p.party_id
;

CREATE OR REPLACE VIEW shape_list AS 
SELECT pr.product_name AS product, s.shape_name AS shape, 
       ps.grams
  FROM product_shapes as ps
  JOIN products AS pr on ps.product_id = pr.product_id
  Join shapes as s on ps.shape_id = s.shape_id;


CREATE OR REPLACE VIEW ein_list AS 
SELECT p.party_name as name, ei.ein FROM ein_numbs AS ei 
  JOIN parties AS p on ei.party_id = p.party_id 
       AND ei.party_type = p.party_type;


CREATE OR REPLACE VIEW todays_orders AS 
SELECT pr.product_id, p.party_name AS customer, so.delivery_date, 
       pr.lead_time_days AS lead_time, so.amt, 
       pr.product_name, s.shape_name, ps.grams AS grams
    
  FROM product_shapes AS ps 
  JOIN products AS pr ON pr.product_id = ps.product_id
  JOIN shapes AS s ON s.shape_id = ps.shape_id
  JOIN special_orders as so ON so.product_id = ps.product_id
       AND s.shape_id = so.shape_id
  JOIN parties AS p on so.customer_id = p.party_id 
       AND so.io = p.party_type
 WHERE now()::date + pr.lead_time_days = so.delivery_date;


CREATE OR REPLACE VIEW todays_adjusted_so AS
WITH
   current_so_changes (dow, cid, prid, sid, pm)
  AS
(
    SELECT tc.day_of_week, tc.customer_id, tc.product_id, tc.shape_id, tc.percent_multiplier
    FROM tmp_chng AS tc
    JOIN products as pr ON tc.product_id = pr.product_id
    WHERE tc.start_date - pr.lead_time_days <= TIMESTAMP 'now()'::date
          AND tc.resume_date - pr.lead_time_days > TIMESTAMP 'now()'::date
)

SELECT so.day_of_week as dow, so.customer_id as cid, so.product_id as prid, pr.product_name, so.shape_id as sid,
       COALESCE(round(so.amt * csc.pm / 100, 0), so.amt) AS amt, ps.grams as grams
  FROM standing_orders as so
  LEFT JOIN current_so_changes as csc
       ON so.day_of_week = csc.dow AND so.customer_id = csc.cid
       AND so.product_id = csc.prid AND so.shape_id = csc.sid
  JOIN products as pr on so.product_id = pr.product_id
  JOIN product_shapes as ps ON so.product_id = ps.product_id AND so.shape_id = ps.shape_id
 WHERE 
       so.day_of_week = (SELECT EXTRACT(DOW FROM TIMESTAMP 'now()')) + pr.lead_time_days 
       OR
       so.day_of_week + 7 = (SELECT EXTRACT(DOW FROM TIMESTAMP 'now()')) + pr.lead_time_days
;

--used by get_batch_weight function, which is called by formula function
CREATE OR REPLACE VIEW todays_combined_spec_standing AS
WITH
    spec (dow, cid, prid, product_name, sid, amt, grams)
AS
    (
SELECT date_part('dow', so.delivery_date), so.customer_id, so.product_id, pr.product_name,
       so.shape_id, so.amt, ps.grams
  FROM special_orders AS so
  JOIN product_shapes as ps ON so.product_id = ps.product_id AND so.shape_id = ps.shape_id
  JOIN products as pr ON so.product_id = pr.product_id
 WHERE now()::date + pr.lead_time_days = so.delivery_date
   )

SELECT dow, cid, prid, product_name, 
       sid, amt, grams
  FROM todays_adjusted_so
 UNION ALL
SELECT dow, cid, prid, product_name, sid, amt, grams
  FROM spec
;

CREATE OR REPLACE FUNCTION
get_batch_weight(which_dough VARCHAR)
RETURNS numeric AS
'SELECT (SELECT COALESCE (sum(amt * grams), 0)
   FROM todays_combined_spec_standing
  WHERE LOWER(product_name) LIKE LOWER(which_dough))
;'
LANGUAGE SQL
IMMUTABLE
RETURNS NULL ON NULL INPUT;

CREATE OR REPLACE VIEW product_info AS 
SELECT di.product_id, pr.product_name, di.bakers_percent, i.ingredient_name AS ingredient, 
       i.is_flour, di.percent_in_sour, di.percent_in_poolish, di.percent_in_soaker
  FROM product_ingredients AS di
  JOIN ingredients AS i ON di.ingredient_id = i.ingredient_id
  JOIN products as pr on di.product_id = pr.product_id
 ORDER BY di.product_id, i.is_flour DESC, di.bakers_percent DESC;


CREATE OR REPLACE VIEW standing_change_history AS
SELECT p.party_name, pr.product_name, s.shape_name, dw.dow_names AS day_of_week,
       sc.old_amt, sc.new_amt, sc.change_time
  FROM standing_change_log as sc
  JOIN parties as p on sc.customer_id = p.party_id AND sc.io = p.party_type
  JOIN products as pr ON sc.product_id = pr.product_id
  JOIN shapes AS s on sc.shape_id = s.shape_id
  JOIN days_of_week AS dw on sc.old_day_of_week = dw.dow_id;


CREATE OR REPLACE VIEW cost_change_list AS
SELECT p.party_name as maker, i.ingredient_name as item, ROUND(cc.old_cost, 2) AS old_cost, 
       ROUND(cc.new_cost, 2) AS new_cost, ROUND(cc.old_cost / cc.old_grams, 5) AS old_cost_per_g, 
       ROUND(cc.new_cost / cc.new_grams, 5) as new_cost_per_g, cc.new_grams, cc.change_time
  FROM cost_change_log as cc
  JOIN ingredients as i on cc.ingredient_id = i.ingredient_id
  JOIN parties as p on cc.maker_id = p.party_id
 WHERE maker_id = p.party_id;


CREATE OR REPLACE VIEW cost_list AS
SELECT i.ingredient_id, i.ingredient_name, ROUND(ic.cost, 2) AS cost, ic.grams, 
       ROUND(ic.cost / ic.grams, 5) AS cost_per_g 
  FROM ingredient_costs AS ic
  JOIN ingredients as i on ic.ingredient_id = i.ingredient_id;


CREATE OR REPLACE VIEW total_bp AS
SELECT DISTINCT product_name, sum(bakers_percent) OVER 
       (partition by product_name) AS total_bp
  FROM product_info;

--called by formula function
CREATE OR REPLACE FUNCTION bak_per(which_doe VARCHAR)
  returns numeric AS
          'SELECT DISTINCT sum(bakers_percent) OVER (PARTITION BY product_id)
          FROM product_info WHERE LOWER(product_name) LIKE LOWER(which_doe);'
 LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION pid(p_name VARCHAR)
  returns uuid AS
          'SELECT party_id FROM parties
          WHERE LOWER(party_name) LIKE LOWER(p_name);'
 LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION prid(d_name VARCHAR)
  returns uuid AS
          'SELECT product_id FROM products
          WHERE LOWER(product_name) LIKE LOWER(d_name);'
 LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION iid(i_name VARCHAR)
  returns uuid AS
          'SELECT ingredient_id FROM ingredients
          WHERE LOWER(ingredient_name) LIKE LOWER(i_name);'
 LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


CREATE OR REPLACE FUNCTION sid(s_name VARCHAR)
  returns uuid AS
          'SELECT shape_id FROM shapes
          WHERE LOWER(shape_name) LIKE LOWER(s_name);'
 LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


--usage: SELECT bak_per2('kam%', 'cran%');
CREATE OR REPLACE FUNCTION bak_per2(which_doe VARCHAR, mod VARCHAR)
  returns numeric AS

          'SELECT (SELECT SUM(dm.bakers_percent) 
           FROM dough_mods AS dm
           JOIN products as pr on dm.product_id = pr.product_id
           WHERE LOWER(pr.product_name) LIKE LOWER(which_doe)) +
           (SELECT SUM(di.bakers_percent)
           FROM product_ingredients AS di
           JOIN products as pr on di.product_id = pr.product_id
           WHERE LOWER(pr.product_name) LIKE LOWER(which_doe)
           AND di.ingredient_id NOT IN (SELECT ingredient_id 
           FROM dough_mods AS dm
           JOIN products as pr on dm.product_id = pr.product_id
           WHERE LOWER(pr.product_name) LIKE LOWER(which_doe) 
           AND LOWER(mod_name) LIKE LOWER(mod)));'

LANGUAGE SQL
IMMUTABLE
  RETURNS NULL ON NULL INPUT;


--formula function usage: 

--formula with sour and soaker:
         --SELECT "%", ingredient, overall, sour, soaker, final FROM formula('kam%');
--formula with poolish:
         --SELECT "%", ingredient, overall, poolish, final FROM formula('pizza');
--recipe with no preferments
         --SELECT product, "%", ingredient, overall as grams FROM formula('cao%');
--sum of the product cost
         --SELECT sum(cost) FROM formula('rug%');
--cost per gram
         --SELECT sum(overall) AS grams, sum(cost) AS cost, ROUND(sum(cost) / sum(overall),4) AS cost_per_gram FROM formula('rug%');

CREATE OR REPLACE FUNCTION formula(my_product VARCHAR)
       RETURNS TABLE (product character varying, "%" numeric, ingredient character varying,
       overall numeric, sour numeric, poolish numeric, soaker numeric, final numeric, cost numeric) AS $$
       BEGIN
             RETURN QUERY
                    SELECT din.product_name, din.bakers_percent, din.ingredient,
                    ROUND(get_batch_weight(my_product) * din.bakers_percent /
                          bak_per(my_product), 0),
                    ROUND(get_batch_weight(my_product) * din.bakers_percent /
                          bak_per(my_product) * din.percent_in_sour /100, 0),
                    ROUND(get_batch_weight(my_product) * din.bakers_percent /
                          bak_per(my_product) * din.percent_in_poolish /100, 1),
                    ROUND(get_batch_weight(my_product) * din.bakers_percent /
                          bak_per(my_product) * din.percent_in_soaker /100, 0),
                    ROUND(get_batch_weight(my_product) * din.bakers_percent /
                          bak_per(my_product) * (1- (din.percent_in_sour + 
                          din.percent_in_poolish + din.percent_in_soaker)/100), 0),
                    ROUND(get_batch_weight(my_product) * din.bakers_percent /
                          bak_per(my_product), 0) * cl.cost_per_g AS cost
                    FROM product_info AS din
                    JOIN cost_list as cl on din.ingredient = cl.ingredient_name
                    WHERE LOWER(din.product_name) LIKE LOWER(my_product);
      END;
$$ LANGUAGE plpgsql;

--useage: SELECT * FROM modded_formula('Kam%', 'cran%');
CREATE OR REPLACE FUNCTION modded_formula(get_dough VARCHAR, get_mod VARCHAR)
       RETURNS TABLE (dough character varying, "%" numeric, ingredient character varying,
       overall numeric, sour numeric, poolish numeric, soaker numeric, final numeric) AS $$
       BEGIN
             RETURN QUERY
            WITH dmu (
                product_name, product_id, ingredient_id, ingredient_name, is_flour, bakers_percent,
                percent_in_sour, percent_in_poolish, percent_in_soaker
                ) AS 
            (SELECT pr.product_name, dm.product_id, dm.ingredient_id, i.ingredient_name, i.is_flour, dm.bakers_percent, 
            dm.percent_in_sour, dm.percent_in_poolish, dm.percent_in_soaker
FROM dough_mods as dm 
JOIN ingredients as i on dm.ingredient_id = i.ingredient_id
JOIN products as pr on dm.product_id = pr.product_id
     WHERE LOWER(dm.mod_name) LIKE LOWER(get_mod) AND LOWER(pr.product_name) LIKE LOWER(get_dough)
     UNION ALL
SELECT pr.product_name, di.product_id, di.ingredient_id, i.ingredient_name, i.is_flour, di.bakers_percent, 
             di.percent_in_sour, di.percent_in_poolish, di.percent_in_soaker
FROM product_ingredients as di 
JOIN ingredients as i on di.ingredient_id = i.ingredient_id
JOIN products as pr on di.product_id = pr.product_id
WHERE LOWER(pr.product_name) LIKE LOWER(get_dough)
AND di.ingredient_id NOT IN (SELECT ingredient_id FROM dough_mods)
ORDER BY is_flour DESC, bakers_percent DESC)

                    SELECT product_name, bakers_percent, ingredient_name,
                    ROUND(get_batch_weight(get_dough) * bakers_percent /
                          bak_per2(get_dough, get_mod), 0),
                    ROUND(get_batch_weight(get_dough) * bakers_percent /
                          bak_per2(get_dough, get_mod) * percent_in_sour /100, 0),
                    ROUND(get_batch_weight(get_dough) * bakers_percent /
                          bak_per2(get_dough, get_mod) * percent_in_poolish /100, 1),
                    ROUND(get_batch_weight(get_dough) * bakers_percent /
                          bak_per2(get_dough, get_mod) * percent_in_soaker /100, 0),
                    ROUND(get_batch_weight(get_dough) * bakers_percent /
                          bak_per2(get_dough, get_mod) * (1- (percent_in_sour + 
                          percent_in_poolish + percent_in_soaker)/100), 0)
                    FROM dmu
                    WHERE LOWER(product_name) LIKE LOWER(get_dough)
                    ;
      END;
$$ LANGUAGE plpgsql;


       --Useage: SELECT * FROM phone_search('mad%');
CREATE OR REPLACE FUNCTION phone_search(name_snippet VARCHAR)
       RETURNS TABLE (name VARCHAR, phone_type text, phone_no VARCHAR) AS $$
       BEGIN
              RETURN QUERY
                 SELECT pb.name, pb.type, pb.phone_no
                 FROM phone_book AS pb
                 WHERE LOWER(pb.name) LIKE LOWER(name_snippet);
       END;
$$ LANGUAGE plpgsql;

--function for triggers to update any column named 'modified'
CREATE OR REPLACE FUNCTION update_modified_column() 
RETURNS TRIGGER AS $$
BEGIN
        NEW.modified = now();
            RETURN NEW; 
END;
$$ language 'plpgsql';

CREATE TRIGGER update_parties_modtime BEFORE UPDATE ON parties 
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_people_modtime BEFORE UPDATE ON people_st
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_phones_modtime BEFORE UPDATE ON phones
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_ingredients_modtime BEFORE UPDATE ON ingredients
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_ingredient_costs_modtime BEFORE UPDATE ON ingredient_costs
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_d_ingredients_modtime BEFORE UPDATE ON product_ingredients
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_dough_mods_modtime BEFORE UPDATE ON dough_mods
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_spec_orders_modtime BEFORE UPDATE ON special_orders
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_tmp_chng_modtime BEFORE UPDATE ON tmp_chng
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

CREATE TRIGGER update_stand_orders_modtime BEFORE UPDATE ON standing_orders
   FOR EACH ROW EXECUTE PROCEDURE update_modified_column();

--Insert data to test code

INSERT INTO zip_codes (zip, city, state)
VALUES (53705, 'Madison', 'WI'),
       (53703, 'Madison', 'WI'),
       (53562, 'Middleton', 'WI')
;

INSERT INTO phones (party_id, phone_type, phone_no)
VALUES 
       (pid('Blow'), 'm', '555-1212'),
       (pid('Blow'), 'w', '608-555-0000'),
       (pid('Madison Sourdough'), 'b', '608-442-8009'),
       (pid('Woodmans'), 'b', '608-555-1111'),
       (pid('Bar'), 'm', '608-555-2222'),
       (pid('Meadowlark Organics'), 'b', '608-555-3333'),
       (pid('Bar'), 'e', '608-555-1234'),
       (pid('Willy St Coop'), 'f', '608-000-0000')
;

INSERT INTO people_st (party_id, first_name)
VALUES ((SELECT party_id FROM parties WHERE party_name = 'Blow' AND now() - modified < interval '10 sec'), 'Joe'),
       ((SELECT party_id FROM parties WHERE party_name = 'Bar' AND now() - modified < interval '10 sec'), 'Foo'),
       ((SELECT party_id FROM parties WHERE party_name = 'Latte' AND now() - modified < interval '10 sec'), 'Moka-Choka')
;

            --shapes
INSERT INTO shapes (shape_name)
VALUES 
       ('12" boule'),
       ('walter 25'),
       ('16" pizza'),
       ('baguette'),
       ('truffle'),
       ('100 grams'),
       ('7" pita'),
       ('hard rolls')
;

            --products
INSERT INTO products (product_name, lead_time_days, is_dough)
     VALUES
            ('cranberry walnut', 2, TRUE),
            ('pizza dough', 1, TRUE),
            ('five day', 5, TRUE),
            ('goji almond nyt', 2, TRUE),
            ('rugbrod', 2, TRUE),
            ('yeastie nuts', 0, FALSE),
            ('cao cao truffles', 0, FALSE),
            ('kamut sourdough', 2, TRUE),
            ('leverpostej', 0, False),
            ('pita bread', 1, TRUE)
;


INSERT INTO product_instructions (product_id, sequence, directions)
     VALUES
            (prid('leverpostej'), 0, 'have butcher grind liver and bacon/pork fat'),
            (prid('leverpostej'), 1, 'weigh dry spices in mixing bowl'),
            (prid('leverpostej'), 2, 'weigh milk, eggs, flour and whisk well'),
            (prid('leverpostej'), 3, 'melt ghee & process in food processor with onions, shrooms, anchovies, hot sauce, ginger/garlic'),
            (prid('leverpostej'), 4, 'coat baking pan with butter, then shake flour all the way around on all inside surfaces'),
            (prid('leverpostej'), 5, 'gently fold all ingredients in large bowl, do not over-mix; pour into buttered/floured pan'),
            (prid('leverpostej'), 6, 'bake in bain-marie at 350 F until internal temp is 176 F'),
            (prid('leverpostej'), 7, 'if setting up in smoker, preheat on stove; in smoker--lid off dutch oven, add smoke wood'),
            (prid('leverpostej'), 8, 'Place in an ice water bath for 45 minutes, then cover with wrap and chill in frig'),
            (prid('cao%'), 1, 'grind spices in spice grinder'),
            (prid('cao%'), 2, 'grind spices in juicer'),
            (prid('cao%'), 3, 'add salt to nuts'),
            (prid('cao%'), 4, 'grind nuts/salt/spices in juicer twice'),
            (prid('cao%'), 5, 'alternate fruit with nut mixture in grinder'),
            (prid('cao%'), 6, 'repeat previous step'),
            (prid('cao%'), 7, 'alternate cao cao with nut/fruit mixter SLOWLY little at a time'),
            (prid('cao%'), 8, 'repeat previous step'),
            (prid('cao%'), 9, 'melt ghee/coconut oil, add monk fruit, one drop per truffle, and add to dries'),
            (prid('cao%'), 10, 'form into balls and place on silpat and freeze for 30 min'),
            (prid('cao%'), 11, 'wrap in wax paper')
;

--ingredients (use lower case)
INSERT INTO ingredients (ingredient_name, is_flour)
     VALUES 
            ('bolted red fife flour', TRUE),
            ('kamut flour', TRUE),
            ('kamut berries', TRUE),
            ('sprouted kamut berries', TRUE),
            ('rye flour', TRUE),
            ('all purpose flour', TRUE),
            ('bread flour', TRUE),
            ('water', FALSE),
            ('high extraction flour', TRUE),
            ('sea salt', FALSE),
            ('leaven', FALSE),
            ('saf-instant yeast', FALSE),
            ('dried cranberries', FALSE),
            ('walnuts', FALSE),
            ('almonds', FALSE),
            ('cashews', FALSE),
            ('pistachios', FALSE),
            ('turkey red flour', TRUE),
            ('filmjolk', FALSE),
            ('barley malt syrup', FALSE),
            ('sprouted rye berries', FALSE),
            ('sprouted spelt berries', FALSE),
            ('whole flax seeds', FALSE),
            ('ground flax seeds', FALSE),
            ('sesame seeds', FALSE),
            ('sunflower seeds', FALSE),
            ('black sesame seeds', FALSE),
            ('kefir whey', FALSE),
            ('chia seeds', FALSE),
            ('goji berries', FALSE),
            ('dates', FALSE),
            ('cardamom', FALSE),
            ('smoked paprika', FALSE),
            ('turmeric', FALSE),
            ('ceylon cinnamon', FALSE),
            ('nutmeg', FALSE),
            ('monk fruit extract', FALSE),
            ('red boat salt', FALSE),
            ('anchovies', FALSE),
            ('coconut oil', FALSE),
            ('ghee', FALSE),
            ('liver', FALSE),
            ('heavy cream', FALSE),
            ('whole milk', FALSE),
            ('bacon', FALSE),
            ('eggs', FALSE),
            ('mushrooms', FALSE),
            ('onions', FALSE),
            ('fermented ginger/garlic', FALSE),
            ('fermented hot sauce', FALSE),
            ('black pepper', FALSE),
            ('nutritional yeast', FALSE),
            ('raw cao cao powder', FALSE),
            ('anchovy sauce', FALSE),
            ('pumpkin seeds', FALSE)
;

            --ingredient_costs
INSERT INTO ingredient_costs (ingredient_id, maker_id, mio, seller_id, sio, cost, grams)
     VALUES 
            (iid('bolted red fife flour'), pid('Meadowlark%'), 'o', pid('Meadowlark%'), 'o', 7.00, 907),
            (iid('kamut flour'), pid('Madison Sourdough'), 'o', pid('Madison Sourdough'), 'o', 5.20, 907),
            (iid('kamut berries'), pid('Montana F%'), 'o', pid('Montana F%'), 'o', 29.15, 4536),
            (iid('sprouted kamut berries'), pid('Montana F%'), 'o', pid('Montana F%'), 'o', 29.15, 4536),
            (iid('rye flour'), pid('Madison Sourdough'), 'o', pid('Madison Sourdough'), 'o', 5.20, 907),
            (iid('all purpose flour'), pid('King Arthur'), 'o', pid('Woodmans'), 'o', 2.20, 907),
            (iid('bread flour'), pid('King Arthur'), 'o', pid('Woodmans'), 'o', 2.20, 907),
            (iid('water'), pid('Woodmans'), 'o', pid('Woodmans'), 'o', .55, 3785),
            (iid('kefir whey'), pid('Sassy Cow'), 'o', pid('Woodmans'), 'o', 7.00, 3900),
            (iid('high extraction flour'), pid('Madison Sour%'), 'o', pid('Madison Sour%'), 'o', 5.20, 907),
            (iid('sea salt'), pid('Redmond'), 'o', pid('Willy St%'), 'o', 1.25, 450),
            (iid('leaven'), pid('Blow'), 'i', pid('Blow'), 'i', .75, 300),
            (iid('saf-instant yeast'), pid('LeSaffre'), 'o', pid('Willy St Coop'), 'o', 2.50, 450),
            (iid('dried cranberries'), pid('Willy St Coop'), 'o', pid('Willy St Coop'), 'o', 7.50, 450),
            (iid('walnuts'), pid('Willy St Coop'), 'o', pid('Willy St Coop'), 'o', 7.50, 450),
            (iid('almonds'), pid('Kirkland'), 'o', pid('Costco'), 'o', 10, 1360),
            (iid('pistachios'), pid('Kirkland'), 'o', pid('Costco'), 'o', 10, 1360),
            (iid('cashews'), pid('Kirkland'), 'o', pid('Costco'), 'o', 16.99, 1135),
            (iid('turkey red flour'), pid('Meadowlark%'), 'o', pid('Meadowlark%'), 'o', 7.00, 907),
            (iid('filmjolk'), pid('Siggis'), 'o', pid('Woodmans'), 'o', 4.00, 2000),
            (iid('barley malt syrup'), pid('Eden'), 'o', pid('Willy St Coop'), 'o', 4.00, 566),
            (iid('sprouted rye berries'), pid('Blow'), 'i', pid('Blow'), 'i', 1.50, 450),
            (iid('sprouted spelt berries'), pid('Blow'), 'i', pid('Blow'), 'i', 1.50, 450),
            (iid('whole flax seeds'), pid('Willy St Coop'), 'o', pid('Willy St Coop'), 'o', 3.00, 450),
            (iid('ground flax seeds'), pid('Willy St Coop'), 'o', pid('Willy St Coop'), 'o', 3.00, 450),
            (iid('sesame seeds'), pid('Willy St Coop'), 'o', pid('Willy St Coop'), 'o', 3.50, 450),
            (iid('black sesame seeds'), pid('Terrasoul'), 'o', pid('Amazon'), 'o', 12.95, 907),
            (iid('sunflower seeds'), pid('Terrasoul'), 'o', pid('Amazon'), 'o', 10.95, 907),
            (iid('chia seeds'), pid('Terrasoul'), 'o', pid('Amazon'), 'o', 10.75, 1134),
            (iid('anchovies'), pid('King Oscar'), 'o', pid('Amazon'), 'o', 12.30, 224),
            (iid('goji berries'), pid('Terrasoul'), 'o', pid('Amazon'), 'o', 13.85, 454),
            (iid('dates'), pid('Terrasoul'), 'o', pid('Amazon'), 'o', 14.95, 907),
            (iid('nutritional yeast'), pid('Terrasoul'), 'o', pid('Amazon'), 'o', 8.43, 170),
            (iid('raw cao cao powder'), pid('Terrasoul'), 'o', pid('Amazon'), 'o', 19.99, 1362),
            (iid('coconut oil'), pid('Viva Naturals'), 'o', pid('Amazon'), 'o', 13.22, 473),
            (iid('ghee'), pid('4th & Heart'), 'o', pid('Amazon'), 'o', 17.11, 454),
            (iid('cardamom'), pid('Rani Brands'), 'o', pid('Amazon'), 'o', 13.99, 100),
            (iid('red boat salt'), pid('Red Boat'), 'o', pid('Amazon'), 'o', 19.95, 250),
            (iid('monk fruit extract'), pid('Now'), 'o', pid('Amazon'), 'o', 11.43, 59),
            (iid('ceylon cinnamon'), pid('Ceylon Flavors'), 'o', pid('Amazon'), 'o', 10.99, 99),
            (iid('nutmeg'), pid('Ceylon Flavors'), 'o', pid('Amazon'), 'o', 6.95, 100),
            (iid('turmeric'), pid('FGO'), 'o', pid('Amazon'), 'o', 8.99, 226),
            (iid('smoked paprika'), pid('The Spice Lab'), 'o', pid('Amazon'), 'o', 8.95, 130),
            (iid('liver'), pid('Woodmans'), 'o', pid('Woodmans'), 'o', 5.00, 454),
            (iid('heavy cream'), pid('Sassy%'), 'o', pid('Woodmans'), 'o', 4.50, 454),
            (iid('whole milk'), pid('Sassy%'), 'o', pid('Woodmans'), 'o', 4.00, 1950),
            (iid('bacon'), pid('Willow C%'), 'o', pid('Vitruvian'), 'o', 11.00, 454),
            (iid('eggs'), pid('OrgaNICK%'), 'o', pid('Vitruvian'), 'o', 4.00, 600),
            (iid('mushrooms'), pid('Vitruvian%'), 'o', pid('Vitruvian'), 'o', 10.00, 454),
            (iid('onions'), pid('Woodmans%'), 'o', pid('Woodmans'), 'o', 2.00, 454),
            (iid('fermented ginger/garlic'), pid('Blow'), 'i', pid('Blow'), 'i', 2.00, 454),
            (iid('fermented hot sauce'), pid('Blow'), 'i', pid('Blow'), 'i', 2.00, 454),
            (iid('black pepper'), pid('Penzeys'), 'o', pid('Penzeys'), 'o', 8.69, 94),
            (iid('anchovy sauce'), pid('OFood'), 'o', pid('Amazon'), 'o', 14.38, 1000),
            (iid('pumpkin seeds'), pid('Terrasoul'), 'o', pid('Amazon'), 'o', 13.75, 907)
;

INSERT INTO staff_st (party_id, party_type, ssn, is_active, hire_date,
       street_no, street, zip)
VALUES (pid('Blow'), 'i', '123-45-6789', TRUE, '2019-10-01', '2906', 'Barlow St', 53705),
       (pid('Bar'), 'i', '121-21-2121', FALSE, '2017-12-30', '924', 'Williamson St', 53703),
       (pid('Latte'), 'i', '123-45-6666', TRUE, '2019-12-07', '2906', 'Barlow St', 53705)
;

INSERT INTO organization_st (party_id, party_type, org_type)
VALUES (pid('Madison Sourdough'), 'o', 'b'),
       (pid('Meadowlark Organics'), 'o', 'b'),
       (pid('Woodmans'), 'o', 'b'),
       (pid('Willy St Coop'), 'o', 'c'),
       (pid('King Arthur'), 'o', 'b'),
       (pid('Dept of Revenue'), 'o', 'g'),
       (pid('Westside Farmers Market'), 'o', 'n'),
       (pid('Siggis'), 'o', 'b'),
       (pid('Eden'), 'o', 'b'),
       (pid('Redmond'), 'o', 'b'),
       (pid('LeSaffre'), 'o', 'b')
;

INSERT INTO ein_numbs (party_id, party_type, ein)
VALUES (pid('Madison Sourdough'), 'o', '01-23456789'),
       (pid('Meadowlark Organics'), 'o', '11-11111111')
;

INSERT INTO emails (party_id, email_type, email)
VALUES (pid('Blow'), 'p', 'bubba@gmail.com'),
       (pid('Dept of Revenue'), 'w', 'punkinhead_sucks@traitors.com')
;


            --product_shapes (use lower case)
INSERT INTO product_shapes (product_id, shape_id, grams)
     VALUES (prid('kamut sourdough'), sid('12" boule'), 1600),
            (prid('rugbrod'), sid('walter 25'), 1150),
            (prid('pita bread'), sid('7" pita'), 105),
            (prid('goji almond nyt'), sid('12" boule'), 1600),
            (prid('five%'), sid('12" boule'), 1600),
            (prid('cao cao%'), sid('truffle'), 24),
            (prid('yeastie%'), sid('100 g%'), 100),
            (prid('cranberry walnut'), sid('12" boule'), 1600),
            (prid('cranberry walnut'), sid('hard rolls'), 120),
            (prid('leverpostej'), sid('walter 25'), 1255),
            (prid('pizza dough'), sid('16" pizza'), 400)
;
            
           --product_ingredients(use lower case)products without preferments
INSERT INTO product_ingredients (product_id, ingredient_id, bakers_percent)
     VALUES (prid('cao%'), iid('raw cao cao powder'), 100),
            (prid('cao%'), iid('ghee'), 33.35),
            (prid('cao%'), iid('coconut oil'), 33.35),
            (prid('cao%'), iid('dates'), 65),
            (prid('cao%'), iid('almonds'), 13.74),
            (prid('cao%'), iid('pumpkin seeds'), 26.43),
            (prid('cao%'), iid('pistachios'), 26.43),
            (prid('cao%'), iid('goji berries'), 13.3),
            (prid('cao%'), iid('ceylon cinnamon'), 2.7),
            (prid('cao%'), iid('sea salt'), 1.3),
            (prid('cao%'), iid('red boat salt'), 1.3),
            (prid('cao%'), iid('cardamom'), 0.67),
            (prid('cao%'), iid('monk fruit extract'), 0.43),
            (prid('yeastie%'), iid('almonds'), 100),
            (prid('yeastie%'), iid('cashews'), 100),
            (prid('yeastie%'), iid('coconut oil'), 77.8),
            (prid('yeastie%'), iid('goji%'), 69.4),
            (prid('yeastie%'), iid('nutritional%'), 45),
            (prid('yeastie%'), iid('smoked paprika'), 2),
            (prid('yeastie%'), iid('turmeric'), 2),
            (prid('yeastie%'), iid('sea salt'), 2),
            (prid('leverpostej'), iid('liver'), 100),
            (prid('leverpostej'), iid('onions'), 19),
            (prid('leverpostej'), iid('mushrooms'), 19),
            (prid('leverpostej'), iid('ghee'), 19),
            (prid('leverpostej'), iid('eggs'), 22),
            (prid('leverpostej'), iid('bacon'), 40),
            (prid('leverpostej'), iid('whole milk'), 32),
            (prid('leverpostej'), iid('kamut flour'), 12.7),
            (prid('leverpostej'), iid('red boat salt'), 1.5),
            (prid('leverpostej'), iid('smoked paprika'), 0.8),
            (prid('leverpostej'), iid('black pepper'), 0.3),
            (prid('leverpostej'), iid('nutmeg'), 0.2),
            (prid('leverpostej'), iid('anchovies'), 6.0),
            (prid('leverpostej'), iid('fermented hot sauce'), 2.0),
            (prid('leverpostej'), iid('fermented ginger/garlic'), 1.5)
;

            --product_ingredients(use lower case)
INSERT INTO product_ingredients (product_id, ingredient_id, bakers_percent,
            percent_in_sour, percent_in_poolish, percent_in_soaker)
     VALUES (prid('kamut sourdough'), iid('kamut flour'), 60, 0, 0, 20),
            (prid('kamut sourdough'), iid('high extraction flour'), 40, 33, 0, 20),
            (prid('kamut sourdough'), iid('sprouted kamut berries'), 25, 0, 0, 0),
            (prid('kamut sourdough'), iid('water'), 80, 20, 0, 18),
            (prid('kamut sourdough'), iid('sea salt'), 2.2, 0, 0, 0),
            (prid('cranberry walnut'), iid('kamut flour'), 40, 0, 0, 20),
            (prid('cranberry walnut'), iid('all purpose flour'), 20, 36, 0, 0),
            (prid('cranberry walnut'), iid('high extraction flour'), 40, 36, 0, 20),
            (prid('cranberry walnut'), iid('water'), 70, 22, 0, 18),
            (prid('cranberry walnut'), iid('sea salt'), 2.0, 0, 0, 0),
            (prid('cranberry walnut'), iid('dried cranberries'), 25, 0, 0, 0),
            (prid('cranberry walnut'), iid('walnuts'), 25, 0, 0, 0),
            (prid('goji almond nyt'), iid('kamut flour'), 45, 0, 0, 40),
            (prid('goji almond nyt'), iid('sprouted kamut berries'), 25, 0, 0, 0),
            (prid('goji almond nyt'), iid('rye flour'), 10, 0, 0, 0),
            (prid('goji almond nyt'), iid('high extraction flour'), 45, 12, 0, 28),
            (prid('goji almond nyt'), iid('water'), 75, 5.4, 0, 30.6),
            (prid('goji almond nyt'), iid('sea salt'), 2.0, 0, 0, 0),
            (prid('goji almond nyt'), iid('goji berries'), 25, 0, 0, 0),
            (prid('goji almond nyt'), iid('almonds'), 25, 0, 0, 0),
            (prid('pita bread'), iid('bolted red fife flour'), 50, 0, 0, 0),
            (prid('pita bread'), iid('all purpose flour'), 50, 5.4, 0, 0),
            (prid('pita bread'), iid('water'), 64, 2.4, 0, 0),
            (prid('pita bread'), iid('sea salt'), 1.9, 0, 0, 0),
            (prid('pizza dough'), iid('bread flour'), 30, 0, 25, 0),
            (prid('pizza dough'), iid('kamut flour'), 40, 0, 0, 0),
            (prid('pizza dough'), iid('high extraction flour'), 30, 0, 0, 0),
            (prid('pizza dough'), iid('water'), 68, 0, 20, 0),
            (prid('pizza dough'), iid('sea salt'), 1.9, 0, 0, 0),
            (prid('pizza dough'), iid('saf-instant yeast'), .05, 0, 100, 0),
            (prid('rugbrod'), iid('rye flour'), 100, 27.3, 0, 0),
            (prid('rugbrod'), iid('water'), 100, 45, 0, 18),
            (prid('rugbrod'), iid('sunflower seeds'), 7.3, 0, 0, 100),
            (prid('rugbrod'), iid('black sesame seeds'), 5.4, 0, 0, 100),
            (prid('rugbrod'), iid('whole flax seeds'), 3.5, 0, 0, 100),
            (prid('rugbrod'), iid('chia seeds'), 5.4, 0, 0, 100),
            (prid('rugbrod'), iid('pumpkin seeds'), 36.4, 0, 0, 100),
            (prid('rugbrod'), iid('ground flax seeds'), 6.36, 0, 0, 0),
            (prid('rugbrod'), iid('sprouted kamut berries'), 29, 0, 0, 0),
            (prid('rugbrod'), iid('kefir whey'), 40, 0, 0, 100),
            (prid('rugbrod'), iid('sea salt'), 3.5, 0, 0, 0)
;


--any ingredient in this table will supercede dough_ingredient values
--otherwise, all dough_ingredient values will be used
INSERT INTO dough_mods (mod_name, product_id, ingredient_id, bakers_percent,
       percent_in_sour, percent_in_poolish, percent_in_soaker)
       VALUES ('cranberry', prid('kamut sourdough'), iid('dried cranberries'), 20, 0, 0, 0),
              ('cranberry', prid('kamut sourdough'), iid('water'), 75, 20, 0, 18),
              ('cranberry', prid('kamut sourdough'), iid('sea salt'), 2.0, 0, 0, 0)
;

            --special_orders
INSERT INTO special_orders (delivery_date, customer_id, io, product_id,
            shape_id, amt, modified)
       VALUES 
        --goji almond
            --((SELECT now()::date + interval '2 days'), pid('Blow'), 'i', prid('goji%'), 
                --sid('12" boule'), 1, (SELECT now())),

        --five
            ((SELECT now()::date + interval '5 days'), pid('Blow'), 'i', prid('five%'), 
                sid('12" boule'), 1, (SELECT now())),

        --kamut
            ((SELECT now()::date + interval '2 days'), pid('Blow'), 'i', prid('kamut sourdough'), 
                sid('12" boule'), 1, (SELECT now())),

        --pizza
            ((SELECT now()::date + interval '1 day'), pid('Blow'), 'i', prid('pizza dough'), 
                sid('16" pizza'), 6, (SELECT now())),

        --pita bread
            ((SELECT now()::date + interval '1 day'), pid('Blow'), 'i', prid('pita bread'), 
                sid('7" pita'), 8, (SELECT now())),

        --pita bread
            ((SELECT now()::date + interval '1 day'), pid('Bar'), 'i', prid('pita bread'), 
                sid('7" pita'), 4, (SELECT now())),
        
        --rugbrod
            --((SELECT now()::date + interval '2 days'), pid('Blow'), 'i', prid('rugbrod'), 
                --sid('walter 25'), 2, (SELECT now())),

        --cranberry walnut
            ((SELECT now()::date + interval '2 days'), pid('Blow'), 'i', prid('cranberry walnut'), 
                sid('hard rolls'), 4, (SELECT now())),
        
        --cranberry walnut
            ((SELECT now()::date + interval '2 days'), pid('Blow'), 'i', prid('cranberry walnut'), 
                sid('12" boule'), 1, (SELECT now()))
;

INSERT INTO days_of_week (dow_id, dow_names)
       VALUES
            (1, 'Mon'),
            (2, 'Tue'),
            (3, 'Wed'),
            (4, 'Thu'),
            (5, 'Fri'),
            (6, 'Sat'),
            (0, 'Sun')
;

INSERT INTO standing_orders (day_of_week, customer_id, io, product_id,
            shape_id, amt, modified)
       VALUES 
            (0, pid('Blow'), 'i', prid('yeastie%'), sid('100%'), 1, (SELECT now())),
            (1, pid('Blow'), 'i', prid('yeastie%'), sid('100%'), 1, (SELECT now())),
            (2, pid('Blow'), 'i', prid('yeastie%'), sid('100%'), 1, (SELECT now())),
            (3, pid('Blow'), 'i', prid('yeastie%'), sid('100%'), 1, (SELECT now())),
            (4, pid('Blow'), 'i', prid('yeastie%'), sid('100%'), 1, (SELECT now())),
            (5, pid('Blow'), 'i', prid('yeastie%'), sid('100%'), 1, (SELECT now())),
            (6, pid('Blow'), 'i', prid('yeastie%'), sid('100%'), 1, (SELECT now())),
            (0, pid('Blow'), 'i', prid('cao%'), sid('truffle'), 50, (SELECT now())),
            (1, pid('Blow'), 'i', prid('cao%'), sid('truffle'), 50, (SELECT now())),
            (2, pid('Blow'), 'i', prid('cao%'), sid('truffle'), 50, (SELECT now())),
            (3, pid('Blow'), 'i', prid('cao%'), sid('truffle'), 50, (SELECT now())),
            (4, pid('Blow'), 'i', prid('cao%'), sid('truffle'), 50, (SELECT now())),
            (5, pid('Blow'), 'i', prid('cao%'), sid('truffle'), 50, (SELECT now())),
            (6, pid('Blow'), 'i', prid('cao%'), sid('truffle'), 50, (SELECT now())),
            (1, pid('Blow'), 'i', prid('goji%'), sid('12" boule'), 1, (SELECT now())),
            (2, pid('Blow'), 'i', prid('goji%'), sid('12" boule'), 1, (SELECT now())),
            (3, pid('Blow'), 'i', prid('goji%'), sid('12" boule'), 1, (SELECT now())),
            (4, pid('Blow'), 'i', prid('goji%'), sid('12" boule'), 1, (SELECT now())),
            (5, pid('Blow'), 'i', prid('goji%'), sid('12" boule'), 1, (SELECT now())),
            (6, pid('Blow'), 'i', prid('goji%'), sid('12" boule'), 1, (SELECT now())),
            (0, pid('Blow'), 'i', prid('goji%'), sid('12" boule'), 1, (SELECT now())),
            (1, pid('Blow'), 'i', prid('kamut%'), sid('12" boule'), 2, (SELECT now())),
            (2, pid('Blow'), 'i', prid('kamut%'), sid('12" boule'), 2, (SELECT now())),
            (3, pid('Blow'), 'i', prid('kamut%'), sid('12" boule'), 1, (SELECT now())),
            (4, pid('Blow'), 'i', prid('kamut%'), sid('12" boule'), 1, (SELECT now())),
            (5, pid('Blow'), 'i', prid('kamut%'), sid('12" boule'), 1, (SELECT now())),
            (6, pid('Blow'), 'i', prid('kamut%'), sid('12" boule'), 1, (SELECT now())),
            (0, pid('Blow'), 'i', prid('kamut%'), sid('12" boule'), 4, (SELECT now())),
            (1, pid('Blow'), 'i', prid('rugbrod'), sid('walter 25'), 2, (SELECT now())),
            (2, pid('Blow'), 'i', prid('rugbrod'), sid('walter 25'), 2, (SELECT now())),
            (3, pid('Blow'), 'i', prid('rugbrod'), sid('walter 25'), 2, (SELECT now())),
            (4, pid('Blow'), 'i', prid('rugbrod'), sid('walter 25'), 2, (SELECT now())),
            (5, pid('Blow'), 'i', prid('rugbrod'), sid('walter 25'), 2, (SELECT now())),
            (6, pid('Blow'), 'i', prid('rugbrod'), sid('walter 25'), 2, (SELECT now())),
            (0, pid('Blow'), 'i', prid('rugbrod'), sid('walter 25'), 2, (SELECT now())),
            (1, pid('Blow'), 'i', prid('leverpostej'), sid('walter 25'), 1, (SELECT now())),
            (2, pid('Blow'), 'i', prid('leverpostej'), sid('walter 25'), 1, (SELECT now())),
            (3, pid('Blow'), 'i', prid('leverpostej'), sid('walter 25'), 1, (SELECT now())),
            (4, pid('Blow'), 'i', prid('leverpostej'), sid('walter 25'), 1, (SELECT now())),
            (5, pid('Blow'), 'i', prid('leverpostej'), sid('walter 25'), 1, (SELECT now())),
            (6, pid('Blow'), 'i', prid('leverpostej'), sid('walter 25'), 1, (SELECT now())),
            (0, pid('Blow'), 'i', prid('leverpostej'), sid('walter 25'), 1, (SELECT now()))
;

--make temporary change to standing orders
INSERT INTO tmp_chng (day_of_week, customer_id, product_id, shape_id, start_date, resume_date, percent_multiplier)
       VALUES
            (1, pid('Blow'), prid('kamut sourdough'), sid('12" boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 50),
        
            (2, pid('Blow'), prid('kamut sourdough'), sid('12" boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 50),

            (3, pid('Blow'), prid('kamut sourdough'), sid('12" boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 200),

            (4, pid('Blow'), prid('kamut sourdough'), sid('12" boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 150),
        
            (5, pid('Blow'), prid('kamut sourdough'), sid('12" boule'), 
            (SELECT now()::date + interval '8 days'), (SELECT now()::date + interval '14 days'), 300),

            (6, pid('Blow'), prid('kamut sourdough'), sid('12" boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 200),

            (0, pid('Blow'), prid('kamut sourdough'), sid('12" boule'), 
            (SELECT now()::date + interval '2 days'), (SELECT now()::date + interval '7 days'), 50)
;

UPDATE standing_orders 
   SET amt = 2
 WhERE day_of_week = 0 AND customer_id = pid('Blow')
   AND product_id = prid('kam%');


UPDATE parties
SET party_name = 'Dept of Shenanigans'
WHERE party_name Like 'Dept%';

UPDATE ingredient_costs
   SET cost = 6.00
 WHERE ingredient_id = iid('kamut flour')

-- Ran five tests with 2 indexes + no index on 
-- party_name and ingredient_name
--
--           test_name        | which_index | median 
--    ------------------------+-------------+--------
--     ingredient_name_join   | trgm        |  0.245
--     ingredient_name_join   | b-tree      |  0.412
--     ingredient_name_join   | none        |  0.464
--     insert_ingredients     | none        | 20.107
--     insert_ingredients     | b-tree      | 26.035
--     insert_ingredients     | trgm        | 34.551
--     insert_parties         | none        |  21.08
--     insert_parties         | b-tree      | 27.128
--     insert_parties         | trgm        |  29.44
--     party_name_equal       | b-tree      |  0.047
--     party_name_equal       | trgm        |  0.053
--     party_name_equal       | none        |  0.057
--     update_ingredient_cost | trgm        |   0.17
--     update_ingredient_cost | b-tree      |  0.504
--     update_ingredient_cost | none        |  0.884
