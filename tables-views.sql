SELECT party_id, party_type, org_type, ein
  FROM organization_st;

SELECT party_id, party_type, party_name
  FROM parties;

SELECT party_id, name, party_type, type, phone_no
  FROM phone_book;

SELECT party_id, first_name, last_name, ssn
       is_active, hire_date, street_no, street
       city, state, zip, mobile
  FROM staff_list;

SELECT dough_id, dough_name, lead_time_days
  FROM doughs;

SELECT ingredient_id, ingredient, manufacturer
  FROM ingredient_list;

SELECT party_id, first_name, last_name
  FROM people_list;
