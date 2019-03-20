-- WORK IN PROGRESS Still lots of things to change.
-- I haven't really done all the constraints yet but this is so everyone can see how it's going.
-- I'll continue on Tuesday, also looking forward to your updates re: normalization and any changes to the ERD.
--
--
-- The commit date is the last upload to git.
-- This code is to create the database RBSC and the 8 (+6) tables contained in it.
CREATE DATABASE RBSC
USE RBSC
GO
-- This section creates the COLLECTIONS table.
-- 'Collection' is a command, so we can't call our table that.
CREATE TABLE [COLLECTION](
-- 'IDENTITY' is used for automatic keys that increase automatically. Ours start at 1 and increase by 1 each time.
-- It's all here https://docs.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql-identity-property?view=sql-server-2017
-- and here https://docs.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql?view=sql-server-2017
  COLL_ID INT NOT NULL IDENTITY,
  COLL_NAME NOT NULL VARCHAR(100),
  -- ****What is a COLL_REFCODE referring to?
  COLL_REFCODE NOT NULL VARCHAR(15),
-- If I declare the FKs here with int, does that conflict with the full declaration in the main table?
  NOTE_ID INT,
  TRAN_ID INT,
  FOREIGN KEY (TRAN_ID) REFERENCES TRANSACTION,
  FOREIGN KEY (NOTE_ID) REFERENCES NOTE,
  PRIMARY KEY (COLL_ID)
)

CREATE TABLE NOTE(
  NOTE_ID INT NOT NULL IDENTITY,
  NOTE_TTL VARCHAR(100),
  -- If our math is correct, 50000 characters is 50kb, which is a generous margin for a note.
  -- Chelsea Shriver asked us to err on the side of fewer limits, fewer mandatory fields. Also, they are
  -- especially interested in having a 'narrative' and more space for text is consistent with that.
  NOTE_TXT TEXT VARCHAR(50000),
  NOTE_DATE DATE DEFAULT SYSDATE NOT NULL,
  NOTE_AUTH VARCHAR(100),
  REC_ID INT,
  COLL_ID INT,
  DON_ID INT,
  TRAN_ID INT,
  FOREIGN KEY (REC_ID) REFERENCES RECORD,
  FOREIGN KEY (COLL_ID) REFERENCES [COLLECTION],
  FOREIGN KEY (DON_ID) REFERENCES DONOR,
  FOREIGN KEY (TRAN_ID) REFERENCES TRANSACTION,
  PRIMARY KEY (NOTE_ID)
)

CREATE TABLE KIND(
  KIND_ID INT NOT NULL IDENTITY,
  KIND_NAME VARCHAR(50),
  PRIMARY KEY(KIND_ID)
)

-- This section creates the TRANSACTION table and its subtypes ACQUISITION, ADDITION and FUNDS,
CREATE TABLE TRANSACTION(
  TRAN_ID INT NOT NULL IDENTITY,
  TRAN_DATE DATE DEFAULT SYSDATE NOT NULL,
  TRAN_TYPE CHAR(3) CHECK(TRAN_TYPE IN ('ACQ', 'ADD', 'FUN')),
  DON_ID INT,
  COLL_ID INT,
  REC_ID INT,
  PERS_MAIN_ID NOT NULL CHAR(7),
  FOREIGN KEY (DON_ID) REFERENCES DONOR,
  FOREIGN KEY (COLL_ID) REFERENCES [COLLECTION],
  FOREIGN KEY (REC_ID) REFERENCES RECORD,
  FOREIGN KEY (PERS_MAIN_ID) REFERENCES PERSONNEL(PERS_ID),
  PRIMARY KEY (TRAN_ID)
  )

CREATE TABLE ACQUISITION(
  TRAN_ID INT,
  ACQ_METHOD VARCHAR(100),
  KIND_ID INT,
  FOREIGN KEY (KIND_ID) REFERENCES KIND,
  FOREIGN KEY (TRAN_ID) REFERENCES TRANSACTION,
  PRIMARY KEY (TRAN_ID)
)

CREATE TABLE ADDITION(
  TRAN_ID INT,
  -- We are ranking these additions in order of ranking, the first addition gets 1, the second gets 2, and so on...
  ADD_RANKING INT IDENTITY(1,1),
  KIND_ID INT,
  FOREIGN KEY (KIND_ID) REFERENCES KIND,
  FOREIGN KEY (TRAN_ID) REFERENCES TRANSACTION,
  PRIMARY KEY (TRAN_ID)
)

