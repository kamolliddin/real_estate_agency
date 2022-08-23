-- -- CREATE DATABASE 'real_estate_agency':
-- CREATE DATABASE real_estate_agency WITH OWNER postgres;
-- COMMENT ON DATABASE real_estate_agency IS 'Database for real estate agency (final_task)';
--
-- -- CREATE SCHEMA 'agency':
-- CREATE SCHEMA agency;
-- COMMENT ON SCHEMA agency IS 'schema for real estate agency';
-- ALTER SCHEMA agency OWNER TO postgres;

-- SELECT SCHEMA 'agency':
SET search_path TO agency;

-- TRIGGER FUNCTION FOR 'updated_at' COLUMN:
-- Almost all tables contain updated_at column to track the date and time when record in the table was updated
-- To automate filling this column, I will create a trigger for each table that has such column
-- and use trigger function below:
CREATE OR REPLACE FUNCTION last_updated() RETURNS TRIGGER
    LANGUAGE plpgsql
AS
$$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END
$$;

-- TABLES (DDL):

-- country:
CREATE TABLE IF NOT EXISTS "country"
(
    "country_id" smallint generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "country"    varchar(100) NOT NULL UNIQUE,
    "updated_at" timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" date         NOT NULL DEFAULT CURRENT_DATE
);
ALTER TABLE country
    ADD CONSTRAINT "CHECK_country_characters" CHECK (country ~* '^[A-Za-z\s,.()]+$');
-- country updated_at trigger
DROP TRIGGER IF EXISTS country_last_updated ON country;
CREATE TRIGGER country_last_updated
    BEFORE UPDATE
    ON country
    FOR EACH ROW
EXECUTE PROCEDURE last_updated();

-- city:
CREATE TABLE IF NOT EXISTS "city"
(
    "city_id"    smallint generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "city"       varchar(100)                                                NOT NULL,
    "country_id" smallint REFERENCES country (country_id) ON DELETE RESTRICT NOT NULL,
    "updated_at" timestamp                                                   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" date                                                        NOT NULL DEFAULT CURRENT_DATE
);
ALTER TABLE city
    ADD CONSTRAINT "CHECK_city_characters" CHECK (city ~* '^[A-Za-z\s,.()-/]+$');
-- city updated_at trigger:
DROP TRIGGER IF EXISTS city_last_updated ON city;
CREATE TRIGGER city_last_updated
    BEFORE UPDATE
    ON city
    FOR EACH ROW
EXECUTE PROCEDURE last_updated();
-- index on foreign keys:
CREATE INDEX IF NOT EXISTS "idx_city_country_id" ON city(country_id);

-- address:
CREATE TABLE IF NOT EXISTS "address"
(
    "address_id"  int generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "address"     varchar(100)                                          NOT NULL,
    "district"    varchar(100)                                          NOT NULL,
    "city_id"     smallint REFERENCES city (city_id) ON DELETE RESTRICT NOT NULL,
    "postal_code" varchar(50)                                           NOT NULL,
    "updated_at"  timestamp                                             NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at"  date                                                  NOT NULL DEFAULT CURRENT_DATE
);
ALTER TABLE address ADD CONSTRAINT "CHECK_district_characters" CHECK (district ~* '^[A-Za-z\s,.()-]+$');
-- address updated_at trigger:
DROP TRIGGER IF EXISTS address_last_updated ON address;
CREATE TRIGGER address_last_updated
    BEFORE UPDATE
    ON address
    FOR EACH ROW
EXECUTE PROCEDURE last_updated();
-- index on foreign keys:
CREATE INDEX IF NOT EXISTS "idx_address_city_id" ON address(city_id);

