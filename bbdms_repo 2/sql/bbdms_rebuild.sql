
-- BLOOD BANK & DONOR MANAGEMENT SYSTEM (BBDMS)
-- Complete rebuild script — runs against the BBDMS user in FREEPDB1
-- ----------------------------------------------------------------------------
-- Course:   UCS310 — Database Management Systems
-- Author :  Devansh Gupta, Matreyi Suryan, Ayati Gupta
-- DBMS:     Oracle Database 23ai Free
-- ----------------------------------------------------------------------------
-- Usage:
--   1. Connect to your bbdms user in DBeaver / SQL*Plus
--   2. Run this entire file
--   3. The schema, all PL/SQL objects, and seed data will be rebuilt


-- ====================== SECTION 0: CLEAN SLATE =============================
-- Drop in reverse dependency order. Each is wrapped in a PL/SQL block so a
-- missing object does not abort the script.

BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_audit_issuance';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_audit_unit';            EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_audit_donor';           EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_unit_release';          EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TRIGGER trg_donation_eligibility';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE issue_unit';              EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP PROCEDURE register_donor';          EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP FUNCTION get_compatible_groups';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP FUNCTION donor_eligible';           EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP FUNCTION calc_expiry_date';         EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN EXECUTE IMMEDIATE 'DROP TABLE audit_log CASCADE CONSTRAINTS';            EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE issuance CASCADE CONSTRAINTS';             EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE request CASCADE CONSTRAINTS';              EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE recipient CASCADE CONSTRAINTS';            EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE screening CASCADE CONSTRAINTS';            EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE blood_unit CASCADE CONSTRAINTS';           EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE donation CASCADE CONSTRAINTS';             EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE blood_compatibility CASCADE CONSTRAINTS';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE hospital CASCADE CONSTRAINTS';             EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE donor CASCADE CONSTRAINTS';                EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE staff CASCADE CONSTRAINTS';                EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP TABLE component CASCADE CONSTRAINTS';            EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE audit_seq';      EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE issuance_seq';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE request_seq';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE recipient_seq';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE screening_seq';  EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE unit_seq';       EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE donation_seq';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE hospital_seq';   EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE donor_seq';      EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP SEQUENCE staff_seq';      EXCEPTION WHEN OTHERS THEN NULL; END;
/

-- ====================== SECTION 1: TABLES ===================================

CREATE TABLE component (
    component_id      NUMBER(3)      PRIMARY KEY,
    name              VARCHAR2(50)   NOT NULL UNIQUE,
    shelf_life_days   NUMBER(4)      NOT NULL,
    storage_temp_min  NUMBER(4,1)    NOT NULL,
    storage_temp_max  NUMBER(4,1)    NOT NULL,
    description       VARCHAR2(200),
    CONSTRAINT chk_component_shelf  CHECK (shelf_life_days BETWEEN 1 AND 400),
    CONSTRAINT chk_component_temp   CHECK (storage_temp_min < storage_temp_max)
);

CREATE TABLE staff (
    staff_id      NUMBER(5)        PRIMARY KEY,
    full_name     VARCHAR2(100)    NOT NULL,
    role          VARCHAR2(20)     NOT NULL,
    contact       VARCHAR2(20),
    login_id      VARCHAR2(30)     NOT NULL UNIQUE,
    hired_on      DATE             DEFAULT SYSDATE NOT NULL,
    is_active     CHAR(1)          DEFAULT 'Y' NOT NULL,
    CONSTRAINT chk_staff_role     CHECK (role IN ('ADMIN','RECEPTION','LAB','ISSUE','AUDITOR')),
    CONSTRAINT chk_staff_active   CHECK (is_active IN ('Y','N'))
);

CREATE TABLE donor (
    donor_id              NUMBER(7)        PRIMARY KEY,
    full_name             VARCHAR2(100)    NOT NULL,
    dob                   DATE             NOT NULL,
    gender                CHAR(1)          NOT NULL,
    blood_group           VARCHAR2(3)      NOT NULL,
    contact               VARCHAR2(20)     NOT NULL,
    email                 VARCHAR2(100),
    address               VARCHAR2(300),
    last_donation_date    DATE,
    registered_on         DATE             DEFAULT SYSDATE NOT NULL,
    is_active             CHAR(1)          DEFAULT 'Y' NOT NULL,
    CONSTRAINT chk_donor_gender       CHECK (gender IN ('M','F','O')),
    CONSTRAINT chk_donor_blood_group  CHECK (blood_group IN ('O+','O-','A+','A-','B+','B-','AB+','AB-')),
    CONSTRAINT chk_donor_active       CHECK (is_active IN ('Y','N')),
    CONSTRAINT chk_donor_age          CHECK (MONTHS_BETWEEN(SYSDATE, dob) BETWEEN 18*12 AND 65*12),
    CONSTRAINT chk_donor_dob_past     CHECK (dob < SYSDATE)
);

