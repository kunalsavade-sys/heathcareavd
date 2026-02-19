CREATE TABLE IF NOT EXISTS `project-65b029a2-02f6-40de-986.silver_dataset.departments` (
    dept_id STRING,
    name STRING,
    is_quarantined BOOLEAN
);

TRUNCATE TABLE `project-65b029a2-02f6-40de-986.silver_dataset.departments`;

INSERT INTO `project-65b029a2-02f6-40de-986.silver_dataset.departments`
SELECT DISTINCT 
    deptid,
    name,
    CASE 
        WHEN deptid IS NULL OR name IS NULL THEN TRUE 
        ELSE FALSE 
    END AS is_quarantined
FROM `project-65b029a2-02f6-40de-986.bronze_dataset.departments`;

------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `project-65b029a2-02f6-40de-986.silver_dataset.providers` (
    ProviderID STRING,
    FirstName STRING,
    LastName STRING,
    Specialization STRING,
    DeptID STRING,
    NPI INT64,
    is_quarantined BOOLEAN
);

TRUNCATE TABLE `project-65b029a2-02f6-40de-986.silver_dataset.providers`;

INSERT INTO `project-65b029a2-02f6-40de-986.silver_dataset.providers`
SELECT DISTINCT 
    ProviderID,
    FirstName,
    LastName,
    Specialization,
    DeptID,
    CAST(NPI AS INT64),
    CASE 
        WHEN ProviderID IS NULL OR DeptID IS NULL THEN TRUE 
        ELSE FALSE 
    END AS is_quarantined
FROM `project-65b029a2-02f6-40de-986.bronze_dataset.providers`;

------------------------------------------------------------
-- PATIENTS (Fixed Project ID)
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS 
`project-65b029a2-02f6-40de-986.silver_dataset.patients` (
  PatientID STRING NOT NULL,
  FirstName STRING,
  LastName STRING,
  MiddleName STRING,
  SSN STRING,
  PhoneNumber STRING,
  Gender STRING,
  DOB DATE,
  Address STRING,
  ModifiedDate TIMESTAMP,
  is_quarantined BOOLEAN,
  start_date TIMESTAMP,
  end_date TIMESTAMP,
  is_current BOOLEAN,
  HashID_ChangeCheck STRING,
  SilverLoadTime TIMESTAMP
);

MERGE INTO 
`project-65b029a2-02f6-40de-986.silver_dataset.patients` AS target
USING (
  SELECT
    PatientID,
    FirstName,
    LastName,
    MiddleName,
    SSN,
    PhoneNumber,
    Gender,
    DATE(TIMESTAMP_MILLIS(CAST(DOB AS INT64))) AS DOB,
    Address,
    CURRENT_TIMESTAMP() AS CurrentLoadDate,
    IF(PatientID IS NULL OR SSN IS NULL, TRUE, FALSE) AS is_quarantined,
    TO_HEX(SHA256(CONCAT(
      IFNULL(FirstName, ''), IFNULL(LastName, ''), IFNULL(MiddleName, ''),
      IFNULL(SSN, ''), IFNULL(PhoneNumber, ''), IFNULL(Gender, ''),
      IFNULL(Address, '')
    ))) AS HashID_ChangeCheck
  FROM `project-65b029a2-02f6-40de-986.bronze_dataset.patients`
) AS source
ON target.PatientID = source.PatientID AND target.is_current = TRUE

WHEN MATCHED AND target.HashID_ChangeCheck != source.HashID_ChangeCheck
THEN UPDATE SET
  target.end_date = TIMESTAMP_SUB(source.CurrentLoadDate, INTERVAL 1 MICROSECOND),
  target.is_current = FALSE,
  target.SilverLoadTime = source.CurrentLoadDate

WHEN NOT MATCHED THEN
INSERT (
  PatientID, FirstName, LastName, MiddleName, SSN, PhoneNumber,
  Gender, DOB, Address, ModifiedDate, is_quarantined,
  start_date, end_date, is_current, HashID_ChangeCheck, SilverLoadTime
)
VALUES (
  source.PatientID, source.FirstName, source.LastName, source.MiddleName, source.SSN, source.PhoneNumber,
  source.Gender, source.DOB, source.Address, source.CurrentLoadDate, source.is_quarantined,
  source.CurrentLoadDate,
  TIMESTAMP('9999-12-31 23:59:59'),
  TRUE,
  source.HashID_ChangeCheck,
  source.CurrentLoadDate
)