-- client:
-- There two types of clients (INDIVIDUAL and ORGANIZATION) that are stored in this table
CREATE TABLE IF NOT EXISTS "client"
(
    "client_id"    int generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "client_type"  smallint                                               NOT NULL,
    "name"         varchar(255)                                           NOT NULL,
    "address_id"   int REFERENCES address (address_id) ON DELETE RESTRICT NOT NULL,
    "phone_number" varchar(100)                                           NOT NULL UNIQUE,
    "email"        varchar(100)                                           NOT NULL UNIQUE,
    "details"      text                                                   NOT NULL DEFAULT 'no client details specified',
    "updated_at"   timestamp                                              NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at"   date                                                   NOT NULL DEFAULT CURRENT_DATE
);
ALTER TABLE client ADD CONSTRAINT "CHECK_client_type" CHECK (client_type IN (1, 2));
ALTER TABLE client ADD CONSTRAINT "CHECK_client_name_characters" CHECK (name ~* '^[A-Za-z\s.]+$');
ALTER TABLE client ADD CONSTRAINT "CHECK_client_phone_number" CHECK (phone_number ~* '^\d*$');
ALTER TABLE client ADD CONSTRAINT "CHECK_client_email" CHECK (email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$');
-- comments on columns:
COMMENT ON COLUMN client.client_type IS '1 - INDIVIDUAL, 2 - ORGANIZATION';
-- client updated_at trigger:
DROP TRIGGER IF EXISTS client_last_updated ON client;
CREATE TRIGGER client_last_updated
    BEFORE UPDATE
    ON client
    FOR EACH ROW
EXECUTE PROCEDURE last_updated();
-- index on foreign keys:
CREATE INDEX IF NOT EXISTS "idx_client_address_id" ON client(address_id);

-- organization_contact:
-- If client is an organization, they provide a manager to contact with.
-- All such contacts are stored in this table
CREATE TABLE IF NOT EXISTS "organization_contact"
(
    "organization_contact_id" int generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "client_id"               int REFERENCES client (client_id) ON DELETE RESTRICT NOT NULL,
    "person_name"             varchar(255)                                         NOT NULL,
    "person_email"            varchar(100)                                         NOT NULL UNIQUE,
    "person_phone_number"     varchar(100)                                         NOT NULL UNIQUE,
    "updated_at"              timestamp                                            NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at"              date                                                 NOT NULL DEFAULT CURRENT_DATE
);
ALTER TABLE organization_contact ADD CONSTRAINT "CHECK_person_name_characters" CHECK (person_name ~* '^[A-Za-z\s.]+$');
ALTER TABLE organization_contact ADD CONSTRAINT "CHECK_person_phone_number" CHECK (person_phone_number ~* '^\d*$');
ALTER TABLE organization_contact ADD CONSTRAINT "CHECK_person_email" CHECK (person_email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$');
-- organization_contact updated_at trigger:
DROP TRIGGER IF EXISTS organization_contact_last_updated ON organization_contact;
CREATE TRIGGER organization_contact_last_updated
    BEFORE UPDATE
    ON organization_contact
    FOR EACH ROW
EXECUTE PROCEDURE last_updated();
-- index on foreign keys:
CREATE INDEX IF NOT EXISTS "idx_organization_contact_client_id" ON organization_contact(client_id);

-- position:
-- Table to store positions within agency each employee might work as
CREATE TABLE IF NOT EXISTS "position"
(
    "position_id" smallint generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "title"       varchar(50) NOT NULL UNIQUE,
    "description" text        NOT NULL DEFAULT 'no description was provided for this position',
    "created_at"  date        NOT NULL DEFAULT CURRENT_DATE
);

-- employee:
CREATE TABLE IF NOT EXISTS "employee"
(
    "employee_id" int generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "position_id" smallint REFERENCES position (position_id) ON DELETE RESTRICT NOT NULL,
    "first_name"  varchar(100)                                                  NOT NULL,
    "last_name"   varchar(100)                                                  NOT NULL,
    "address_id"  int REFERENCES address (address_id) ON DELETE RESTRICT        NOT NULL,
    "profile_url" text                                                          NOT NULL,
    "begin_date"  date                                                          NOT NULL,
    "end_date"    date                                                                   DEFAULT CURRENT_DATE + INTERVAL '100' YEAR,
    "condition"   smallint                                                      NOT NULL DEFAULT 1,
    "updated_at"  timestamp                                                     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at"  date                                                          NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (first_name, last_name, address_id, condition)
);
ALTER TABLE employee ADD CONSTRAINT "CHECK_employee_condition" CHECK (condition IN (0, 1));
ALTER TABLE employee ADD CONSTRAINT "CHECK_employee_first_name_characters" CHECK (first_name ~* '^[A-Za-z.]+$');
ALTER TABLE employee ADD CONSTRAINT "CHECK_employee_last_name_characters" CHECK (last_name ~* '^[A-Za-z.]+$');
ALTER TABLE employee ADD CONSTRAINT "CHECK_employee_work_period" CHECK (end_date > begin_date);
-- comments on columns:
COMMENT ON COLUMN employee.condition IS '0 - INACTIVE, 1 - ACTIVE';
-- employee updated_at trigger:
DROP TRIGGER IF EXISTS employee_last_updated ON employee;
CREATE TRIGGER employee_last_updated
    BEFORE UPDATE
    ON employee
    FOR EACH ROW
EXECUTE PROCEDURE last_updated();
-- index on foreign keys:
CREATE INDEX IF NOT EXISTS "idx_employee_position_id" ON employee(position_id);
CREATE INDEX IF NOT EXISTS "idx_employee_address_id" ON employee(address_id);

-- employee_contact:
-- Table to store the data of all employees
CREATE TABLE IF NOT EXISTS "employee_contact"
(
    "employee_contact_id" int generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "employee_id"         int REFERENCES employee (employee_id) ON DELETE RESTRICT NOT NULL,
    "phone_number"        varchar(100)                                             NOT NULL UNIQUE,
    "email"               varchar(100)                                             NOT NULL UNIQUE,
    "updated_at"          timestamp                                                NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at"          date                                                     NOT NULL DEFAULT CURRENT_DATE
);
ALTER TABLE employee_contact ADD CONSTRAINT "CHECK_employee_contact_phone_number" CHECK (phone_number ~* '^\d*$');
ALTER TABLE employee_contact ADD CONSTRAINT "CHECK_employee_contact_email" CHECK (email ~* '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$');
-- employee_contact updated_at trigger:
DROP TRIGGER IF EXISTS employee_contact_last_updated ON employee_contact;
CREATE TRIGGER employee_contact_last_updated
    BEFORE UPDATE
    ON employee_contact
    FOR EACH ROW
EXECUTE PROCEDURE last_updated();
-- index on foreign keys:
CREATE INDEX IF NOT EXISTS "idx_employee_contact_employee_id" ON employee_contact(employee_id);

-- estate_type:
-- Table to store real estate types such as land, house, office and so on
CREATE TABLE IF NOT EXISTS "estate_type"
(
    "estate_type_id" smallint generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "type"           varchar(100) NOT NULL UNIQUE,
    "created_at"     date         NOT NULL DEFAULT CURRENT_DATE
);

-- estate_condition:
-- Table to store real estate conditions such under consideration, rental, sold, bought and so on
CREATE TABLE IF NOT EXISTS "estate_condition"
(
    "estate_condition_id" smallint generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "condition"           varchar(100) NOT NULL UNIQUE,
    "created_at"          date         NOT NULL DEFAULT CURRENT_DATE
);

-- estate:
CREATE TABLE IF NOT EXISTS "estate"
(
    "estate_id"           varchar(7) PRIMARY KEY,
    -- id of client who want to sell the property
    -- or id of client who bought the property
    -- when agency buys the estate from client, it is left with value of previous owner until new owner comes
    "client_id"           int REFERENCES client (client_id) ON DELETE RESTRICT                          NOT NULL,
    "address_id"          int REFERENCES address (address_id) ON DELETE RESTRICT                        NOT NULL,
    "estate_type_id"      smallint REFERENCES estate_type (estate_type_id) ON DELETE RESTRICT           NOT NULL,
    "full_description"    text                                                                          NOT NULL,
    price                 bigint                                                                        NOT NULL,
    "page_url"            text                                                                          NOT NULL DEFAULT 'catalog url was not yet specified',
    "estate_condition_id" smallint REFERENCES estate_condition (estate_condition_id) ON DELETE RESTRICT NOT NULL,
    "updated_at"          timestamp                                                                     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at"          date                                                                          NOT NULL DEFAULT CURRENT_DATE
);
ALTER TABLE estate ADD CONSTRAINT "CHECK_estate_price" CHECK (price > 0);
-- estate updated_at trigger:
DROP TRIGGER IF EXISTS estate_last_updated ON estate;
CREATE TRIGGER estate_last_updated
    BEFORE UPDATE
    ON estate
    FOR EACH ROW
EXECUTE PROCEDURE last_updated();
-- index on foreign keys:
CREATE INDEX IF NOT EXISTS "idx_estate_estate_id" ON estate (estate_id);
CREATE INDEX IF NOT EXISTS "idx_estate_address_id" ON estate (address_id);
CREATE INDEX IF NOT EXISTS "idx_estate_type_id" ON estate (estate_type_id);
CREATE INDEX IF NOT EXISTS "idx_estate_condition_id" ON estate (estate_condition_id);

-- contract_type:
CREATE TABLE IF NOT EXISTS "contract_type"
(
    "contract_type_id" smallint generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "type"             varchar(100) NOT NULL UNIQUE,
    "cost"             bigint       NOT NULL,
    "description"      text         NOT NULL DEFAULT 'no description was provided for this contract type',
    "updated_at"       timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at"       date         NOT NULL DEFAULT CURRENT_DATE
);
-- contract_type updated_at trigger:
DROP TRIGGER IF EXISTS contract_type_last_updated ON contract_type;
CREATE TRIGGER contract_type_last_updated
    BEFORE UPDATE
    ON contract_type
    FOR EACH ROW
EXECUTE PROCEDURE last_updated();

-- contract:
CREATE TABLE IF NOT EXISTS "contract"
(
    "contract_id"        int generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "contract_type_id"   smallint REFERENCES contract_type (contract_type_id) ON DELETE RESTRICT NOT NULL,
    "client_id"          int REFERENCES client (client_id) ON DELETE RESTRICT                    NOT NULL,
    "employee_id"        int REFERENCES employee (employee_id) ON DELETE RESTRICT                NOT NULL,
    "estate_id"          varchar(7) REFERENCES estate (estate_id) ON DELETE RESTRICT                    NOT NULL,
    "details"            text                                                                    NOT NULL DEFAULT 'no detail were specified for this contract',
    "number_of_payments" smallint                                                                NOT NULL,
    "payment_amount"     bigint                                                                  NOT NULL,
    "contract_date"      date                                                                    NOT NULL DEFAULT CURRENT_DATE,
    "start_date"         date                                                                    NOT NULL,
    "end_date"           date,
    "updated_at"         timestamp                                                               NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at"         date                                                                    NOT NULL DEFAULT CURRENT_DATE
);
ALTER TABLE contract
    ADD CONSTRAINT "CHECK_contract_number_of_payments" CHECK (number_of_payments > 0);
ALTER TABLE contract
    ADD CONSTRAINT "CHECK_contract_payment_amount" CHECK (payment_amount > 0);
ALTER TABLE contract
    ADD CONSTRAINT "CHECK_contract_period" CHECK (end_date >= start_date);
-- contract updated_at trigger:
DROP TRIGGER IF EXISTS contract_last_updated ON contract;
CREATE TRIGGER contract_last_updated
    BEFORE UPDATE
    ON contract
    FOR EACH ROW
EXECUTE PROCEDURE last_updated();
-- index on foreign keys:
CREATE INDEX IF NOT EXISTS "idx_contract_type_id" ON contract (contract_type_id);
CREATE INDEX IF NOT EXISTS "idx_contract_client_id" ON contract (client_id);
CREATE INDEX IF NOT EXISTS "idx_contract_employee_id" ON contract (employee_id);
CREATE INDEX IF NOT EXISTS "idx_contract_estate_id" ON contract (estate_id);

-- document_type:
CREATE TABLE IF NOT EXISTS "document_type"
(
    "document_type_id" smallint generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "type"             varchar(100) NOT NULL UNIQUE,
    "description"      text         NOT NULL DEFAULT 'no description was provided for this document type',
    "created_at"       date         NOT NULL DEFAULT CURRENT_DATE
);

-- document:
CREATE TABLE IF NOT EXISTS "document"
(
    "document_id"      int generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "contract_id"      int REFERENCES contract (contract_id) ON DELETE RESTRICT                NOT NULL,
    "document_type_id" smallint REFERENCES document_type (document_type_id) ON DELETE RESTRICT NOT NULL,
    "title"            varchar(255)                                                            NOT NULL,
    "url"              text                                                                    NOT NULL DEFAULT 'file url for this document was not specified',
    "signed_date"      date                                                                    NOT NULL,
    "confirmed"        boolean                                                                          DEFAULT false,
    "updated_at"       timestamp                                                               NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at"       date                                                                    NOT NULL DEFAULT CURRENT_DATE,
    UNIQUE (document_id, created_at)
);
-- document updated_at trigger:
DROP TRIGGER IF EXISTS document_last_updated ON document;
CREATE TRIGGER document_last_updated
    BEFORE UPDATE
    ON document
    FOR EACH ROW
EXECUTE PROCEDURE last_updated();
-- index on foreign keys:
CREATE INDEX IF NOT EXISTS "idx_document_contract_id" ON document(contract_id);
CREATE INDEX IF NOT EXISTS "idx_document_document_type_id" ON document(document_type_id);

-- payment_type:
CREATE TABLE IF NOT EXISTS "payment_type" (
  "payment_type_id" int generated always as identity (start with 1 increment by 1) PRIMARY KEY,
  "type" varchar(100) NOT NULL,
  "provider" varchar(100) NOT NULL,
  "created_at" date NOT NULL DEFAULT CURRENT_DATE,
   UNIQUE (type, provider)
);

-- payment:
CREATE TABLE IF NOT EXISTS "payment"
(
    "payment_id"          int generated always as identity (start with 1 increment by 1) PRIMARY KEY,
    "contract_id"         int REFERENCES contract (contract_id) ON DELETE RESTRICT                NOT NULL,
    "contract_type_id"    smallint REFERENCES contract_type (contract_type_id) ON DELETE RESTRICT NOT NULL,
    "payment_type_id"     smallint REFERENCES payment_type (payment_type_id) ON DELETE RESTRICT   NOT NULL,
    "invoice_id"          varchar(100)                                                            NOT NULL UNIQUE,
    "issued_by"           text                                                                    NOT NULL,
    "issued_to"           text                                                                    NOT NULL,
    "amount"              bigint                                                                  NOT NULL,
    "discount"            boolean                                                                 NOT NULL DEFAULT false,
    "discount_percentage" smallint                                                                NOT NULL DEFAULT 0,
    "details"             text                                                                    NOT NULL,
    "updated_at"          timestamp                                                               NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "payment_date"        date,
    "created_at"          date                                                                             DEFAULT CURRENT_DATE
);
ALTER TABLE payment ADD CONSTRAINT "CHECK_payment_amount" CHECK (amount > 0);
-- max 20% of discount for our organization:
ALTER TABLE payment ADD CONSTRAINT "CHECK_payment_discount_percentage" CHECK (discount_percentage between 0 and 20);
-- payment updated_at trigger:
DROP TRIGGER IF EXISTS payment_last_updated ON payment;
CREATE TRIGGER payment_last_updated
    BEFORE UPDATE
    ON payment
    FOR EACH ROW
EXECUTE PROCEDURE last_updated();
-- index on foreign keys:
CREATE INDEX IF NOT EXISTS "idx_payment_contract_id" ON payment(contract_id);
CREATE INDEX IF NOT EXISTS "idx_payment_contract_type_id" ON payment(contract_type_id);
CREATE INDEX IF NOT EXISTS "idx_payment_type_id" ON payment(payment_type_id);




-- DATA (DML):

-- pre-populate country data:
insert into country (country)
values  ('Afghanistan'),
        ('Algeria'),
        ('American Samoa'),
        ('Angola'),
        ('Anguilla'),
        ('Argentina'),
        ('Armenia'),
        ('Australia'),
        ('Austria'),
        ('Azerbaijan'),
        ('Bahrain'),
        ('Bangladesh'),
        ('Belarus'),
        ('Bolivia'),
        ('Brazil'),
        ('Brunei'),
        ('Bulgaria'),
        ('Cambodia'),
        ('Cameroon'),
        ('Canada'),
        ('Chad'),
        ('Chile'),
        ('China'),
        ('Colombia'),
        ('Congo, The Democratic Republic of the'),
        ('Czech Republic'),
        ('Dominican Republic'),
        ('Ecuador'),
        ('Egypt'),
        ('Estonia'),
        ('Ethiopia'),
        ('Faroe Islands'),
        ('Finland'),
        ('France'),
        ('French Guiana'),
        ('French Polynesia'),
        ('Gambia'),
        ('Germany'),
        ('Greece'),
        ('Greenland'),
        ('Holy See (Vatican City State)'),
        ('Hong Kong'),
        ('Hungary'),
        ('India'),
        ('Indonesia'),
        ('Iran'),
        ('Iraq'),
        ('Israel'),
        ('Italy'),
        ('Japan'),
        ('Kazakstan'),
        ('Kenya'),
        ('Kuwait'),
        ('Latvia'),
        ('Liechtenstein'),
        ('Lithuania'),
        ('Madagascar'),
        ('Malawi'),
        ('Malaysia'),
        ('Mexico'),
        ('Moldova'),
        ('Morocco'),
        ('Mozambique'),
        ('Myanmar'),
        ('Nauru'),
        ('Nepal'),
        ('Netherlands'),
        ('New Zealand'),
        ('Nigeria'),
        ('North Korea'),
        ('Oman'),
        ('Pakistan'),
        ('Paraguay'),
        ('Peru'),
        ('Philippines'),
        ('Poland'),
        ('Puerto Rico'),
        ('Romania'),
        ('Runion'),
        ('Russian Federation'),
        ('Saint Vincent and the Grenadines'),
        ('Saudi Arabia'),
        ('Senegal'),
        ('Slovakia'),
        ('South Africa'),
        ('South Korea'),
        ('Spain'),
        ('Sri Lanka'),
        ('Sudan'),
        ('Sweden'),
        ('Switzerland'),
        ('Taiwan'),
        ('Tanzania'),
        ('Thailand'),
        ('Tonga'),
        ('Tunisia'),
        ('Turkey'),
        ('Turkmenistan'),
        ('Tuvalu'),
        ('Ukraine'),
        ('United Arab Emirates'),
        ('United Kingdom'),
        ('United States'),
        ('Venezuela'),
        ('Vietnam'),
        ('Virgin Islands, U.S.'),
        ('Yemen'),
        ('Yugoslavia'),
        ('Zambia'),
        ('Uzbekistan');

-- pre-populate city data:
insert into city(city, country_id)
values  ('A Corua (La Corua)', 87),
        ('Abha', 82),
        ('Abu Dhabi', 101),
        ('Acua', 60),
        ('Adana', 97),
        ('Addis Abeba', 31),
        ('Aden', 107),
        ('Adoni', 44),
        ('Ahmadnagar', 44),
        ('Akishima', 50),
        ('Akron', 103),
        ('al-Ayn', 101),
        ('al-Hawiya', 82),
        ('al-Manama', 11),
        ('al-Qadarif', 89),
        ('al-Qatif', 82),
        ('Alessandria', 49),
        ('Allappuzha (Alleppey)', 44),
        ('Allende', 60),
        ('Almirante Brown', 6),
        ('Alvorada', 15),
        ('Ambattur', 44),
        ('Amersfoort', 67),
        ('Amroha', 44),
        ('Angra dos Reis', 15),
        ('Anpolis', 15),
        ('Antofagasta', 22),
        ('Aparecida de Goinia', 15),
        ('Apeldoorn', 67),
        ('Araatuba', 15),
        ('Arak', 46),
        ('Arecibo', 77),
        ('Arlington', 103),
        ('Ashdod', 48),
        ('Ashgabat', 98),
        ('Ashqelon', 48),
        ('Asuncin', 73),
        ('Athenai', 39),
        ('Atinsk', 80),
        ('Atlixco', 60),
        ('Augusta-Richmond County', 103),
        ('Aurora', 103),
        ('Avellaneda', 6),
        ('Bag', 15),
        ('Baha Blanca', 6),
        ('Baicheng', 23),
        ('Baiyin', 23),
        ('Baku', 10),
        ('Balaiha', 80),
        ('Balikesir', 97),
        ('Balurghat', 44),
        ('Bamenda', 19),
        ('Bandar Seri Begawan', 16),
        ('Banjul', 37),
        ('Barcelona', 104),
        ('Basel', 91),
        ('Bat Yam', 48),
        ('Batman', 97),
        ('Batna', 2),
        ('Battambang', 18),
        ('Baybay', 75),
        ('Bayugan', 75),
        ('Bchar', 2),
        ('Beira', 63),
        ('Bellevue', 103),
        ('Belm', 15),
        ('Benguela', 4),
        ('Beni-Mellal', 62),
        ('Benin City', 69),
        ('Bergamo', 49),
        ('Berhampore (Baharampur)', 44),
        ('Bern', 91),
        ('Bhavnagar', 44),
        ('Bhilwara', 44),
        ('Bhimavaram', 44),
        ('Bhopal', 44),
        ('Bhusawal', 44),
        ('Bijapur', 44),
        ('Bilbays', 29),
        ('Binzhou', 23),
        ('Birgunj', 66),
        ('Bislig', 75),
        ('Blumenau', 15),
        ('Boa Vista', 15),
        ('Boksburg', 85),
        ('Botosani', 78),
        ('Botshabelo', 85),
        ('Bradford', 102),
        ('Braslia', 15),
        ('Bratislava', 84),
        ('Brescia', 49),
        ('Brest', 34),
        ('Brindisi', 49),
        ('Brockton', 103),
        ('Bucuresti', 78),
        ('Buenaventura', 24),
        ('Bydgoszcz', 76),
        ('Cabuyao', 75),
        ('Callao', 74),
        ('Cam Ranh', 105),
        ('Cape Coral', 103),
        ('Caracas', 104),
        ('Carmen', 60),
        ('Cavite', 75),
        ('Cayenne', 35),
        ('Celaya', 60),
        ('Chandrapur', 44),
        ('Changhwa', 92),
        ('Changzhou', 23),
        ('Chapra', 44),
        ('Charlotte Amalie', 106),
        ('Chatsworth', 85),
        ('Cheju', 86),
        ('Chiayi', 92),
        ('Chisinau', 61),
        ('Chungho', 92),
        ('Cianjur', 45),
        ('Ciomas', 45),
        ('Ciparay', 45),
        ('Citrus Heights', 103),
        ('Citt del Vaticano', 41),
        ('Ciudad del Este', 73),
        ('Clarksville', 103),
        ('Coacalco de Berriozbal', 60),
        ('Coatzacoalcos', 60),
        ('Compton', 103),
        ('Coquimbo', 22),
        ('Crdoba', 6),
        ('Cuauhtmoc', 60),
        ('Cuautla', 60),
        ('Cuernavaca', 60),
        ('Cuman', 104),
        ('Czestochowa', 76),
        ('Dadu', 72),
        ('Dallas', 103),
        ('Datong', 23),
        ('Daugavpils', 54),
        ('Davao', 75),
        ('Daxian', 23),
        ('Dayton', 103),
        ('Deba Habe', 69),
        ('Denizli', 97),
        ('Dhaka', 12),
        ('Dhule (Dhulia)', 44),
        ('Dongying', 23),
        ('Donostia-San Sebastin', 87),
        ('Dos Quebradas', 24),
        ('Duisburg', 38),
        ('Dundee', 102),
        ('Dzerzinsk', 80),
        ('Ede', 67),
        ('Effon-Alaiye', 69),
        ('El Alto', 14),
        ('El Fuerte', 60),
        ('El Monte', 103),
        ('Elista', 80),
        ('Emeishan', 23),
        ('Emmen', 67),
        ('Enshi', 23),
        ('Erlangen', 38),
        ('Escobar', 6),
        ('Esfahan', 46),
        ('Eskisehir', 97),
        ('Etawah', 44),
        ('Ezeiza', 6),
        ('Ezhou', 23),
        ('Faaa', 36),
        ('Fengshan', 92),
        ('Firozabad', 44),
        ('Florencia', 24),
        ('Fontana', 103),
        ('Fukuyama', 50),
        ('Funafuti', 99),
        ('Fuyu', 23),
        ('Fuzhou', 23),
        ('Gandhinagar', 44),
        ('Garden Grove', 103),
        ('Garland', 103),
        ('Gatineau', 20),
        ('Gaziantep', 97),
        ('Gijn', 87),
        ('Gingoog', 75),
        ('Goinia', 15),
        ('Gorontalo', 45),
        ('Grand Prairie', 103),
        ('Graz', 9),
        ('Greensboro', 103),
        ('Guadalajara', 60),
        ('Guaruj', 15),
        ('guas Lindas de Gois', 15),
        ('Gulbarga', 44),
        ('Hagonoy', 75),
        ('Haining', 23),
        ('Haiphong', 105),
        ('Haldia', 44),
        ('Halifax', 20),
        ('Halisahar', 44),
        ('Halle/Saale', 38),
        ('Hami', 23),
        ('Hamilton', 68),
        ('Hanoi', 105),
        ('Hidalgo', 60),
        ('Higashiosaka', 50),
        ('Hino', 50),
        ('Hiroshima', 50),
        ('Hodeida', 107),
        ('Hohhot', 23),
        ('Hoshiarpur', 44),
        ('Hsichuh', 92),
        ('Huaian', 23),
        ('Hubli-Dharwad', 44),
        ('Huejutla de Reyes', 60),
        ('Huixquilucan', 60),
        ('Hunuco', 74),
        ('Ibirit', 15),
        ('Idfu', 29),
        ('Ife', 69),
        ('Ikerre', 69),
        ('Iligan', 75),
        ('Ilorin', 69),
        ('Imus', 75),
        ('Inegl', 97),
        ('Ipoh', 59),
        ('Isesaki', 50),
        ('Ivanovo', 80),
        ('Iwaki', 50),
        ('Iwakuni', 50),
        ('Iwatsuki', 50),
        ('Izumisano', 50),
        ('Jaffna', 88),
        ('Jaipur', 44),
        ('Jakarta', 45),
        ('Jalib al-Shuyukh', 53),
        ('Jamalpur', 12),
        ('Jaroslavl', 80),
        ('Jastrzebie-Zdrj', 76),
        ('Jedda', 82),
        ('Jelets', 80),
        ('Jhansi', 44),
        ('Jinchang', 23),
        ('Jining', 23),
        ('Jinzhou', 23),
        ('Jodhpur', 44),
        ('Johannesburg', 85),
        ('Joliet', 103),
        ('Jos Azueta', 60),
        ('Juazeiro do Norte', 15),
        ('Juiz de Fora', 15),
        ('Junan', 23),
        ('Jurez', 60),
        ('Kabul', 1),
        ('Kaduna', 69),
        ('Kakamigahara', 50),
        ('Kaliningrad', 80),
        ('Kalisz', 76),
        ('Kamakura', 50),
        ('Kamarhati', 44),
        ('Kamjanets-Podilskyi', 100),
        ('Kamyin', 80),
        ('Kanazawa', 50),
        ('Kanchrapara', 44),
        ('Kansas City', 103),
        ('Karnal', 44),
        ('Katihar', 44),
        ('Kermanshah', 46),
        ('Kilis', 97),
        ('Kimberley', 85),
        ('Kimchon', 86),
        ('Kingstown', 81),
        ('Kirovo-Tepetsk', 80),
        ('Kisumu', 52),
        ('Kitwe', 109),
        ('Klerksdorp', 85),
        ('Kolpino', 80),
        ('Konotop', 100),
        ('Koriyama', 50),
        ('Korla', 23),
        ('Korolev', 80),
        ('Kowloon and New Kowloon', 42),
        ('Kragujevac', 108),
        ('Ktahya', 97),
        ('Kuching', 59),
        ('Kumbakonam', 44),
        ('Kurashiki', 50),
        ('Kurgan', 80),
        ('Kursk', 80),
        ('Kuwana', 50),
        ('La Paz', 60),
        ('La Plata', 6),
        ('La Romana', 27),
        ('Laiwu', 23),
        ('Lancaster', 103),
        ('Laohekou', 23),
        ('Lapu-Lapu', 75),
        ('Laredo', 103),
        ('Lausanne', 91),
        ('Le Mans', 34),
        ('Lengshuijiang', 23),
        ('Leshan', 23),
        ('Lethbridge', 20),
        ('Lhokseumawe', 45),
        ('Liaocheng', 23),
        ('Liepaja', 54),
        ('Lilongwe', 58),
        ('Lima', 74),
        ('Lincoln', 103),
        ('Linz', 9),
        ('Lipetsk', 80),
        ('Livorno', 49),
        ('Ljubertsy', 80),
        ('Loja', 28),
        ('London', 102),
        ('London', 20),
        ('Lublin', 76),
        ('Lubumbashi', 25),
        ('Lungtan', 92),
        ('Luzinia', 15),
        ('Madiun', 45),
        ('Mahajanga', 57),
        ('Maikop', 80),
        ('Malm', 90),
        ('Manchester', 103),
        ('Mandaluyong', 75),
        ('Mandi Bahauddin', 72),
        ('Mannheim', 38),
        ('Maracabo', 104),
        ('Mardan', 72),
        ('Maring', 15),
        ('Masqat', 71),
        ('Matamoros', 60),
        ('Matsue', 50),
        ('Meixian', 23),
        ('Memphis', 103),
        ('Merlo', 6),
        ('Mexicali', 60),
        ('Miraj', 44),
        ('Mit Ghamr', 29),
        ('Miyakonojo', 50),
        ('Mogiljov', 13),
        ('Molodetno', 13),
        ('Monclova', 60),
        ('Monywa', 64),
        ('Moscow', 80),
        ('Mosul', 47),
        ('Mukateve', 100),
        ('Munger (Monghyr)', 44),
        ('Mwanza', 93),
        ('Mwene-Ditu', 25),
        ('Myingyan', 64),
        ('Mysore', 44),
        ('Naala-Porto', 63),
        ('Nabereznyje Telny', 80),
        ('Nador', 62),
        ('Nagaon', 44),
        ('Nagareyama', 50),
        ('Najafabad', 46),
        ('Naju', 86),
        ('Nakhon Sawan', 94),
        ('Nam Dinh', 105),
        ('Namibe', 4),
        ('Nantou', 92),
        ('Nanyang', 23),
        ('NDjamna', 21),
        ('Newcastle', 85),
        ('Nezahualcyotl', 60),
        ('Nha Trang', 105),
        ('Niznekamsk', 80),
        ('Novi Sad', 108),
        ('Novoterkassk', 80),
        ('Nukualofa', 95),
        ('Nuuk', 40),
        ('Nyeri', 52),
        ('Ocumare del Tuy', 104),
        ('Ogbomosho', 69),
        ('Okara', 72),
        ('Okayama', 50),
        ('Okinawa', 50),
        ('Olomouc', 26),
        ('Omdurman', 89),
        ('Omiya', 50),
        ('Ondo', 69),
        ('Onomichi', 50),
        ('Oshawa', 20),
        ('Osmaniye', 97),
        ('ostka', 100),
        ('Otsu', 50),
        ('Oulu', 33),
        ('Ourense (Orense)', 87),
        ('Owo', 69),
        ('Oyo', 69),
        ('Ozamis', 75),
        ('Paarl', 85),
        ('Pachuca de Soto', 60),
        ('Pak Kret', 94),
        ('Palghat (Palakkad)', 44),
        ('Pangkal Pinang', 45),
        ('Papeete', 36),
        ('Parbhani', 44),
        ('Pathankot', 44),
        ('Patiala', 44),
        ('Patras', 39),
        ('Pavlodar', 51),
        ('Pemalang', 45),
        ('Peoria', 103),
        ('Pereira', 24),
        ('Phnom Penh', 18),
        ('Pingxiang', 23),
        ('Pjatigorsk', 80),
        ('Plock', 76),
        ('Po', 15),
        ('Ponce', 77),
        ('Pontianak', 45),
        ('Poos de Caldas', 15),
        ('Portoviejo', 28),
        ('Probolinggo', 45),
        ('Pudukkottai', 44),
        ('Pune', 44),
        ('Purnea (Purnia)', 44),
        ('Purwakarta', 45),
        ('Pyongyang', 70),
        ('Qalyub', 29),
        ('Qinhuangdao', 23),
        ('Qomsheh', 46),
        ('Quilmes', 6),
        ('Rae Bareli', 44),
        ('Rajkot', 44),
        ('Rampur', 44),
        ('Rancagua', 22),
        ('Ranchi', 44),
        ('Richmond Hill', 20),
        ('Rio Claro', 15),
        ('Rizhao', 23),
        ('Roanoke', 103),
        ('Robamba', 28),
        ('Rockford', 103),
        ('Ruse', 17),
        ('Rustenburg', 85),
        ('s-Hertogenbosch', 67),
        ('Saarbrcken', 38),
        ('Sagamihara', 50),
        ('Saint Louis', 103),
        ('Saint-Denis', 79),
        ('Sal', 62),
        ('Salala', 71),
        ('Salamanca', 60),
        ('Salinas', 103),
        ('Salzburg', 9),
        ('Sambhal', 44),
        ('San Bernardino', 103),
        ('San Felipe de Puerto Plata', 27),
        ('San Felipe del Progreso', 60),
        ('San Juan Bautista Tuxtepec', 60),
        ('San Lorenzo', 73),
        ('San Miguel de Tucumn', 6),
        ('Sanaa', 107),
        ('Santa Brbara dOeste', 15),
        ('Santa F', 6),
        ('Santa Rosa', 75),
        ('Santiago de Compostela', 87),
        ('Santiago de los Caballeros', 27),
        ('Santo Andr', 15),
        ('Sanya', 23),
        ('Sasebo', 50),
        ('Satna', 44),
        ('Sawhaj', 29),
        ('Serpuhov', 80),
        ('Shahr-e Kord', 46),
        ('Shanwei', 23),
        ('Shaoguan', 23),
        ('Sharja', 101),
        ('Shenzhen', 23),
        ('Shikarpur', 72),
        ('Shimoga', 44),
        ('Shimonoseki', 50),
        ('Shivapuri', 44),
        ('Shubra al-Khayma', 29),
        ('Siegen', 38),
        ('Siliguri (Shiliguri)', 44),
        ('Simferopol', 100),
        ('Sincelejo', 24),
        ('Sirjan', 46),
        ('Sivas', 97),
        ('Skikda', 2),
        ('Smolensk', 80),
        ('So Bernardo do Campo', 15),
        ('So Leopoldo', 15),
        ('Sogamoso', 24),
        ('Sokoto', 69),
        ('Songkhla', 94),
        ('Sorocaba', 15),
        ('Soshanguve', 85),
        ('Sousse', 96),
        ('South Hill', 5),
        ('Southampton', 102),
        ('Southend-on-Sea', 102),
        ('Southport', 102),
        ('Springs', 85),
        ('Stara Zagora', 17),
        ('Sterling Heights', 103),
        ('Stockport', 102),
        ('Sucre', 14),
        ('Suihua', 23),
        ('Sullana', 74),
        ('Sultanbeyli', 97),
        ('Sumqayit', 10),
        ('Sumy', 100),
        ('Sungai Petani', 59),
        ('Sunnyvale', 103),
        ('Surakarta', 45),
        ('Syktyvkar', 80),
        ('Syrakusa', 49),
        ('Szkesfehrvr', 43),
        ('Tabora', 93),
        ('Tabriz', 46),
        ('Tabuk', 82),
        ('Tafuna', 3),
        ('Taguig', 75),
        ('Taizz', 107),
        ('Talavera', 75),
        ('Tallahassee', 103),
        ('Tama', 50),
        ('Tambaram', 44),
        ('Tanauan', 75),
        ('Tandil', 6),
        ('Tangail', 12),
        ('Tanshui', 92),
        ('Tanza', 75),
        ('Tarlac', 75),
        ('Tarsus', 97),
        ('Tartu', 30),
        ('Teboksary', 80),
        ('Tegal', 45),
        ('Tel Aviv-Jaffa', 48),
        ('Tete', 63),
        ('Tianjin', 23),
        ('Tiefa', 23),
        ('Tieli', 23),
        ('Tokat', 97),
        ('Tonghae', 86),
        ('Tongliao', 23),
        ('Torren', 60),
        ('Touliu', 92),
        ('Toulon', 34),
        ('Toulouse', 34),
        ('Trshavn', 32),
        ('Tsaotun', 92),
        ('Tsuyama', 50),
        ('Tuguegarao', 75),
        ('Tychy', 76),
        ('Udaipur', 44),
        ('Udine', 49),
        ('Ueda', 50),
        ('Uijongbu', 86),
        ('Uluberia', 44),
        ('Urawa', 50),
        ('Uruapan', 60),
        ('Usak', 97),
        ('Usolje-Sibirskoje', 80),
        ('Uttarpara-Kotrung', 44),
        ('Vaduz', 55),
        ('Valencia', 104),
        ('Valle de la Pascua', 104),
        ('Valle de Santiago', 60),
        ('Valparai', 44),
        ('Vancouver', 20),
        ('Varanasi (Benares)', 44),
        ('Vicente Lpez', 6),
        ('Vijayawada', 44),
        ('Vila Velha', 15),
        ('Vilnius', 56),
        ('Vinh', 105),
        ('Vitria de Santo Anto', 15),
        ('Warren', 103),
        ('Weifang', 23),
        ('Witten', 38),
        ('Woodridge', 8),
        ('Wroclaw', 76),
        ('Xiangfan', 23),
        ('Xiangtan', 23),
        ('Xintai', 23),
        ('Xinxiang', 23),
        ('Yamuna Nagar', 44),
        ('Yangor', 65),
        ('Yantai', 23),
        ('Yaound', 19),
        ('Yerevan', 7),
        ('Yinchuan', 23),
        ('Yingkou', 23),
        ('York', 102),
        ('Yuncheng', 23),
        ('Yuzhou', 23),
        ('Zalantun', 23),
        ('Zanzibar', 93),
        ('Zaoyang', 23),
        ('Zapopan', 60),
        ('Zaria', 69),
        ('Zeleznogorsk', 80),
        ('Zhezqazghan', 51),
        ('Zhoushan', 23),
        ('Ziguinchor', 83),
        ('Tashkent', 110);

-- CREATE FUNCTION TO REDUCE CODE DUPLICATION:
CREATE OR REPLACE FUNCTION register_address(IN p_address text, IN p_district text, IN p_city_id int, IN p_postal_code varchar)
RETURNS INTEGER
LANGUAGE plpgsql
AS
$$
DECLARE out_address_id integer;
BEGIN
    insert into address (address, district, city_id, postal_code)
    values (p_address, p_district, p_city_id, p_postal_code)
    returning address_id into out_address_id;
    return out_address_id;
END;
$$;

-- CLIENT REGISTRATION:
INSERT INTO client(client_type, name, address_id, phone_number, email)
SELECT 1,
       'MARY SMITH',
       register_address('913 Coacalco de Berriozbal Loop', 'Texas', ci.city_id, '42141'),
       '262088367001',
       'MARY.SMITH@sakilacustomer.org'
FROM city ci JOIN country co ON co.country_id = ci.country_id
WHERE co.country = 'United States'
AND ci.city = 'Arlington';

INSERT INTO client(client_type, name, address_id, phone_number, email)
SELECT 1,
       'PATRICIA JOHNSON',
       register_address('1308 Arecibo Way', 'Georgia', ci.city_id, '30695'),
       '6171054059',
       'PATRICIA.JOHNSON@sakilacustomer.org'
FROM city ci JOIN country co ON co.country_id = ci.country_id
WHERE co.country = 'United States'
AND ci.city = 'Augusta-Richmond County';

INSERT INTO client(client_type, name, address_id, phone_number, email)
SELECT 1,
       'LINDA WILLIAMS',
        register_address('587 Benguela Manor', 'Illinois', ci.city_id, '91590'),
       '165450987037',
       'LINDA.WILLIAMS@sakilacustomer.org'
FROM city ci JOIN country co ON co.country_id = ci.country_id
WHERE co.country = 'United States'
AND ci.city = 'Aurora';

INSERT INTO client (client_type, name, address_id, phone_number, email)
SELECT 1,
       'BARBARA JONES',
       register_address('43 Vilnius Manor', 'Colorado', ci.city_id, '79814'),
       '484500282381',
       'BARBARA.JONES@sakilacustomer.org'
FROM city ci JOIN country co ON co.country_id = ci.country_id
WHERE co.country = 'United States'
AND ci.city = 'Aurora';

-- ORGANIZATION REGISTRATION:
INSERT INTO client (client_type, name, address_id, phone_number, email, details)
SELECT 2,
       'Tranio LLC',
       register_address('1819 Alessandria Loop', 'Campeche', ci.city_id, '53829'),
       '6505067000',
       'tranio@mail.com',
       'Tranio is an international real estate brokerage'
FROM city ci JOIN country co ON co.country_id = ci.country_id
WHERE co.country = 'United States'
AND ci.city = 'Akron';

INSERT INTO organization_contact(client_id, person_name, person_email, person_phone_number)
SELECT client_id, 'DEBRA NELSON', 'DEBRA.NELSON@tranio.com', '75975221996'
FROM client WHERE NAME = 'Tranio LLC';

INSERT INTO organization_contact(client_id, person_name, person_email, person_phone_number)
SELECT client_id, 'AMANDA CARTER', 'AMANDA.CARTER@tranio.com', '435785045362'
FROM client WHERE NAME = 'Tranio LLC';

INSERT INTO organization_contact(client_id, person_name, person_email, person_phone_number)
SELECT client_id, 'STEPHANIE MITCHELL', 'STEPHANIE.MITCHELL@tranio.com', '785881412500'
FROM client WHERE NAME = 'Tranio LLC';

INSERT INTO organization_contact(client_id, person_name, person_email, person_phone_number)
SELECT client_id, 'CAROLYN PEREZ', 'CAROLYN.PEREZ@tranio.com', '206841104594'
FROM client WHERE NAME = 'Tranio LLC';

INSERT INTO organization_contact(client_id, person_name, person_email, person_phone_number)
SELECT client_id, 'CHRISTINE ROBERTS', 'CHRISTINE.ROBERTS@tranio.com', '838635286649'
FROM client WHERE NAME = 'Tranio LLC';


-- EMPLOYEE REGISTRATION:
INSERT INTO position(title, description)
VALUES ('property manager',
        'A property manager oversees a rental property and manages the administrative duties associated with marketing the location, negotiating leases and maintaining the property. A property manager is responsible for establishing the appropriate rental rate for the area, collecting rent and managing the property’s budget to make sure that it’s profitable. The manager will also contract maintenance and landscaping services and schedule repairs and routine care.'
        ),
       (
        'home inspector',
        'A home inspector conducts inspections of real estate properties to inform potential buyers of any issues. The inspector looks at the electrical and plumbing systems, water quality, interior and exterior structures, HVAC system, roofing, attic, flooring and other aspects of the home. The inspector makes the potential buyer aware of the condition of the property and offers advice on the best ways to improve and care for the home.'
       ),
       (
        'real estate manager',
        'Real estate managers assist with the listing and sale of properties on behalf of the owners. These professionals help their clients maximize their return on value with any commercial or residential property sale. Their responsibilities include performing market research, performing due diligence on the property or terms of purchase, marketing the property and negotiating property agreements.'
       ),
       (
        'mortgage loan originator',
        'Mortgage loan originators evaluate loan applicants, determine their eligibility for a loan and execute loan proposals and contracts. They must be familiar with the various home loan programs available. Their responsibilities include counseling prospective homebuyers on the process of securing a mortgage and advising these clients on the best loan programs for their personal needs and financial situations.'
       ),
       (
        'real estate agent',
        'A real estate agent assists clients with the purchase or sale of real estate. The agent evaluates the market and offers advice based on current conditions. They walk buyers through properties and assist them in finding real estate that meets their needs. Real estate agents help sellers by listing, marketing and showing their properties.'
       );


insert into employee(position_id, first_name, last_name, address_id, profile_url, begin_date, condition)
select (select position_id from position where title = 'real estate manager'),
       'TYLER',
       'NASH',
       register_address('782 Mosul Street', 'Massachusetts', ci.city_id, '25545'),
       'https://buyingva.com/team/tyler-nash-licensed-real-estate-agent',
       '2019-01-01',
       1
from city ci join country co on co.country_id = ci.country_id
where co.country = 'United States' and ci.city = 'Brockton';

INSERT INTO employee_contact(employee_id, phone_number, email)
SELECT employee_id, 7577767236, 'Tylern@yourfriendlyagent.net'
FROM employee
WHERE first_name = 'TYLER'
  AND last_name = 'NASH'
  AND position_id = (select position_id from position where title = 'real estate manager');


insert into employee(position_id, first_name, last_name, address_id, profile_url, begin_date, condition)
select (select position_id from position where title = 'mortgage loan originator'),
       'MEZ',
       'ESPIRITU',
       register_address('1427 Tabuk Place', 'Florida', ci.city_id, '31342'),
       'https://buyingva.com/team/mez-espiritu-licensed-real-estate-agent',
       '2019-02-01',
       1
from city ci join country co on co.country_id = ci.country_id
where co.country = 'United States' and ci.city = 'Cape Coral';

INSERT INTO employee_contact(employee_id, phone_number, email)
SELECT employee_id, 7577052474, 'mez@yourfriendlyagent.net'
FROM employee
WHERE first_name = 'MEZ'
  AND last_name = 'ESPIRITU'
  AND position_id = (select position_id from position where title = 'mortgage loan originator');


insert into employee(position_id, first_name, last_name, address_id, profile_url, begin_date, condition)
select (select position_id from position where title = 'property manager'),
       'ANNIE',
       'SPECKHART',
       register_address('770 Bydgoszcz Avenue', 'California', ci.city_id, '16266'),
       'https://buyingva.com/team/annie-speckhart-licensed-real-estate-agent',
       '2019-03-01',
       1
from city ci join country co on co.country_id = ci.country_id
where co.country = 'United States' and ci.city = 'Citrus Heights';

INSERT INTO employee_contact(employee_id, phone_number, email)
SELECT employee_id, 7572889840, 'anniespeckharthomes@gmail.com'
FROM employee
WHERE first_name = 'ANNIE'
  AND last_name = 'SPECKHART'
  AND position_id = (select position_id from position where title = 'property manager');


insert into employee(position_id, first_name, last_name, address_id, profile_url, begin_date, condition)
select (select position_id from position where title = 'real estate agent'),
       'AMANDA',
       'WILLIAMS',
       register_address('1666 Beni-Mellal Place', 'Tennessee', ci.city_id, '13377'),
       'https://buyingva.com/team/amanda-williams-licensed-real-estate-agent',
       '2019-04-01',
       1
from city ci join country co on co.country_id = ci.country_id
where co.country = 'United States' and ci.city = 'Clarksville';

INSERT INTO employee_contact(employee_id, phone_number, email)
SELECT employee_id, 7572688426, 'amanda@yourfriendlyagent.net'
FROM employee
WHERE first_name = 'AMANDA'
  AND last_name = 'WILLIAMS'
  AND position_id = (select position_id from position where title = 'real estate agent');


insert into employee(position_id, first_name, last_name, address_id, profile_url, begin_date, end_date, condition)
select (select position_id from position where title = 'real estate agent'),
       'HOLLY',
       'HERBERT',
       register_address('533 al-Ayn Boulevard', 'California', ci.city_id, '8862'),
       'https://buyingva.com/team/holly-herbert',
       '2019-05-01',
       '2021-01-01',
       0
from city ci join country co on co.country_id = ci.country_id
where co.country = 'United States' and ci.city = 'Compton';

INSERT INTO employee_contact(employee_id, phone_number, email)
SELECT employee_id, 7572688566, 'holly@movinghrva.com'
FROM employee
WHERE first_name = 'HOLLY'
  AND last_name = 'HERBERT'
  AND position_id = (select position_id from position where title = 'real estate agent');



-- REAL ESTATE REGISTRATION:
INSERT INTO estate_type(type)
VALUES ('apartment'),
       ('house'),
       ('office'),
       ('hotel'),
       ('mall');

INSERT INTO estate_condition(condition)
VALUES ('estate registered'),
       ('estate undergoing operation'),
       ('estate leased'),
       ('estate bought'),
       ('estate sold'),
       ('estate rented');

INSERT INTO estate(estate_id, client_id, address_id, estate_type_id, full_description, price, page_url,
                   estate_condition_id)
SELECT 'OF00001',
       (SELECT client_id FROM client WHERE client_type = 2 and name = 'Tranio LLC'),
       register_address('530 Lausanne Lane', 'Texas', ci.city_id, '11067'),
       (select estate_type_id from estate_type where type = 'office'),
       'Freestanding bank building. Lot Dimensions: 100x125 m. The cost of the facility is 4,647,619 $. The absolute annual income is 244,000 $. The current yield of 5,25%.',
       464800000, -- in cents
       'https://tranio.com/commercial/usa/adt/1764284/',
       (select estate_condition_id from estate_condition where condition = 'estate registered')
FROM city ci
         JOIN country co ON co.country_id = ci.country_id
WHERE co.country = 'United States'
  AND ci.city = 'Dallas';


INSERT INTO estate(estate_id, client_id, address_id, estate_type_id, full_description, price, page_url,
                   estate_condition_id)
SELECT 'HO00001',
       (SELECT client_id FROM client WHERE client_type = 1 and name = 'MARY SMITH' and email = 'MARY.SMITH@sakilacustomer.org'),
       register_address('32 Pudukkottai Lane', 'Ohio', ci.city_id, '38834'),
       (select estate_type_id from estate_type where type = 'house'),
       'CLOSE TO CAMPUS!!! This multi-level home is just blocks away from OSU Vet Med on a GIANT 100x140 Corner Lot. The yard has white vinyl privacy fence on the south side and new cedar fence on the west. Plenty of parking here, which is rare in this neck of the woods, with a circle drive out front and a 2-car garage with overflow parking facing Arrowhead St. Mature Pecan Trees, recently groomed yard, painted brick, some fresh windows and a new roof wrap up the outside. The assessor shows 1939 sq feet inside +/- with a finished basement but the house has a 3rd story that is heated/cooled as well as the basement footage so please satisfy yourself to the actual footage. Mostly hardwood floors throughout with a real wood burning fireplace and ORIGINAL 1950s countertops. Floor to ceiling original cabinets in the kitchen and updated HVAC is housed in the basement. There are 2 full baths that could use a little TLC but everything is working as it should. Lots of character inside this one with an unbeatable location within the Westwood Overlay District. You could argue this house anywhere from a 3-bed to a 5-bed with 2 full baths, but thats for the new owner to decide. Owner is licensed/active Oklahoma Real Estate Broker/Agent.',
       23490000, -- in cents
       'https://www.zillow.com/homedetails/136-S-Willis-St-Stillwater-OK-74074/224757581_zpid/',
       (select estate_condition_id from estate_condition where condition = 'estate registered')
FROM city ci
         JOIN country co ON co.country_id = ci.country_id
WHERE co.country = 'United States'
  AND ci.city = 'Dayton';


INSERT INTO estate(estate_id, client_id, address_id, estate_type_id, full_description, price, page_url,
                   estate_condition_id)
SELECT 'HO00002',
       (SELECT client_id FROM client WHERE client_type = 1 and name = 'PATRICIA JOHNSON' and email = 'PATRICIA.JOHNSON@sakilacustomer.org'),
       register_address('1866 al-Qatif Avenue', 'California', ci.city_id, '89420'),
       (select estate_type_id from estate_type where type = 'house'),
       'Here it is! Location, size, functionality!! This 4 bed 2 bath home sits on a large lot just off 12th St in Stillwater. This location is fabulous for a family and also has the history of being a great rental property! The second floor of this property boasts a large living room, with fireplace, spacious kitchen with dining room big enough for the whole family, great island with cooktop, built in oven, pantry and more! Four bedrooms including a master suite with full bath with a shower. Second bathroom has a tub/shower combo. The lower level hosts a massive flex room! Think game room, family room, second living area, or even a 5th bedroom if needed. Massive back yard, mature trees, beautiful lot. Call me today to take a look at this fabulous property!',
       22400000, -- in cents
       'https://www.zillow.com/homedetails/1120-S-McDonald-St-Stillwater-OK-74074/244058640_zpid/',
       (select estate_condition_id from estate_condition where condition = 'estate registered')
FROM city ci
         JOIN country co ON co.country_id = ci.country_id
WHERE co.country = 'United States'
  AND ci.city = 'El Monte';


INSERT INTO estate(estate_id, client_id, address_id, estate_type_id, full_description, price, page_url,
                   estate_condition_id)
SELECT 'HO00003',
       (SELECT client_id FROM client WHERE client_type = 1 and name = 'LINDA WILLIAMS' and email = 'LINDA.WILLIAMS@sakilacustomer.org'),
       register_address('1135 Izumisano Parkway', 'California', ci.city_id, '48150'),
       (select estate_type_id from estate_type where type = 'house'),
       '*** IMMEDIATE MOVE-IN *** COMPLETED HOME *** The WRIGHT floor plan is the perfect home for new home owners. This Unique floor plan offers great space where it is needed most. From the Huge master bedroom with included master bath with an enormous walk in closet, to the large covered patio this home is sure to be the perfect home for your family. This home is equipped with a spacious living room that overlooks an incredible kitchen that is perfect for entertaining guests. Kitchen has great counter top space, while having a large area for a good size dining table.',
       19239000, -- in cents
       'https://www.zillow.com/homedetails/1821-E-Moore-Ave-Stillwater-OK-74075/2069807473_zpid/',
       (select estate_condition_id from estate_condition where condition = 'estate registered')
FROM city ci
         JOIN country co ON co.country_id = ci.country_id
WHERE co.country = 'United States'
  AND ci.city = 'Fontana';


INSERT INTO estate(estate_id, client_id, address_id, estate_type_id, full_description, price, page_url,
                   estate_condition_id)
SELECT 'HO00004',
       (SELECT client_id FROM client WHERE client_type = 1 and name = 'BARBARA JONES' and email = 'BARBARA.JONES@sakilacustomer.org'),
       register_address('1895 Zhezqazghan Drive', 'California', ci.city_id, '36693'),
       (select estate_type_id from estate_type where type = 'house'),
       'The charming rc magnolia plan is full of curb appeal with its welcoming front porch and front yard landscaping. This home features an open floor plan with 4 bedrooms, 2 bathrooms, and a large family room. Also enjoy a cozy breakfast/dining area, and a lovely kitchen fully equipped with energy-efficient appliances, ample counter space, and a roomy pantry for snacking and delicious family meals. Plus, a covered back porch for entertaining and relaxing. Learn more about this home today!',
       20190000, -- in cents
       'https://www.zillow.com/community/skyline-east/2067050552_zpid/',
       (select estate_condition_id from estate_condition where condition = 'estate registered')
FROM city ci
         JOIN country co ON co.country_id = ci.country_id
WHERE co.country = 'United States'
  AND ci.city = 'Garden Grove';

-- CREATE CONTRACT:
INSERT INTO contract_type(type, cost)
VALUES ('purchase', 0),
       ('selling',  100000),
       ('leasing', 50000),
       ('renting', 20000);

INSERT INTO payment_type(type, provider)
VALUES ('cash', 'agency'),
       ('bank transfer', 'bank');


-- PURCHASE ESTATE FROM CLIENT:
-- Firstly the condition of estate updated to 'undergoing operation':
WITH cte_update_estate AS (
    update estate set estate_condition_id = (select estate_condition_id from estate_condition where condition = 'estate undergoing operation')
    where estate_id = 'OF00001'
    returning estate_id, client_id, price
),
-- Secondly the contract is created:
    cte_contract AS (
    INSERT INTO contract (contract_type_id, client_id, employee_id, estate_id, details, number_of_payments,
                          payment_amount, contract_date, start_date)
        SELECT (select contract_type_id from contract_type where type = 'purchase'),
               client_id,
               (select employee_id
                from employee
                where condition = 1
                  and first_name = 'TYLER'
                  and last_name = 'NASH'
                  and position_id = (select position_id from position where title = 'real estate manager')),
               estate_id,
               concat('Purchase of estate', ' ', estate_id::text),
               1,
               price + (select cost from contract_type where type = 'purchase'),
               CURRENT_DATE,
               CURRENT_DATE
        FROM cte_update_estate
    RETURNING contract_id, contract_type_id, client_id, payment_amount, estate_id
)
-- Lastly the contract initiates the payment that can be completed later:
INSERT INTO payment (contract_id, contract_type_id, payment_type_id, invoice_id, issued_by, issued_to, amount, details)
SELECT contract_id,
       contract_type_id,
       (select payment_type_id from payment_type where type = 'bank transfer'),
       'PBT00000000001',
       concat('Client:',' ',client_id),
       'AGENCY',
       payment_amount,
       concat('Payment for purchase:',' ',estate_id)
FROM cte_contract;
-- Final condition of estate if set to 'estate bought' when payment was done


-- RENT ESTATE TO CLIENT:
-- Firstly the condition of estate updated to 'undergoing operation':
WITH cte_update_estate AS (
    update estate set estate_condition_id = (select estate_condition_id from estate_condition where condition = 'estate undergoing operation')
    where estate_id = 'HO00001'
    returning estate_id, client_id, price
),
-- Secondly the contract is created:
    cte_contract AS (
    INSERT INTO contract (contract_type_id, client_id, employee_id, estate_id, details, number_of_payments,
                          payment_amount, contract_date, start_date, end_date)
        SELECT (select contract_type_id from contract_type where type = 'renting'),
               (select client_id from client where name = 'BARBARA JONES' and email = 'BARBARA.JONES@sakilacustomer.org'),
               (select employee_id
                from employee
                where condition = 1
                  and first_name = 'AMANDA'
                  and last_name = 'WILLIAMS'
                  and position_id = (select position_id from position where title = 'real estate agent')),
               estate_id,
               concat('Rental of estate', ' ', estate_id::text),
               12,
               (price + (select cost from contract_type where type = 'renting')) / 12,
               CURRENT_DATE,
               CURRENT_DATE + interval '1' month,
               CURRENT_DATE + interval '12' month
        FROM cte_update_estate
    RETURNING contract_id, contract_type_id, client_id, payment_amount, estate_id
)
-- Lastly the contract initiates the payment that can be completed later:
INSERT INTO payment (contract_id, contract_type_id, payment_type_id, invoice_id, issued_by, issued_to, discount, discount_percentage, amount, details)
SELECT contract_id,
       contract_type_id,
       (select payment_type_id from payment_type where type = 'bank transfer'),
       'PRT00000000002',
       'AGENCY',
       concat('Client:',' ',client_id),
       true,
       5,
       payment_amount - (payment_amount / 100 * 5),
       concat('Payment for rental:',' ',estate_id)
FROM cte_contract;
-- Final condition of estate if set to 'estate rented' when payment was done


-- • Function that UPDATEs data in one of your tables
--   (input arguments: table's primary key value, column name and column value to UPDATE to):
CREATE OR REPLACE FUNCTION update_estate_specified_column(IN p_record_id varchar, IN p_colname varchar, IN p_value text)
    RETURNS TEXT
    LANGUAGE plpgsql
AS
$$
DECLARE
    rec record;
BEGIN

    SELECT estate_id INTO STRICT rec FROM agency.estate where estate_id = p_record_id;

    EXECUTE 'UPDATE agency.estate SET ' || quote_ident(p_colname) || ' = ' || quote_literal(p_value)
                || ' WHERE estate_id = ' || quote_literal(p_record_id) || ';';
    RETURN FORMAT('COLUMN %s IN ESTATE TABLE WAS UPDATED', p_colname);

EXCEPTION
    WHEN no_data_found THEN RETURN FORMAT('THERE IS NO SUCH ESTATE WITH ID %s', p_record_id);
    WHEN others THEN RETURN FORMAT('ERROR !!! COLUMN %s IN ESTATE TABLE WAS NOT UPDATED', p_colname);
END;
$$;

SELECT update_estate_specified_column('HO00001', 'full_description', 'no description');


-- • Function that adds new transaction to transaction table:
CREATE OR REPLACE FUNCTION sell_estate(IN p_estate_id varchar, IN p_client_name text, IN p_client_email text,
                                       IN p_emp_first_name varchar, IN p_emp_last_name varchar, IN p_price bigint,
                                       IN p_payment_method text, IN p_invoice_id text, IN is_discount boolean,
                                       IN p_discount_percentage int)
    RETURNS TEXT
    LANGUAGE plpgsql
AS
$$
DECLARE
    rec record;
    v_client_id           int;
    v_emp_id              int;
    v_estate_condition_id smallint;
    v_contract_type_id    smallint;
    v_number_of_payment   smallint := 1;
    v_operation_cost      bigint;
    v_contract_id         int;
    v_payment_type_id     smallint;
    v_contract_pay_amount bigint;
BEGIN
    SELECT estate_id INTO STRICT rec FROM agency.estate WHERE estate_id = p_estate_id;
    SELECT client_id INTO STRICT v_client_id FROM agency.client WHERE name = p_client_name AND email = p_client_email;
    SELECT employee_id INTO STRICT v_emp_id FROM agency.employee WHERE condition = 1
      AND first_name = p_emp_first_name
      AND last_name = p_emp_last_name
      AND position_id = (select position_id
                         from agency.position
                         where title = 'real estate manager');
    SELECT estate_condition_id INTO STRICT v_estate_condition_id FROM agency.estate_condition WHERE condition = 'estate undergoing operation';
    SELECT contract_type_id INTO STRICT v_contract_type_id FROM agency.contract_type WHERE type = 'selling';
    SELECT cost INTO STRICT v_operation_cost FROM agency.contract_type WHERE type = 'selling';
    SELECT payment_type_id INTO STRICT v_payment_type_id FROM agency.payment_type WHERE type = p_payment_method;
    v_contract_pay_amount := p_price + v_operation_cost;

    -- Firstly the condition of estate updated to 'undergoing operation':
    UPDATE agency.estate SET estate_condition_id = v_estate_condition_id WHERE estate_id = p_estate_id;
    -- Secondly the contract is created:
    INSERT INTO agency.contract (contract_type_id, client_id, employee_id, estate_id, details, number_of_payments,
                                 payment_amount, contract_date, start_date)
    VALUES (v_contract_type_id,
            v_client_id,
            v_emp_id,
            p_estate_id,
            concat('Selling of estate', ' ', p_estate_id::text),
            v_number_of_payment,
            v_contract_pay_amount,
            CURRENT_DATE,
            CURRENT_DATE)
    returning contract_id into v_contract_id;
    -- Lastly the contract initiates the payment that can be completed later:
    INSERT INTO agency.payment (contract_id, contract_type_id, payment_type_id, invoice_id, issued_by, issued_to, discount,
                         discount_percentage, amount, details)
    values (v_contract_id,
            v_contract_type_id,
            v_payment_type_id,
            p_invoice_id,
            'AGENCY',
            concat('Client:', ' ', v_client_id),
            is_discount,
            p_discount_percentage,
            case
                when is_discount = true then v_contract_pay_amount -
                                             (v_contract_pay_amount / 100 * p_discount_percentage)
                else v_contract_pay_amount
                end,
            concat('Payment for buying:', ' ', p_estate_id, ' by ', v_client_id));

    RETURN FORMAT('OPERATION ON ESTATE %s WAS FINISHED', p_estate_id);

    EXCEPTION
    WHEN no_data_found THEN RETURN 'THERE IS NO SUCH DATA';
    WHEN others THEN RETURN 'ERROR !!!';

END;
$$;

SELECT sell_estate('HO00002', 'LINDA WILLIAMS', 'LINDA.WILLIAMS@sakilacustomer.org', 'TYLER', 'NASH', 10000,
    'cash', 'PSC00000000001', true, 20);