CREATE TABLE hospital (
    hospital_id     NUMBER(5)        PRIMARY KEY,
    name            VARCHAR2(150)    NOT NULL,
    address         VARCHAR2(300)    NOT NULL,
    city            VARCHAR2(50)     NOT NULL,
    contact         VARCHAR2(20)     NOT NULL,
    license_no      VARCHAR2(30)     NOT NULL UNIQUE,
    is_active       CHAR(1)          DEFAULT 'Y' NOT NULL,
    registered_on   DATE             DEFAULT SYSDATE NOT NULL,
    CONSTRAINT chk_hospital_active CHECK (is_active IN ('Y','N'))
);

CREATE TABLE donation (
    donation_id        NUMBER(8)        PRIMARY KEY,
    donor_id           NUMBER(7)        NOT NULL,
    staff_id           NUMBER(5)        NOT NULL,
    donation_date      DATE             DEFAULT SYSDATE NOT NULL,
    volume_ml          NUMBER(4)        NOT NULL,
    notes              VARCHAR2(300),
    CONSTRAINT fk_donation_donor  FOREIGN KEY (donor_id) REFERENCES donor(donor_id),
    CONSTRAINT fk_donation_staff  FOREIGN KEY (staff_id) REFERENCES staff(staff_id),
    CONSTRAINT chk_donation_volume CHECK (volume_ml BETWEEN 200 AND 500),
    CONSTRAINT chk_donation_date_not_future CHECK (donation_date <= SYSDATE)
);

CREATE TABLE blood_unit (
    unit_id           NUMBER(9)        PRIMARY KEY,
    donation_id       NUMBER(8)        NOT NULL,
    component_id      NUMBER(3)        NOT NULL,
    collection_date   DATE             DEFAULT SYSDATE NOT NULL,
    expiry_date       DATE             NOT NULL,
    status            VARCHAR2(15)     DEFAULT 'QUARANTINE' NOT NULL,
    storage_location  VARCHAR2(50),
    CONSTRAINT fk_unit_donation   FOREIGN KEY (donation_id)  REFERENCES donation(donation_id),
    CONSTRAINT fk_unit_component  FOREIGN KEY (component_id) REFERENCES component(component_id),
    CONSTRAINT chk_unit_status    CHECK (status IN ('QUARANTINE','AVAILABLE','RESERVED','ISSUED','EXPIRED','DISCARDED')),
    CONSTRAINT chk_unit_expiry    CHECK (expiry_date > collection_date)
);

CREATE TABLE screening (
    screening_id     NUMBER(9)        PRIMARY KEY,
    unit_id          NUMBER(9)        NOT NULL UNIQUE,
    hiv              VARCHAR2(10)     NOT NULL,
    hbv              VARCHAR2(10)     NOT NULL,
    hcv              VARCHAR2(10)     NOT NULL,
    syphilis         VARCHAR2(10)     NOT NULL,
    malaria          VARCHAR2(10)     NOT NULL,
    tested_on        DATE             DEFAULT SYSDATE NOT NULL,
    tested_by        NUMBER(5)        NOT NULL,
    CONSTRAINT fk_screening_unit  FOREIGN KEY (unit_id)   REFERENCES blood_unit(unit_id),
    CONSTRAINT fk_screening_staff FOREIGN KEY (tested_by) REFERENCES staff(staff_id),
    CONSTRAINT chk_screen_hiv      CHECK (hiv      IN ('NEGATIVE','POSITIVE','PENDING')),
    CONSTRAINT chk_screen_hbv      CHECK (hbv      IN ('NEGATIVE','POSITIVE','PENDING')),
    CONSTRAINT chk_screen_hcv      CHECK (hcv      IN ('NEGATIVE','POSITIVE','PENDING')),
    CONSTRAINT chk_screen_syphilis CHECK (syphilis IN ('NEGATIVE','POSITIVE','PENDING')),
    CONSTRAINT chk_screen_malaria  CHECK (malaria  IN ('NEGATIVE','POSITIVE','PENDING'))
);