WHEN NOT MATCHED BY SOURCE AND target.is_current = TRUE
THEN UPDATE SET
  target.end_date = TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 MICROSECOND),
  target.is_current = FALSE,
  target.SilverLoadTime = CURRENT_TIMESTAMP();

------------------------------------------------------------
-- ENCOUNTERS
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `project-65b029a2-02f6-40de-986.silver_dataset.encounters` (
  EncounterID STRING,
  PatientID STRING,
  EncounterDate DATE,
  EncounterType STRING,
  ProviderID STRING,
  DepartmentID STRING,
  ProcedureCode INT64,
  InsertedDate DATE,
  ModifiedDate DATE,
  is_quarantined BOOLEAN
);

TRUNCATE TABLE `project-65b029a2-02f6-40de-986.silver_dataset.encounters`;

INSERT INTO `project-65b029a2-02f6-40de-986.silver_dataset.encounters`
SELECT DISTINCT 
  EncounterID,
  PatientID,
  DATE(TIMESTAMP_MILLIS(CAST(EncounterDate AS INT64))) AS EncounterDate,
  EncounterType,
  ProviderID,
  DepartmentID,
  CAST(ProcedureCode AS INT64),
  DATE(TIMESTAMP_MILLIS(CAST(InsertedDate AS INT64))),
  DATE(TIMESTAMP_MILLIS(CAST(ModifiedDate AS INT64))),
  CASE 
    WHEN EncounterID IS NULL OR PatientID IS NULL OR ProviderID IS NULL THEN TRUE 
    ELSE FALSE 
  END
FROM `project-65b029a2-02f6-40de-986.bronze_dataset.encounters`;

------------------------------------------------------------
-- TRANSACTIONS (Fixed VisitDate Alias)
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS `project-65b029a2-02f6-40de-986.silver_dataset.transactions` (
  TransactionID STRING,
  EncounterID STRING,
  PatientID STRING,
  ProviderID STRING,
  DeptID STRING,
  VisitDate DATE,
  ServiceDate DATE,
  PaidDate DATE,
  VisitType STRING,
  Amount FLOAT64,
  AmountType STRING,
  PaidAmount FLOAT64,
  ClaimID STRING,
  PayorID STRING,
  ProcedureCode INT64,
  ICDCode STRING,
  LineOfBusiness STRING,
  MedicaidID STRING,
  MedicareID STRING,
  InsertDate DATE,
  ModifiedDate DATE,
  is_quarantined BOOLEAN
);

TRUNCATE TABLE `project-65b029a2-02f6-40de-986.silver_dataset.transactions`;

INSERT INTO `project-65b029a2-02f6-40de-986.silver_dataset.transactions`
SELECT DISTINCT 
  TransactionID,
  EncounterID,
  PatientID,
  ProviderID,
  DeptID,
  DATE(TIMESTAMP_MILLIS(CAST(VisitDate AS INT64))) AS VisitDate,
  DATE(TIMESTAMP_MILLIS(CAST(ServiceDate AS INT64))) AS ServiceDate,
  DATE(TIMESTAMP_MILLIS(CAST(PaidDate AS INT64))) AS PaidDate,
  VisitType,
  CAST(Amount AS FLOAT64),
  AmountType,
  CAST(PaidAmount AS FLOAT64),
  ClaimID,
  PayorID,
  CAST(ProcedureCode AS INT64),
  ICDCode,
  LineOfBusiness,
  MedicaidID,
  MedicareID,
  DATE(TIMESTAMP_MILLIS(CAST(InsertDate AS INT64))),
  DATE(TIMESTAMP_MILLIS(CAST(ModifiedDate AS INT64))),
  CASE 
    WHEN TransactionID IS NULL OR PatientID IS NULL OR EncounterID IS NULL THEN TRUE 
    ELSE FALSE 
  END
FROM `project-65b029a2-02f6-40de-986.bronze_dataset.transactions`;
