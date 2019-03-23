--Please execute code in this order:
--1st: Create table RBSC executing line 6
--2nd: Execute Part I (schema) on lines 7-217
--3rd: Execute Part II (data) on lines 226-end, one block at a time following instructions on each labeled block.

CREATE TABLE RBSC

-- PART I: Database Schema (lines 7-217). This file creates the tables in the RBSC database.
USE RBSC
-- DONOR
CREATE TABLE DONOR(
  DON_ID INT NOT NULL IDENTITY,
  --We err on the side of longer names to ensure 'exotic' names also have enough space.
  --Only DON_LNAME is mandatory because not all naming conventions follow the first/last name pattern: https://www.kalzumeus.com/2010/06/17/falsehoods-programmers-believe-about-names/
  DON_LNAME VARCHAR(100) NOT NULL,
  DON_FNAME VARCHAR(100),
  DON_AFFIL VARCHAR(50),
  PRIMARY KEY (DON_ID)
)
--Because the user would most likely search for a donor by their last name, we chose that as an index.
CREATE INDEX DON_LNAMEX ON DONOR (DON_LNAME)

-- PERSONNEL
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
  --The database users will most likely search for personnel by name or by role, so we added these two indexes.
  CREATE INDEX PERS_LNAMEX ON PERSONNEL (PERS_LNAME)
  CREATE INDEX PERS_ROLEX ON PERSONNEL (PERS_ROLE)