CREATE TABLE recipient (
    recipient_id     NUMBER(7)        PRIMARY KEY,
    full_name        VARCHAR2(100)    NOT NULL,
    dob              DATE             NOT NULL,
    gender           CHAR(1)          NOT NULL,
    blood_group      VARCHAR2(3)      NOT NULL,
    hospital_id      NUMBER(5)        NOT NULL,
    contact          VARCHAR2(20),
    registered_on    DATE             DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_recipient_hospital  FOREIGN KEY (hospital_id) REFERENCES hospital(hospital_id),
    CONSTRAINT chk_recipient_gender   CHECK (gender IN ('M','F','O')),
    CONSTRAINT chk_recipient_bg       CHECK (blood_group IN ('O+','O-','A+','A-','B+','B-','AB+','AB-')),
    CONSTRAINT chk_recipient_dob      CHECK (dob < SYSDATE)
);

CREATE TABLE request (
    request_id       NUMBER(8)        PRIMARY KEY,
    recipient_id     NUMBER(7)        NOT NULL,
    component_id     NUMBER(3)        NOT NULL,
    units_needed     NUMBER(3)        NOT NULL,
    urgency          VARCHAR2(10)     DEFAULT 'ROUTINE' NOT NULL,
    request_date     DATE             DEFAULT SYSDATE NOT NULL,
    status           VARCHAR2(15)     DEFAULT 'OPEN' NOT NULL,
    CONSTRAINT fk_request_recipient  FOREIGN KEY (recipient_id) REFERENCES recipient(recipient_id),
    CONSTRAINT fk_request_component  FOREIGN KEY (component_id) REFERENCES component(component_id),
    CONSTRAINT chk_request_units    CHECK (units_needed BETWEEN 1 AND 20),
    CONSTRAINT chk_request_urgency  CHECK (urgency IN ('ROUTINE','URGENT','EMERGENCY')),
    CONSTRAINT chk_request_status   CHECK (status IN ('OPEN','PARTIAL','FULFILLED','CANCELLED'))
);

CREATE TABLE issuance (
    issuance_id      NUMBER(9)        PRIMARY KEY,
    request_id       NUMBER(8)        NOT NULL,
    unit_id          NUMBER(9)        NOT NULL UNIQUE,
    issued_on        DATE             DEFAULT SYSDATE NOT NULL,
    issued_by        NUMBER(5)        NOT NULL,
    notes            VARCHAR2(200),
    CONSTRAINT fk_issuance_request FOREIGN KEY (request_id) REFERENCES request(request_id),
    CONSTRAINT fk_issuance_unit    FOREIGN KEY (unit_id)    REFERENCES blood_unit(unit_id),
    CONSTRAINT fk_issuance_staff   FOREIGN KEY (issued_by)  REFERENCES staff(staff_id)
);

CREATE TABLE audit_log (
    audit_id         NUMBER(10)       PRIMARY KEY,
    table_name       VARCHAR2(30)     NOT NULL,
    op_type          VARCHAR2(10)     NOT NULL,
    record_pk        VARCHAR2(50),
    old_value        VARCHAR2(500),
    new_value        VARCHAR2(500),
    changed_by       VARCHAR2(30)     DEFAULT USER NOT NULL,
    changed_at       TIMESTAMP        DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT chk_audit_op CHECK (op_type IN ('INSERT','UPDATE','DELETE','ERROR'))
);

CREATE TABLE blood_compatibility (
    recipient_group VARCHAR2(3) NOT NULL,
    donor_group     VARCHAR2(3) NOT NULL,
    PRIMARY KEY (recipient_group, donor_group)
);

-- ====================== SECTION 2: SEQUENCES ================================

CREATE SEQUENCE staff_seq      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE donor_seq      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE hospital_seq   START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE donation_seq   START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE unit_seq       START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE screening_seq  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE recipient_seq  START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE request_seq    START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE issuance_seq   START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;
CREATE SEQUENCE audit_seq      START WITH 1 INCREMENT BY 1 NOCACHE NOCYCLE;

-- ====================== SECTION 3: SEED REFERENCE DATA ======================

INSERT INTO component VALUES (1, 'Whole Blood',            35,   2.0,   6.0, 'Unseparated blood, refrigerated.');
INSERT INTO component VALUES (2, 'Packed Red Blood Cells', 42,   2.0,   6.0, 'Most commonly transfused component.');
INSERT INTO component VALUES (3, 'Platelets',               5,  20.0,  24.0, 'Room temperature, with continuous agitation.');
INSERT INTO component VALUES (4, 'Fresh Frozen Plasma',   365, -30.0, -25.0, 'Frozen within 8 hours of collection.');
INSERT INTO component VALUES (5, 'Cryoprecipitate',       365, -30.0, -25.0, 'Cold-precipitated plasma fraction.');

