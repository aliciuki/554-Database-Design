-- The commit date is the last upload to git.
-- This code is to create the database RBSC and the 10 (+6) tables contained in it. 
-- As mentioned in our discussion page on Canvas, we had to add 2 tables to implement our subtypes properly.

--This query is commented out because the code won't run with it. Make sure to start with this query separately, and then execute all the rest together.
--CREATE DATABASE RBSC
--GO

USE RBSC

-- This section creates the tables for people in the database, DONOR and PERSONNEL.
-- I think we should make names fairly long, because of this: https://www.kalzumeus.com/2010/06/17/falsehoods-programmers-believe-about-names/
CREATE TABLE DONOR(
  DON_ID INT NOT NULL IDENTITY,
  DON_LNAME VARCHAR(100),
  DON_FNAME VARCHAR(100),
  DON_AFFIL VARCHAR(50),
  PRIMARY KEY (DON_ID)
)

CREATE INDEX DON_LNAMEX ON DONOR (DON_LNAME)

CREATE TABLE PERSONNEL(
-- This would be the 7-digit UBC staff ID (see ubccard.ubc.ca/obtaining-a-ubccard/faculty-staff)
  PERS_ID CHAR(7) NOT NULL ,
  PERS_LNAME VARCHAR(100) NOT NULL,
  PERS_FNAME VARCHAR(100),
  PERS_ROLE VARCHAR(50),
-- Phone number is 12 digits, because it would be within Canada. It will default as the real RBSC number, we took it from https://rbsc.library.ubc.ca/contact-form/
  PERS_PHONE CHAR(12) DEFAULT('604-822-2521'),
-- Constraint checks that e-mail has proper format (with @ and dot). Taken from: https://social.msdn.microsoft.com/Forums/sqlserver/en-US/4754314a-a076-449c-ac62-e9d0c12ba717/beginner-question-check-constraint-for-email-address?forum=databasedesign
  PERS_EMAIL VARCHAR(50) CHECK(PERS_EMAIL LIKE '%___@___%.__%'),
  PRIMARY KEY (PERS_ID)
  )
  CREATE INDEX PERS_LNAMEX ON PERSONNEL (PERS_LNAME)
  CREATE INDEX PERS_ROLEX ON PERSONNEL (PERS_ROLE)

--This table is needed to make sure that no one accidentally creates a CORRESPONDENCE record that has DAG or OTH as types. 
--There's a really good explanation on this page: https://www.sqlteam.com/articles/implementing-table-inheritance-in-sql-server
CREATE TABLE RECORD_TYPE(
TREC_ID INT NOT NULL,
TREC_CODE CHAR(3),
PRIMARY KEY (TREC_ID)
)

--This just adds each type to the table. We need data in this table before creating RECORD and the different subtypes, because they will refer to this table.
INSERT INTO RECORD_TYPE 
SELECT 1, 'COR' UNION ALL
SELECT 2, 'DAG' UNION ALL
SELECT 3, 'OTH'


-- This section creates the table RECORD and its subtypes CORRESPONDENCE, DONOR_AGREEMENT and OTHER.
CREATE TABLE RECORD(
  REC_ID INT IDENTITY NOT NULL,
  TREC_ID INT REFERENCES RECORD_TYPE(TREC_ID) NOT NULL,
  REC_DATE DATE NOT NULL,
  REC_PHYLOC VARCHAR(100),
  -- There is no way to limit varbinary to only 25MB, but we might be missing the obvious solution...?
  REC_ATTACH VARBINARY(MAX),
  CONSTRAINT TREC UNIQUE (REC_ID, TREC_ID),
  PRIMARY KEY (REC_ID)
)

CREATE TABLE CORRESPONDENCE(
  REC_ID INT,
  --This means that all CORRESPONDENCE tables are automatically created with a constant value of 1 ('COR').
  TREC_ID AS 1 PERSISTED,
  CORR_AUTHOR VARCHAR(100),
  CORR_RECIP VARCHAR(100),
  FOREIGN KEY (REC_ID, TREC_ID) REFERENCES RECORD (REC_ID, TREC_ID),
  PRIMARY KEY (REC_ID)
)

CREATE TABLE DONOR_AGREEMENT(
  REC_ID INT,
  --This means that all DONOR_AGREEMENT tables are automatically created with a constant value of 2 ('DAG').
  TREC_ID AS 2 PERSISTED,
  DA_RECIP VARCHAR(100),
  DA_WITNESS VARCHAR(100),
  DON_ID INT,
  FOREIGN KEY (DON_ID) REFERENCES DONOR,
  FOREIGN KEY (REC_ID, TREC_ID) REFERENCES RECORD (REC_ID, TREC_ID),
  PRIMARY KEY (REC_ID)
)
CREATE TABLE OTHER(
  REC_ID INT,
  --This means that all OTHER tables are automatically created with a constant value of 3 ('DAG').
  TREC_ID AS 3 PERSISTED,
  OTHER_TYPE VARCHAR(50),
  OTHER_DESC VARCHAR(1000),
  FOREIGN KEY (REC_ID, TREC_ID) REFERENCES RECORD (REC_ID, TREC_ID),
  PRIMARY KEY (REC_ID)
)

-- This section creates the COLLECTION table.
-- 'Collection' is a command, so we use brackets.
CREATE TABLE [COLLECTION](
-- 'IDENTITY' is used for automatic keys that increase automatically. Ours start at 1 and increase by 1 each time.
-- It's all here https://docs.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql-identity-property?view=sql-server-2017
-- and here https://docs.microsoft.com/en-us/sql/t-sql/statements/create-table-transact-sql?view=sql-server-2017
  COLL_ID INT NOT NULL IDENTITY,
  COLL_NAME VARCHAR(100) NOT NULL,
  COLL_REFCODE VARCHAR(15) NOT NULL,
  PRIMARY KEY (COLL_ID)
)
CREATE INDEX COLL_NAMEX ON [COLLECTION] (COLL_NAME)