--To make sure that no one accidentally creates a CORRESPONDENCE record that has DAG or OTH as types, we add 1 table to make persistent attributes on each RECORD type.
--This table must be created and data must be added before creating RECORD and its subtypes.
--(There's a really good explanation on this page: https://www.sqlteam.com/articles/implementing-table-inheritance-in-sql-server)
CREATE TABLE RECORD_TYPE(
TREC_ID INT NOT NULL,
TREC_CODE CHAR(3),
PRIMARY KEY (TREC_ID)
)
INSERT INTO RECORD_TYPE
SELECT 1, 'COR' UNION ALL
SELECT 2, 'DAG' UNION ALL
SELECT 3, 'OTH'

-- RECORD and subtypes: CORRESPONDENCE, DONOR_AGREEMENT and OTHER.
CREATE TABLE RECORD(
  REC_ID INT IDENTITY NOT NULL,
  TREC_ID INT REFERENCES RECORD_TYPE(TREC_ID) NOT NULL,
  REC_DATE DATE NOT NULL,
  REC_PHYLOC VARCHAR(100),
  -- There is no way to limit varbinary to only 25MB, but we might be missing the obvious solution...?
  REC_ATTACH VARCHAR(100),
  CONSTRAINT TREC UNIQUE (TREC_ID,REC_ID),
  PRIMARY KEY (REC_ID)
)

CREATE TABLE CORRESPONDENCE(
  REC_ID INT,
  --This means that all CORRESPONDENCE tables are automatically created with a constant value of 1 ('COR').
  TREC_ID AS 1 PERSISTED,
  CORR_AUTHOR VARCHAR(100),
  CORR_RECIP VARCHAR(100),
  --Foreign keys are indexed so the order matters.
  --Because the PK REC_ID already indexes that column, we will make (TREC_ID,REC_ID) index records first by type, then by record ID.
  FOREIGN KEY (TREC_ID,REC_ID) REFERENCES RECORD (TREC_ID,REC_ID),
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
  FOREIGN KEY (TREC_ID,REC_ID) REFERENCES RECORD (TREC_ID,REC_ID),
  PRIMARY KEY (REC_ID)
)
CREATE TABLE OTHER(
  REC_ID INT,
  --This means that all OTHER tables are automatically created with a constant value of 3 ('DAG').
  TREC_ID AS 3 PERSISTED,
  OTHER_TYPE VARCHAR(50),
  OTHER_DESC VARCHAR(1000),
  FOREIGN KEY (TREC_ID,REC_ID) REFERENCES RECORD (TREC_ID,REC_ID),
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

--To make sure that no one accidentally creates an ACQUISITION record that has ADD or FUN as types, we add 1 table to make persistent attributes on each [TRANSACTION] type.
--This table must be created and data must be added before creating [TRANSACTION] and its subtypes.
--(There's a really good explanation on this page: https://www.sqlteam.com/articles/implementing-table-inheritance-in-sql-server)
CREATE TABLE TRANSACTION_TYPE(
	TTRAN_ID INT NOT NULL,
	TTRAN_CODE CHAR(3),
	PRIMARY KEY (TTRAN_ID)
	)
INSERT INTO TRANSACTION_TYPE
SELECT 1, 'ACQ' UNION ALL
SELECT 2, 'ADD' UNION ALL
SELECT 3, 'FUN'

-- TRANSACTION and subtypes ACQUISITION, ADDITION and FUNDS
CREATE TABLE [TRANSACTION] (
  TRAN_ID INT IDENTITY NOT NULL ,
  TRAN_DATE DATE NOT NULL
  --Transaction dates (date the materials came to UBC) should be no older than UBC itself (1908).
  --We set the constraint after 1900 to account for any book purchases/donations that could have been made for UBC before the official establishment date.
  CHECK (TRAN_DATE > '1900-01-01'),
  --TTRAN_ID, which references table TRANSACTION_TYPE, is a FK. When a user creates a [TRANSACTION], they must indicate a type. This type must correspond with the data in table TRANSACTION_TYPE and the subtype table.
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
 --TTRAN indexes transactions by type. Users might also search transactions by date.
  CREATE INDEX TRAN_DATEX ON [TRANSACTION] (TRAN_DATE)

--KIND stores values for the *_KIND column in ACQUISITIONS and ACCRUALS.
CREATE TABLE KIND(
  KIND_ID INT NOT NULL IDENTITY,
  KIND_NAME VARCHAR(50),
  PRIMARY KEY(KIND_ID)
)

CREATE TABLE ACQUISITION(
  TRAN_ID INT,
  --PERSISTED sets the value of column TTRAN_ID in ACQUISITION as 1. In TRAN_TYPE, 1 corresponds with 'ACQ'.
  --This ensures that each subtype gets assigned the proper type.
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
  -- Chelsea Shriver asked us to err on the side of fewer limits, fewer mandatory fields.
  -- VARCHAR(MAX) is purposely set at 2GB maximum text because the RBSC is interested in having a 'narrative'
  NOTE_TXT VARCHAR(MAX),
  --This is the date the note was created, defaults to the current date but can be changed by author if backdated, etc.
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
  --We think the most useful indexes for notes are dates and titles.
  CREATE INDEX NOTE_DATEX ON NOTE (NOTE_DATE)
  CREATE INDEX NOTE_TTLX ON NOTE (NOTE_TTL)
 --End of Part I


--Part II
--Please run one block at a time.
--BLOCK 1
--
USE RBSC
GO

--INSERTING DATA INTO DONOR--
INSERT INTO DONOR VALUES ('Ocasio-Cortez', 'Alexandria', 'US House of Representatives')
INSERT INTO DONOR VALUES ('O''Rourke', 'Beto', 'State of Texas')
INSERT INTO DONOR VALUES ('Lafourcade', 'Natalia', 'Los Macorinos')
INSERT INTO DONOR VALUES ('Drexler', 'Jorge', 'Salvavidas de Hielo')
INSERT INTO DONOR VALUES('Acorn', 'Milton', 'Writers'' Guild of Canada')
INSERT INTO DONOR VALUES('Adachi', 'Ken', 'Writers'' Guild of Canada')
INSERT INTO DONOR VALUES('Electa Adams', 'Mary', 'Salvation Army')
INSERT INTO DONOR VALUES('Ahenakew', 'Freda', 'Nobel Foundation')
INSERT INTO DONOR VALUES('Thomson', 'David', 'University of the Lagoon')
INSERT INTO DONOR VALUES('Tsai', 'Joseph', 'University of Port Renfrew')
INSERT INTO DONOR VALUES('Weston', 'Galen', 'Incotex Holdings Ltd.')
INSERT INTO DONOR VALUES('Saputo', 'Lino', 'Fortune 500')
INSERT INTO DONOR VALUES('Garrett', 'Camp', 'Rotary Club')
INSERT INTO DONOR VALUES('Pattison', 'Jim', 'Writers'' Guild Canada')
INSERT INTO DONOR VALUES('Selena', 'Gomez', 'Warner Music Inc.')
INSERT INTO DONOR VALUES('Bieber', 'Justin', 'Warner Music Inc.')
INSERT INTO DONOR VALUES('Kylie', 'Jenner', 'The Kardashian Dynasty')
INSERT INTO DONOR VALUES('Kardashian', 'Kim', 'The Kardashian Dynasty')
INSERT INTO DONOR VALUES('Dwayne', 'Johnson', 'World Wrestling Association')
INSERT INTO DONOR VALUES('Grande', 'Ariana', 'World Wide Fund')

--INSERTING INTO PERSONNEL--
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676701,'Andrades-Grassi', 'Silvia', 'Intern', 'silvia@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676702,'Luchka', 'Victoria', 'Intern', 'victoria@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676703,'Urquidi', 'Alicia', 'Intern', 'alicia@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676704,'Warren', 'Petra', 'Intern', 'petra@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676705,'Akinsanya', 'Jimi', 'Intern', 'jimi@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676706,'Shriver', 'Chelsea', 'Librarian', 'chelsea@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676707,'Palmer-Wilson', 'Kevin', 'Staff', 'kevin@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676708,'Appiah', 'Kwame Antonio', 'Archivist', 'kwame@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676709,'Ahumada', 'Marcianito', 'Junior Student Librarian', 'marianitolovers@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676710,'Figueroa', 'Amanda', 'Junior Student Librarian', 'amanda@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676711,'Dickinson McNamara von Schopehnauer under den Linden', 'Emma Patricia Sandra', 'Deputy Librarian', 'emma@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676712,'Evans', 'Vivien', 'Student Librarian', 'vivien@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676713,'McNambuckle', 'Alonso', 'Student Librarian', 'alonso@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676714,'Li', 'Zi', 'Student Librarian', 'zili@ubcfake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676715,'Lee', 'Sam', 'Intern', 'sam@fake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676716,'Humala', 'Ollanta', 'Intern', 'ollanta@fake.info')
INSERT INTO PERSONNEL(PERS_ID,PERS_LNAME,PERS_FNAME, PERS_ROLE, PERS_EMAIL) VALUES(5676717,'Cavallo', 'Ascanio', 'Intern', 'ascanio@fake.info')
-- INSERTING INTO COLLECTION TABLE--

INSERT INTO [COLLECTION] VALUES('Chung Collection','CLLCHUN')
INSERT INTO [COLLECTION] VALUES('Open Collections','CLLOPEC')
INSERT INTO [COLLECTION] VALUES('Puban Collection','CLLPUBN')
INSERT INTO [COLLECTION] VALUES('BC Fire Insurance Maps','CLLFIRE')
INSERT INTO [COLLECTION] VALUES('L. Stanley Deane Collection','CLLSTAN')
INSERT INTO [COLLECTION] VALUES('Howay-Reid Maps of British Columbia','CLLREID')
INSERT INTO [COLLECTION] VALUES('Coolie-Verner Map Collection','CLLCOOL')
INSERT INTO [COLLECTION] VALUES('Andrew McCormick Maps and Prints','CLLANDY')
INSERT INTO [COLLECTION] VALUES('Malcolm Lowry at RBSC','CLLMALC')
INSERT INTO [COLLECTION] VALUES('Norman Colbeck Collection','CLLNORM')
INSERT INTO [COLLECTION] VALUES('Dr. H. Rocke Robertson Collection of Dictionaries and Related Works','CLLROCK')
INSERT INTO [COLLECTION] VALUES('A.M. Donaldson Burns Collection','CLLBURN')
INSERT INTO [COLLECTION] VALUES('Herbert Rosengarten Collection','CLLHERB')
INSERT INTO [COLLECTION] VALUES('Allan Pritchard Collection','CLLPRIT')
INSERT INTO [COLLECTION] VALUES('Angeli-Dennis Collection','CLLANGE')
INSERT INTO [COLLECTION] VALUES('Thomas J. Wise Collection','CLLWISE')
INSERT INTO [COLLECTION] VALUES('Louis Zukofsky Collection','CLLZUKO')


--INSERTING DATA INTO RECORD---

INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (1, '2019-01-19', 'Library Fonds', 'https://preview.tinyurl.com/dicties')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (1, '2018-05-19', 'Library Fonds', 'https://preview.tinyurl.com/feministmetro')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (1, '2016-08-01', 'Library Fonds', 'https://preview.tinyurl.com/dicties')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (1, '2016-05-29', 'Library Fonds', 'https://preview.tinyurl.com/feministmetro')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (1, '2018-03-05', 'Irving K Barber RBSC', 'https://preview.tinyurl.com/abatedsubt')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (2, '2017-12-15', 'Irving K Barber RBSC', 'https://tinyurl.com/dummyimsodummy')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (2, '2003-07-15', 'Irving K Barber RBSC', 'https://preview.tinyurl.com/tiniestPDF')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (2, '1977-09-02', 'Library fonds', 'https://preview.tinyurl.com/fakePDFfake')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (2, '1997-09-19', 'Library Fonds', 'https://preview.tinyurl.com/nutherTinyURL')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (2, '2018-12-19', 'Library Fonds', 'https://preview.tinyurl.com/dicties')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (3, '2018-05-19', 'Library Fonds', 'https://preview.tinyurl.com/feministmetro')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (3, '1986-09-02', 'Library fonds', 'https://preview.tinyurl.com/yaomacaochinesecollection')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (3, '2018-09-02', 'Library fonds', 'https://preview.tinyurl.com/anotherfakePDF')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (3, '2001-01-20', 'Irving K Barber RBSC', 'https://preview.tinyurl.com/papyer')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (3, '1989-09-20', 'Irving K Barber RBSC', 'https://preview.tinyurl.com/unint')
INSERT INTO RECORD (TREC_ID, REC_DATE, REC_PHYLOC, REC_ATTACH) VALUES (3, '1996-12-20', 'Irving K Barber RBSC', 'https://preview.tinyurl.com/nevermorevermore')
 --END of BLOCK 1

 --BLOCK 2
--INSERTING INTO CORRESPONDENCE--
INSERT INTO CORRESPONDENCE(REC_ID, CORR_AUTHOR, CORR_RECIP) VALUES (1,'Salam Cawley', 'Susan Parker')
INSERT INTO CORRESPONDENCE(REC_ID, CORR_AUTHOR, CORR_RECIP) VALUES (2,'Nassif Ghoussoub', 'Sally Taylor')
INSERT INTO CORRESPONDENCE(REC_ID, CORR_AUTHOR, CORR_RECIP) VALUES (3,'Rick Wilson', 'Peter James')
INSERT INTO CORRESPONDENCE(REC_ID, CORR_AUTHOR, CORR_RECIP) VALUES (4,'Nassif Ghoussoub', 'Sally Taylor')
INSERT INTO CORRESPONDENCE(REC_ID, CORR_AUTHOR, CORR_RECIP) VALUES (5,'Saul Bellow', 'Peter James')

--INSERTING INTO DONOR AGREEMENT--
INSERT INTO DONOR_AGREEMENT(REC_ID, DA_RECIP, DA_WITNESS, DON_ID) VALUES (6,'Pierre Trudeau', 'Susan Parker', 12)
INSERT INTO DONOR_AGREEMENT(REC_ID, DA_RECIP, DA_WITNESS, DON_ID) VALUES (7,'Nassif Ghoussoub', 'Santa Ono', 2)
INSERT INTO DONOR_AGREEMENT(REC_ID, DA_RECIP, DA_WITNESS, DON_ID) VALUES (8, 'Matilde Urrutia', 'Susan Parker', 3)
INSERT INTO DONOR_AGREEMENT(REC_ID, DA_RECIP, DA_WITNESS, DON_ID) VALUES (9, 'Isabel Allende', 'Parker Susan', 3)
INSERT INTO DONOR_AGREEMENT(REC_ID, DA_RECIP, DA_WITNESS, DON_ID) VALUES (10, 'Veronica Zondek', 'Santa Ono', 3)

--INSERTING INTO OTHER--
INSERT INTO OTHER(REC_ID, OTHER_TYPE, OTHER_DESC) VALUES (11,'Deed of Gift', 'National Library of Canada, Librarians Working with this collection shoud read the Deed of Gift')
INSERT INTO OTHER(REC_ID, OTHER_TYPE, OTHER_DESC) VALUES (12,'Chinese Cultural Centre', 'Chinese Canadians – History, Canadian Pacific Railway, Northwest Coast of North America')
INSERT INTO OTHER(REC_ID, OTHER_TYPE, OTHER_DESC) VALUES (13,'Bibliography', 'Arctic Regions Discovery and Exploration. Arctic regions, description and travel. Stefansson, Oluf')
INSERT INTO OTHER(REC_ID, OTHER_TYPE, OTHER_DESC) VALUES (14,'Will', 'Michael Jackson''s last words scribbled on a bar napkin')
INSERT INTO OTHER(REC_ID, OTHER_TYPE, OTHER_DESC) VALUES (15,'Advertisement', 'The Times Colonist, December 17th, 1996')

---INSERTING INTO TRANSACTION TABLE---
--INSERTING FOR THE TRANSACTION FOR 1ST COLLECTION WITH THE THREE TYPES OF TRANSACTION---
INSERT INTO [TRANSACTION] VALUES('2018-10-12',1,1,1,2,'5676701')
INSERT INTO [TRANSACTION] VALUES('2018-10-13',2,2,1,2,'5676701')
INSERT INTO [TRANSACTION] VALUES('2018-11-21',2,3,1,2,'5676701')
INSERT INTO [TRANSACTION] VALUES('2018-12-28',3,4,1,2,'5676701')

--INSERTING FOR THE TRANSACTION FOR 2ND COLLECTION WITH THE THREE TYPES OF TRANSACTION---
INSERT INTO [TRANSACTION] VALUES('2010-11-27',1,5,2,5,'5676702')
INSERT INTO [TRANSACTION] VALUES('2011-12-17',1,6,2,8,'5676702')
INSERT INTO [TRANSACTION] VALUES('2011-12-27',2,7,2,5,'5676702')
INSERT INTO [TRANSACTION] VALUES('2013-06-11',2,8,2,8,'5676702')
INSERT INTO [TRANSACTION] VALUES('2018-11-05',3,9,2,4,'5676702')
INSERT INTO [TRANSACTION] VALUES('2017-07-01',3,10,2,7,'5676702')

--INSERTING FOR THE TRANSACTION FOR 3RD COLLECTION WITH THE THREE TYPES OF TRANSACTION---
INSERT INTO [TRANSACTION] VALUES('2008-01-19',1,11,3,8,'5676703')
INSERT INTO [TRANSACTION] VALUES('2018-11-29',1,12,3,9,'5676703')
INSERT INTO [TRANSACTION] VALUES('1999-07-15',2,13,3,10,'5676703')
INSERT INTO [TRANSACTION] VALUES('2006-12-29',2,14,3,8,'5676703')
INSERT INTO [TRANSACTION] VALUES('2019-01-20',3,15,3,9,'5676703')
INSERT INTO [TRANSACTION] VALUES('2018-01-21',3,16,3,10,'5676703')

-- INSERTING INTO KIND TABLE--
INSERT INTO KIND (KIND_NAME) VALUES ('Books')
INSERT INTO KIND (KIND_NAME) VALUES ('Fonds')
INSERT INTO KIND (KIND_NAME) VALUES ('Mixed media')

--END of BLOCK 2

--BLOCK 3
--INSERTING FOR AQUISITION--
INSERT INTO ACQUISITION (TRAN_ID, ACQ_METHOD,KIND_ID) VALUES (5,'Purchase',1)
INSERT INTO ACQUISITION (TRAN_ID, ACQ_METHOD,KIND_ID) VALUES (6,'Purchase',1)
INSERT INTO ACQUISITION (TRAN_ID, ACQ_METHOD,KIND_ID) VALUES (11,'Field collection',1)

--INSERTING FOR ADDITION--
INSERT INTO ADDITION (TRAN_ID,KIND_ID) VALUES (2,1)
INSERT INTO ADDITION (TRAN_ID,KIND_ID) VALUES (3,2)
INSERT INTO ADDITION (TRAN_ID,KIND_ID) VALUES (7,3)
INSERT INTO ADDITION (TRAN_ID,KIND_ID) VALUES (8,2)
INSERT INTO ADDITION (TRAN_ID,KIND_ID) VALUES (13,3)

--INSERTING FOR FUNDS--
INSERT INTO FUNDS (TRAN_ID, FUN_VALUE, FUN_PURPOSE) VALUES (4,1000.00,'Alice in Wonderland in Timbuktu')
INSERT INTO FUNDS (TRAN_ID, FUN_VALUE, FUN_PURPOSE) VALUES (9,12000.00, 'Chinese Mirror Cabinet')
INSERT INTO FUNDS (TRAN_ID, FUN_VALUE, FUN_PURPOSE) VALUES (10,50000000.00, 'Collect ALL the Paris bibles in the world')
INSERT INTO FUNDS (TRAN_ID, FUN_VALUE, FUN_PURPOSE) VALUES (15,5000.00, 'Cookie Monster''s Autograph')
INSERT INTO FUNDS (TRAN_ID, FUN_VALUE, FUN_PURPOSE) VALUES (16,100.00, 'Paper')

--END OF BLOCK 3

--BLOCK 4
--INSERTING INTO NOTES--
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 1', 'Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2011-01-01', 'CHELSEA SHRIVER',2,1,1,1)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 2','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2012-02-02', 'CHELSEA SHRIVER',2,1,2,2)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 3','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2013-03-03', 'CHELSEA SHRIVER',2,1,3,3)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 4','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2013-03-03', 'CHELSEA SHRIVER',2,1,4,4)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 5','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa','2014-04-14', 'CHELSEA SHRIVER',5,2,5,5)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 6','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2015-05-15', 'CHELSEA SHRIVER',8,2,6,6)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 7', 'Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2016-03-20','CHELSEA SHRIVER',5,2,7,7)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 8','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2018-11-28', 'CHELSEA SHRIVER',8,2,8,8)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 9','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2003-06-04', 'CHELSEA SHRIVER',4,2,9,9)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 10','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2015-12-07','CHELSEA SHRIVER',7,2,10,10)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 11','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2003-09-11', 'CHELSEA SHRIVER',8,3,11,11)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 12','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2010-10-14', 'CHELSEA SHRIVER',9,3,12,12)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 13','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2014-04-26', 'CHELSEA SHRIVER',10,3,13,13)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 14','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2011-03-30', 'CHELSEA SHRIVER',8,3,14,14)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 15','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2007-04-08','CHELSEA SHRIVER',9,3,15,15)
INSERT INTO NOTE (NOTE_TTL, NOTE_TXT, NOTE_DATE, NOTE_AUTH, REC_ID,COLL_ID,DON_ID,TRAN_ID)
	VALUES('Note 16','Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam, quis nostrud exerci tation ullamcorper suscipit lobortis nisl ut aliquip ex ea commodo consequa', '2007-04-25', 'CHELSEA SHRIVER',10,3,16,16)