-- Blood compatibility matrix (recipient_group → donor_group)
INSERT INTO blood_compatibility VALUES ('O+',  'O+');
INSERT INTO blood_compatibility VALUES ('O+',  'O-');
INSERT INTO blood_compatibility VALUES ('O+',  'A+');
INSERT INTO blood_compatibility VALUES ('O+',  'A-');
INSERT INTO blood_compatibility VALUES ('O+',  'B+');
INSERT INTO blood_compatibility VALUES ('O+',  'B-');
INSERT INTO blood_compatibility VALUES ('O+',  'AB+');
INSERT INTO blood_compatibility VALUES ('O+',  'AB-');
INSERT INTO blood_compatibility VALUES ('O-',  'O-');
INSERT INTO blood_compatibility VALUES ('A+',  'A+');
INSERT INTO blood_compatibility VALUES ('A+',  'A-');
INSERT INTO blood_compatibility VALUES ('A+',  'O+');
INSERT INTO blood_compatibility VALUES ('A+',  'O-');
INSERT INTO blood_compatibility VALUES ('A-',  'A-');
INSERT INTO blood_compatibility VALUES ('A-',  'O-');
INSERT INTO blood_compatibility VALUES ('B+',  'B+');
INSERT INTO blood_compatibility VALUES ('B+',  'B-');
INSERT INTO blood_compatibility VALUES ('B+',  'O+');
INSERT INTO blood_compatibility VALUES ('B+',  'O-');
INSERT INTO blood_compatibility VALUES ('B-',  'B-');
INSERT INTO blood_compatibility VALUES ('B-',  'O-');
INSERT INTO blood_compatibility VALUES ('AB+', 'AB+');
INSERT INTO blood_compatibility VALUES ('AB+', 'AB-');
INSERT INTO blood_compatibility VALUES ('AB+', 'A+');
INSERT INTO blood_compatibility VALUES ('AB+', 'A-');
INSERT INTO blood_compatibility VALUES ('AB+', 'B+');
INSERT INTO blood_compatibility VALUES ('AB+', 'B-');
INSERT INTO blood_compatibility VALUES ('AB+', 'O+');
INSERT INTO blood_compatibility VALUES ('AB+', 'O-');
INSERT INTO blood_compatibility VALUES ('AB-', 'AB-');
INSERT INTO blood_compatibility VALUES ('AB-', 'A-');
INSERT INTO blood_compatibility VALUES ('AB-', 'B-');
INSERT INTO blood_compatibility VALUES ('AB-', 'O-');

COMMIT;

-- ====================== SECTION 4: SEED OPERATIONAL DATA ====================

-- Staff
INSERT INTO staff VALUES (staff_seq.NEXTVAL, 'Anita Sharma',  'ADMIN',     '+91-9876500001', 'asharma', SYSDATE, 'Y');
INSERT INTO staff VALUES (staff_seq.NEXTVAL, 'Rahul Mehta',   'RECEPTION', '+91-9876500002', 'rmehta',  SYSDATE, 'Y');
INSERT INTO staff VALUES (staff_seq.NEXTVAL, 'Priya Iyer',    'LAB',       '+91-9876500003', 'piyer',   SYSDATE, 'Y');
INSERT INTO staff VALUES (staff_seq.NEXTVAL, 'Vikram Singh',  'ISSUE',     '+91-9876500004', 'vsingh',  SYSDATE, 'Y');
INSERT INTO staff VALUES (staff_seq.NEXTVAL, 'Meera Nair',    'AUDITOR',   '+91-9876500005', 'mnair',   SYSDATE, 'Y');