--This table is needed to make sure that no one accidentally creates an ACQUISITION transaction that accidentally has ACCR or FUN as types. 
--There's a really good explanation on this page: https://www.sqlteam.com/articles/implementing-table-inheritance-in-sql-server
CREATE TABLE TRANSACTION_TYPE(
	TTRAN_ID INT NOT NULL,
	TTRAN_CODE CHAR(3),
	PRIMARY KEY (TTRAN_ID)
	)
--This just adds each type to the table. We need data in this table before creating [TRANSACTION] and the different subtypes, because they will refer to this table.
INSERT INTO TRANSACTION_TYPE
SELECT 1, 'ACQ' UNION ALL
SELECT 2, 'ADD' UNION ALL
SELECT 3, 'FUN'

-- This section creates the TRANSACTION table and its subtypes ACQUISITION, ADDITION and FUNDS,
CREATE TABLE [TRANSACTION] (
  TRAN_ID INT IDENTITY NOT NULL ,
  TRAN_DATE DATE NOT NULL,
  TTRAN_ID INT REFERENCES TRANSACTION_TYPE(TTRAN_ID),
  DON_ID INT,
  COLL_ID INT,
  REC_ID INT,
  PERS_MAIN_ID CHAR(7) NOT NULL,
  FOREIGN KEY (DON_ID) REFERENCES DONOR,
  FOREIGN KEY (COLL_ID) REFERENCES [COLLECTION],
  FOREIGN KEY (REC_ID) REFERENCES RECORD,
  FOREIGN KEY (PERS_MAIN_ID) REFERENCES PERSONNEL(PERS_ID),
  CONSTRAINT TTRAN UNIQUE (TRAN_ID, TTRAN_ID),
  PRIMARY KEY (TRAN_ID),
 )
  CREATE INDEX TRAN_DATEX ON [TRANSACTION] (TRAN_DATE)

CREATE TABLE KIND(
  KIND_ID INT NOT NULL IDENTITY,
  KIND_NAME VARCHAR(50),
  TRAN_ID INT,
  FOREIGN KEY (TRAN_ID) REFERENCES [TRANSACTION],
  PRIMARY KEY(KIND_ID)
)
    
CREATE TABLE ACQUISITION(
  TRAN_ID INT,
  TTRAN_ID AS 1 PERSISTED,
  ACQ_METHOD VARCHAR(100),
  KIND_ID INT,
  FOREIGN KEY (TRAN_ID, TTRAN_ID) REFERENCES [TRANSACTION](TRAN_ID, TTRAN_ID),
  FOREIGN KEY (KIND_ID) REFERENCES KIND,
  FOREIGN KEY (TRAN_ID) REFERENCES [TRANSACTION],
  PRIMARY KEY (TRAN_ID)
)

CREATE TABLE ADDITION(
  TRAN_ID INT,
  TTRAN_ID AS 2 PERSISTED,
  -- We are ranking these additions in order of ranking, the first addition gets 1, the second gets 2, and so on...
  ADD_RANKING INT IDENTITY(1,1),
  KIND_ID INT,
  FOREIGN KEY (TRAN_ID, TTRAN_ID) REFERENCES [TRANSACTION](TRAN_ID, TTRAN_ID),
  FOREIGN KEY (KIND_ID) REFERENCES KIND,
  PRIMARY KEY (TRAN_ID)
)

CREATE TABLE FUNDS(
  TRAN_ID INT,
  TTRAN_ID AS 3 PERSISTED,
  FUN_VALUE DECIMAL(38,2),
  FUN_PURPOSE VARCHAR(200),
  FOREIGN KEY (TRAN_ID, TTRAN_ID) REFERENCES [TRANSACTION](TRAN_ID, TTRAN_ID),
  PRIMARY KEY (TRAN_ID)
)

CREATE TABLE OTHER_PERSONNEL(
  TRAN_ID INT,
  PERS_ID CHAR(7),
  OPERS_NOTE VARCHAR(100),
  FOREIGN KEY (TRAN_ID) REFERENCES [TRANSACTION],
  FOREIGN KEY (PERS_ID) REFERENCES PERSONNEL,
  PRIMARY KEY (TRAN_ID, PERS_ID)
)

CREATE TABLE NOTE(
  NOTE_ID INT NOT NULL IDENTITY,
  NOTE_TTL VARCHAR(100),
  -- If our math is correct, 50000 characters is 50kb, which is a generous margin for a note.
  -- Chelsea Shriver asked us to err on the side of fewer limits, fewer mandatory fields. Also, they are
  -- especially interested in having a 'narrative' and more space for text is consistent with that.
  NOTE_TXT VARCHAR(MAX),
  NOTE_DATE DATE DEFAULT GETDATE() NOT NULL,
  NOTE_AUTH VARCHAR(100),
  REC_ID INT,
  COLL_ID INT,
  DON_ID INT,
  TRAN_ID INT,
  FOREIGN KEY (REC_ID) REFERENCES RECORD,
  FOREIGN KEY (COLL_ID) REFERENCES [COLLECTION],
  FOREIGN KEY (DON_ID) REFERENCES DONOR,
  FOREIGN KEY (TRAN_ID) REFERENCES [TRANSACTION],
  PRIMARY KEY (NOTE_ID)
  )
  CREATE INDEX NOTE_DATEX ON NOTE (NOTE_DATE)
  CREATE INDEX NOTE_TTLX ON NOTE (NOTE_TTL)