CREATE TABLE FUNDS(
  TRAN_ID INT,
  FUN_VALUE DECIMAL(38,2),
  KIND_ID INT,
  FOREIGN KEY (KIND_ID) REFERENCES KIND,
  FOREIGN KEY (TRAN_ID) REFERENCES TRANSACTION,
  PRIMARY KEY (TRAN_ID)
)

-- This section creates the tables for people in the database, DONOR and PERSONNEL.
-- I think we should make names fairly long, because of this: https://www.kalzumeus.com/2010/06/17/falsehoods-programmers-believe-about-names/
CREATE TABLE DONOR(
  DON_ID INT NOT NULL IDENTITY,
  DON_LNAME VARCHAR(100),
  DON_FNAME VARCHAR(100),
  DON_AFFIL VARCHAR(50),
  --- Country code: 3, Area code: 3, Phone number: 7. Spaces or dashes? Plus sign?

  NOTE_ID INT,
  TRAN_ID INT,
  FOREIGN KEY (NOTE_ID) REFERENCES NOTE,
  FOREIGN KEY (TRAN_ID) REFERENCES TRANSACTION,
  PRIMARY KEY (DON_ID)
)

CREATE TABLE PERSONNEL(
-- This would be the 7-digit UBC staff ID (see ubccard.ubc.ca/obtaining-a-ubccard/faculty-staff)
  PERS_ID INT NOT NULL CHAR(7),
  PERS_LNAME NOT NULL VARCHAR(100),
  PERS_FNAME VARCHAR(100),
  PERS_ROLE VARCHAR(50),
-- Phone number is 12 digits, because it would be within Canada. It will default as the real RBSC number, we took it from https://rbsc.library.ubc.ca/contact-form/
  PERS_PHONE CHAR(12) DEFAULT('604-822-2521'),
-- Constraint checks that e-mail has proper format (with @ and dot). Taken from: https://social.msdn.microsoft.com/Forums/sqlserver/en-US/4754314a-a076-449c-ac62-e9d0c12ba717/beginner-question-check-constraint-for-email-address?forum=databasedesign
  PERS_EMAIL VARCHAR(50) CHECK(PERS_EMAIL LIKE '%___@___%.__%'),
  PRIMARY KEY (PERS_ID)
)

CREATE TABLE OTHER_PERSONNEL(
  TRAN_ID INT,
  PERS_ID CHAR(7),
  FOREIGN KEY (TRANS_ID) REFERENCES TRANSACTION,
  FOREIGN KEY (PERS_ID) REFERENCES PERSONNEL,
  PRIMARY KEY (TRANS_ID, PERS_ID)
)


-- This section creates the table RECORD and its subtypes CORRESPONDENCE, DONOR_AGREEMENT and OTHER.
CREATE TABLE RECORD(
  REC_ID INT NOT NULL IDENTITY,
  REC_TYPE CHAR(3) NOT NULL CHECK(REC_TYPE IN ('COR', 'DAG', 'OTH')),
  REC_DATE DATE NOT NULL,
  REC_PHYLOC VARCHAR(100),
  -- There is no way to limit varbinary to only 25MB, but we might be missing the obvious solution...?
  REC_ATTACH VARBINARY(MAX),
  PRIMARY KEY (REC_ID)
)

CREATE TABLE CORRESPONDENCE(
  REC_ID INT,
  CORR_AUTHOR VARCHAR(100),
  CORR_RECIP VARCHAR(100),
  PRIMARY KEY (REC_ID),
  FOREIGN KEY (REC_ID) REFERENCES RECORD
)

CREATE TABLE DONOR_AGREEMENT(
  REC_ID INT,
  DA_RECIP VARCHAR(100),
  DA_WITNESS VARCHAR(100),
  PRIMARY KEY (REC_ID),
  FOREIGN KEY (REC_ID) REFERENCES RECORD
)
CREATE TABLE OTHER(
  REC_ID INT,
  OTHER_TYPE VARCHAR(50),
  OTHER_DESC VARCHAR(1000),
  PRIMARY KEY (REC_ID),
  FOREIGN KEY (REC_ID) REFERENCES RECORD
)