-- Donors (10, varied blood groups)
INSERT INTO donor (donor_id, full_name, dob, gender, blood_group, contact, email)
VALUES (donor_seq.NEXTVAL, 'Arjun Kapoor',   DATE '1990-03-15', 'M', 'O+',  '+91-9876510001', 'arjun.k@email.com');
INSERT INTO donor (donor_id, full_name, dob, gender, blood_group, contact, email)
VALUES (donor_seq.NEXTVAL, 'Sneha Patel',    DATE '1995-07-22', 'F', 'A+',  '+91-9876510002', 'sneha.p@email.com');
INSERT INTO donor (donor_id, full_name, dob, gender, blood_group, contact, email)
VALUES (donor_seq.NEXTVAL, 'Rohan Desai',    DATE '1988-11-30', 'M', 'B+',  '+91-9876510003', 'rohan.d@email.com');
INSERT INTO donor (donor_id, full_name, dob, gender, blood_group, contact, email)
VALUES (donor_seq.NEXTVAL, 'Kavya Reddy',    DATE '1992-05-10', 'F', 'AB+', '+91-9876510004', 'kavya.r@email.com');
INSERT INTO donor (donor_id, full_name, dob, gender, blood_group, contact, email)
VALUES (donor_seq.NEXTVAL, 'Aditya Joshi',   DATE '1985-02-18', 'M', 'O-',  '+91-9876510005', 'aditya.j@email.com');
INSERT INTO donor (donor_id, full_name, dob, gender, blood_group, contact, email)
VALUES (donor_seq.NEXTVAL, 'Pooja Verma',    DATE '1998-09-05', 'F', 'A-',  '+91-9876510006', 'pooja.v@email.com');
INSERT INTO donor (donor_id, full_name, dob, gender, blood_group, contact, email)
VALUES (donor_seq.NEXTVAL, 'Karan Malhotra', DATE '1991-12-01', 'M', 'B-',  '+91-9876510007', 'karan.m@email.com');
INSERT INTO donor (donor_id, full_name, dob, gender, blood_group, contact, email)
VALUES (donor_seq.NEXTVAL, 'Riya Bhatt',     DATE '1996-04-25', 'F', 'AB-', '+91-9876510008', 'riya.b@email.com');
INSERT INTO donor (donor_id, full_name, dob, gender, blood_group, contact, email)
VALUES (donor_seq.NEXTVAL, 'Sameer Shah',    DATE '1987-08-14', 'M', 'O+',  '+91-9876510009', 'sameer.s@email.com');
INSERT INTO donor (donor_id, full_name, dob, gender, blood_group, contact, email)
VALUES (donor_seq.NEXTVAL, 'Tanvi Khanna',   DATE '1993-06-20', 'F', 'A+',  '+91-9876510010', 'tanvi.k@email.com');

-- Hospitals
INSERT INTO hospital (hospital_id, name, address, city, contact, license_no)
VALUES (hospital_seq.NEXTVAL, 'Apollo Hospitals',  '21 Greams Lane',     'Chennai',    '+91-4428290200', 'TN-DL-2018-04421');
INSERT INTO hospital (hospital_id, name, address, city, contact, license_no)
VALUES (hospital_seq.NEXTVAL, 'Fortis Memorial',   'Sector 44, Gurgaon', 'Gurugram',   '+91-1244921021', 'HR-DL-2019-08832');
INSERT INTO hospital (hospital_id, name, address, city, contact, license_no)
VALUES (hospital_seq.NEXTVAL, 'AIIMS New Delhi',   'Ansari Nagar',       'New Delhi',  '+91-1126588500', 'DL-DL-2017-01102');
INSERT INTO hospital (hospital_id, name, address, city, contact, license_no)
VALUES (hospital_seq.NEXTVAL, 'PGIMER Chandigarh', 'Sector 12',          'Chandigarh', '+91-1722755555', 'CH-DL-2016-00071');
INSERT INTO hospital (hospital_id, name, address, city, contact, license_no)
VALUES (hospital_seq.NEXTVAL, 'Manipal Hospital',  'HAL Airport Road',   'Bengaluru',  '+91-8025023300', 'KA-DL-2020-12091');

-- Donations spanning the past year
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 1,  2, DATE '2025-04-15', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 2,  2, DATE '2025-05-10', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 3,  2, DATE '2025-06-22', 450);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 4,  2, DATE '2025-08-05', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 5,  2, DATE '2025-09-12', 450);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 1,  2, DATE '2025-10-20', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 6,  2, DATE '2025-11-08', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 7,  2, DATE '2025-12-15', 450);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 8,  2, DATE '2026-02-18', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 9,  2, DATE '2026-03-05', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 10, 2, DATE '2026-03-25', 450);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 2,  2, DATE '2026-04-01', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 3,  2, DATE '2026-04-05', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 5,  2, DATE '2026-04-08', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 7,  2, DATE '2026-04-10', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 1,  2, DATE '2026-04-12', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 4,  2, DATE '2026-04-14', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 6,  2, DATE '2026-04-16', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 8,  2, DATE '2026-04-18', 350);
INSERT INTO donation (donation_id, donor_id, staff_id, donation_date, volume_ml) VALUES (donation_seq.NEXTVAL, 9,  2, DATE '2026-04-20', 350);

-- Refresh donor.last_donation_date
UPDATE donor d SET last_donation_date = (SELECT MAX(donation_date) FROM donation WHERE donor_id = d.donor_id);

-- BloodUnit per donation (status auto-set from expiry date)
INSERT INTO blood_unit (unit_id, donation_id, component_id, collection_date, expiry_date, status, storage_location)
SELECT unit_seq.NEXTVAL, d.donation_id, 2, d.donation_date, d.donation_date + 42,
       CASE WHEN d.donation_date + 42 < SYSDATE THEN 'EXPIRED' ELSE 'AVAILABLE' END,
       'Fridge-A-Shelf-' || (MOD(d.donation_id, 4) + 1)