--INSERTING DATE INTO OTHER PERSONNEL

INSERT INTO OTHER_PERSONNEL VALUES(1, '5676705', 'This other team helps manage this other transaction')
INSERT INTO OTHER_PERSONNEL VALUES(2, '5676705', 'We''re working together on this transaction')
INSERT INTO OTHER_PERSONNEL VALUES(3, '5676704', 'This team = this transaction')
INSERT INTO OTHER_PERSONNEL VALUES(4, '5676704', 'I''m a lonely worker, there''s no one in my team working on this transaction')
INSERT INTO OTHER_PERSONNEL VALUES(5, '5676704', 'This team helps manage this transaction')
INSERT INTO OTHER_PERSONNEL VALUES(6, '5676705', 'This other team helps manage this other transaction')
INSERT INTO OTHER_PERSONNEL VALUES(7, '5676705', 'We''re working together on this transaction')
INSERT INTO OTHER_PERSONNEL VALUES(8, '5676704', 'This team = this transaction')
INSERT INTO OTHER_PERSONNEL VALUES(9, '5676704', 'I''m a lonely worker, there''s no one in my team working on this transaction')
INSERT INTO OTHER_PERSONNEL VALUES(10, '5676704', 'This team helps manage this transaction')
INSERT INTO OTHER_PERSONNEL VALUES(11, '5676704', 'This team helps manage this transaction')
INSERT INTO OTHER_PERSONNEL VALUES(12, '5676705', 'This other team helps manage this other transaction')
INSERT INTO OTHER_PERSONNEL VALUES(13, '5676705', 'We''re working together on this transaction')
INSERT INTO OTHER_PERSONNEL VALUES(14, '5676704', 'This team = this transaction')
INSERT INTO OTHER_PERSONNEL VALUES(15, '5676704', 'I''m a lonely worker, there''s no one in my team working on this transaction')
INSERT INTO OTHER_PERSONNEL VALUES(16, '5676704', 'This team helps manage this transaction')

--END OF BLOCK 4
--END OF DATA