FROM donation d ORDER BY d.donation_id;

-- Screening for every unit (all clean)
INSERT INTO screening (screening_id, unit_id, hiv, hbv, hcv, syphilis, malaria, tested_on, tested_by)
SELECT screening_seq.NEXTVAL, bu.unit_id, 'NEGATIVE','NEGATIVE','NEGATIVE','NEGATIVE','NEGATIVE',
       bu.collection_date + 1, 3
FROM blood_unit bu;

-- Recipients
INSERT INTO recipient (recipient_id, full_name, dob, gender, blood_group, hospital_id, contact)
VALUES (recipient_seq.NEXTVAL, 'Patient Ramesh',  DATE '1965-08-12', 'M', 'O+',  1, '+91-9876520001');
INSERT INTO recipient (recipient_id, full_name, dob, gender, blood_group, hospital_id, contact)
VALUES (recipient_seq.NEXTVAL, 'Patient Lakshmi', DATE '1972-03-22', 'F', 'A+',  1, '+91-9876520002');
INSERT INTO recipient (recipient_id, full_name, dob, gender, blood_group, hospital_id, contact)
VALUES (recipient_seq.NEXTVAL, 'Patient Suresh',  DATE '1955-11-04', 'M', 'B+',  2, '+91-9876520003');
INSERT INTO recipient (recipient_id, full_name, dob, gender, blood_group, hospital_id, contact)
VALUES (recipient_seq.NEXTVAL, 'Patient Geeta',   DATE '1980-06-30', 'F', 'AB+', 3, '+91-9876520004');
INSERT INTO recipient (recipient_id, full_name, dob, gender, blood_group, hospital_id, contact)
VALUES (recipient_seq.NEXTVAL, 'Patient Anil',    DATE '1962-09-18', 'M', 'O-',  4, '+91-9876520005');
INSERT INTO recipient (recipient_id, full_name, dob, gender, blood_group, hospital_id, contact)
VALUES (recipient_seq.NEXTVAL, 'Patient Maya',    DATE '1985-12-10', 'F', 'A-',  5, '+91-9876520006');

-- Open requests (mix of urgencies)
INSERT INTO request (request_id, recipient_id, component_id, units_needed, urgency, request_date, status)
VALUES (request_seq.NEXTVAL, 1, 2, 2, 'ROUTINE',   DATE '2026-04-22', 'OPEN');
INSERT INTO request (request_id, recipient_id, component_id, units_needed, urgency, request_date, status)
VALUES (request_seq.NEXTVAL, 2, 2, 1, 'URGENT',    DATE '2026-04-23', 'OPEN');
INSERT INTO request (request_id, recipient_id, component_id, units_needed, urgency, request_date, status)
VALUES (request_seq.NEXTVAL, 3, 2, 1, 'EMERGENCY', DATE '2026-04-24', 'OPEN');
INSERT INTO request (request_id, recipient_id, component_id, units_needed, urgency, request_date, status)
VALUES (request_seq.NEXTVAL, 4, 2, 1, 'ROUTINE',   DATE '2026-04-24', 'OPEN');
INSERT INTO request (request_id, recipient_id, component_id, units_needed, urgency, request_date, status)
VALUES (request_seq.NEXTVAL, 5, 2, 1, 'URGENT',    DATE '2026-04-25', 'OPEN');

COMMIT;

-- ====================== SECTION 5: FUNCTIONS ================================

CREATE OR REPLACE FUNCTION calc_expiry_date(
    p_component_id    IN NUMBER,
    p_collection_date IN DATE
) RETURN DATE IS
    v_shelf_life NUMBER;
BEGIN
    SELECT shelf_life_days INTO v_shelf_life FROM component WHERE component_id = p_component_id;
    RETURN p_collection_date + v_shelf_life;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
    WHEN OTHERS THEN RETURN NULL;
END;
/

CREATE OR REPLACE FUNCTION donor_eligible(
    p_donor_id IN NUMBER
) RETURN VARCHAR2 IS                       -- VARCHAR2 instead of BOOLEAN so SQL can call it
    v_last_donation_date DATE;
BEGIN
    SELECT last_donation_date INTO v_last_donation_date FROM donor WHERE donor_id = p_donor_id;
    IF v_last_donation_date IS NULL THEN RETURN 'ELIGIBLE';
    ELSIF TRUNC(SYSDATE) - TRUNC(v_last_donation_date) >= 90 THEN RETURN 'ELIGIBLE';
    ELSE RETURN 'NOT_YET_ELIGIBLE';
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN 'NOT_FOUND';
END;
/

CREATE OR REPLACE FUNCTION get_compatible_groups(
    p_recipient_group IN VARCHAR2
) RETURN VARCHAR2 IS
    v_list VARCHAR2(500);
BEGIN
    SELECT LISTAGG(donor_group, ', ') WITHIN GROUP (ORDER BY donor_group)
    INTO v_list FROM blood_compatibility WHERE recipient_group = p_recipient_group;
    RETURN v_list;
EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN NULL;
END;
/

-- ====================== SECTION 6: PROCEDURES ===============================

CREATE OR REPLACE PROCEDURE register_donor(
    p_full_name    IN VARCHAR2,
    p_dob          IN DATE,
    p_gender       IN CHAR,
    p_blood_group  IN VARCHAR2,
    p_contact      IN VARCHAR2,
    p_email        IN VARCHAR2 DEFAULT NULL,
    p_address      IN VARCHAR2 DEFAULT NULL,
    p_donor_id     OUT NUMBER
) IS
    v_age_months NUMBER;
BEGIN
    v_age_months := MONTHS_BETWEEN(SYSDATE, p_dob);
    IF v_age_months < 18*12 OR v_age_months > 65*12 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Donor age must be between 18 and 65 years');
    END IF;
    IF p_blood_group NOT IN ('O+','O-','A+','A-','B+','B-','AB+','AB-') THEN
        RAISE_APPLICATION_ERROR(-20002, 'Invalid blood group: ' || p_blood_group);
    END IF;
    IF p_gender NOT IN ('M','F','O') THEN
        RAISE_APPLICATION_ERROR(-20003, 'Invalid gender: ' || p_gender);
    END IF;

    p_donor_id := donor_seq.NEXTVAL;
    INSERT INTO donor (donor_id, full_name, dob, gender, blood_group, contact, email, address)
    VALUES (p_donor_id, p_full_name, p_dob, p_gender, p_blood_group, p_contact, p_email, p_address);
    COMMIT;
EXCEPTION
    WHEN OTHERS THEN ROLLBACK; RAISE;
END;
/

CREATE OR REPLACE PROCEDURE issue_unit(
    p_request_id IN NUMBER,
    p_unit_id    IN NUMBER,
    p_staff_id   IN NUMBER
) IS
    v_unit_status     VARCHAR2(15);
    v_recipient_bg    VARCHAR2(3);
    v_donor_bg        VARCHAR2(3);
    v_compatible_list VARCHAR2(500);
BEGIN
    -- 1. Lock the unit row
    SELECT status INTO v_unit_status FROM blood_unit WHERE unit_id = p_unit_id FOR UPDATE NOWAIT;

    -- 2. Status must be AVAILABLE
    IF v_unit_status != 'AVAILABLE' THEN
        RAISE_APPLICATION_ERROR(-20011, 'Unit status is ' || v_unit_status || '; cannot issue');
    END IF;

    -- 3. Recipient blood group
    SELECT rec.blood_group INTO v_recipient_bg
    FROM recipient rec
    WHERE rec.recipient_id = (SELECT recipient_id FROM request WHERE request_id = p_request_id);

    -- 4. Donor blood group
    SELECT d.blood_group INTO v_donor_bg
    FROM donor d
    WHERE d.donor_id = (SELECT don.donor_id FROM donation don
                        WHERE don.donation_id = (SELECT bu.donation_id FROM blood_unit bu WHERE bu.unit_id = p_unit_id));

    -- 5. Compatibility
    v_compatible_list := get_compatible_groups(v_recipient_bg);
    IF INSTR(v_compatible_list, v_donor_bg) = 0 THEN
        RAISE_APPLICATION_ERROR(-20012, 'Group mismatch: recipient ' || v_recipient_bg || ' cannot receive from donor ' || v_donor_bg);
    END IF;

    -- 6+7. Atomic insert + update
    INSERT INTO issuance (issuance_id, request_id, unit_id, issued_on, issued_by)
    VALUES (issuance_seq.NEXTVAL, p_request_id, p_unit_id, SYSDATE, p_staff_id);

    UPDATE blood_unit SET status = 'ISSUED' WHERE unit_id = p_unit_id;

    COMMIT;
EXCEPTION
    WHEN OTHERS THEN ROLLBACK; RAISE;
END;
/

-- ====================== SECTION 7: TRIGGERS =================================

CREATE OR REPLACE TRIGGER trg_donation_eligibility
BEFORE INSERT ON donation
FOR EACH ROW
DECLARE
    v_last_date DATE;
BEGIN
    SELECT last_donation_date INTO v_last_date FROM donor WHERE donor_id = :NEW.donor_id;
    IF v_last_date IS NOT NULL AND TRUNC(SYSDATE) - TRUNC(v_last_date) < 90 THEN
        RAISE_APPLICATION_ERROR(-20020, 'Donor ' || :NEW.donor_id || ' is within 90-day deferral period');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_unit_release
AFTER UPDATE ON screening
FOR EACH ROW
BEGIN
    IF :NEW.hiv = 'NEGATIVE' AND :NEW.hbv = 'NEGATIVE' AND :NEW.hcv = 'NEGATIVE'
       AND :NEW.syphilis = 'NEGATIVE' AND :NEW.malaria = 'NEGATIVE' THEN
        UPDATE blood_unit SET status = 'AVAILABLE'
        WHERE unit_id = :NEW.unit_id AND status = 'QUARANTINE';
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_audit_donor
AFTER INSERT OR UPDATE ON donor
FOR EACH ROW
DECLARE
    v_audit_id NUMBER;
    v_op       VARCHAR2(10);
BEGIN
    SELECT audit_seq.NEXTVAL INTO v_audit_id FROM dual;
    IF INSERTING THEN v_op := 'INSERT'; ELSE v_op := 'UPDATE'; END IF;
    INSERT INTO audit_log (audit_id, table_name, op_type, record_pk, old_value, new_value, changed_by)
    VALUES (v_audit_id, 'donor', v_op, TO_CHAR(:NEW.donor_id),
            CASE WHEN UPDATING THEN :OLD.full_name ELSE NULL END,
            :NEW.full_name, USER);
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE OR REPLACE TRIGGER trg_audit_unit
AFTER INSERT OR UPDATE ON blood_unit
FOR EACH ROW
DECLARE
    v_audit_id NUMBER;
    v_op       VARCHAR2(10);
BEGIN
    SELECT audit_seq.NEXTVAL INTO v_audit_id FROM dual;
    IF INSERTING THEN v_op := 'INSERT'; ELSE v_op := 'UPDATE'; END IF;
    INSERT INTO audit_log (audit_id, table_name, op_type, record_pk, old_value, new_value, changed_by)
    VALUES (v_audit_id, 'blood_unit', v_op, TO_CHAR(:NEW.unit_id),
            CASE WHEN UPDATING THEN :OLD.status ELSE NULL END,
            :NEW.status, USER);
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE OR REPLACE TRIGGER trg_audit_issuance
AFTER INSERT ON issuance
FOR EACH ROW
DECLARE
    v_audit_id NUMBER;
BEGIN
    SELECT audit_seq.NEXTVAL INTO v_audit_id FROM dual;
    INSERT INTO audit_log (audit_id, table_name, op_type, record_pk, old_value, new_value, changed_by)
    VALUES (v_audit_id, 'issuance', 'INSERT', TO_CHAR(:NEW.issuance_id),
            NULL,
            'Unit ' || :NEW.unit_id || ' issued for request ' || :NEW.request_id,
            USER);
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- ====================== SECTION 8: HEALTH CHECK ============================

PROMPT
PROMPT ===========================================================
PROMPT BBDMS REBUILD COMPLETE
PROMPT ===========================================================

SELECT 'Tables'        AS object_type, COUNT(*) AS count FROM user_tables
UNION ALL SELECT 'Sequences',   COUNT(*) FROM user_sequences
UNION ALL SELECT 'Functions',   COUNT(*) FROM user_objects WHERE object_type = 'FUNCTION'
UNION ALL SELECT 'Procedures',  COUNT(*) FROM user_objects WHERE object_type = 'PROCEDURE'
UNION ALL SELECT 'Triggers',    COUNT(*) FROM user_triggers;

SELECT 'Donors',     COUNT(*) FROM donor
UNION ALL SELECT 'Donations',  COUNT(*) FROM donation
UNION ALL SELECT 'Blood Units AVAILABLE', COUNT(*) FROM blood_unit WHERE status = 'AVAILABLE'
UNION ALL SELECT 'Blood Units EXPIRED',   COUNT(*) FROM blood_unit WHERE status = 'EXPIRED'
UNION ALL SELECT 'Screening rows',        COUNT(*) FROM screening
UNION ALL SELECT 'Open Requests',         COUNT(*) FROM request WHERE status = 'OPEN'
UNION ALL SELECT 'Hospitals',             COUNT(*) FROM hospital
UNION ALL SELECT 'Staff',                 COUNT(*) FROM staff;

PROMPT
PROMPT The schema is ready. Test issuance with:
PROMPT   BEGIN issue_unit(p_request_id => 1, p_unit_id => <some AVAILABLE unit_id>, p_staff_id => 4); END; /
PROMPT
