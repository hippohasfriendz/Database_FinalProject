-- ========================================================
-- 校園設備借用管理系統
-- Database Final Project
-- MS SQL Server Version
-- ========================================================

-- ========================================================
-- 0. 安全刪除舊資料表
-- 注意：必須依照外鍵相依性的反向順序刪除
-- ========================================================

DROP TABLE IF EXISTS RETURN_RECORD;
DROP TABLE IF EXISTS BORROW_RECORD;
DROP TABLE IF EXISTS BORROW_REQUEST_DETAIL;
DROP TABLE IF EXISTS BORROW_REQUEST;
DROP TABLE IF EXISTS MAINTENANCE_RECORD;
DROP TABLE IF EXISTS EQUIPMENT;
DROP TABLE IF EXISTS EQUIPMENT_CATEGORY;
DROP TABLE IF EXISTS USER_ACCOUNT;
DROP TABLE IF EXISTS DEPARTMENT;

-- ========================================================
-- 1. DEPARTMENT：系所或單位
-- ========================================================

CREATE TABLE DEPARTMENT (
    DepartmentID INT IDENTITY(1,1) NOT NULL,
    DepartmentName NVARCHAR(50) NOT NULL,

    CONSTRAINT PK_DEPARTMENT PRIMARY KEY (DepartmentID),
    CONSTRAINT UQ_DEPARTMENT_DepartmentName UNIQUE (DepartmentName)
);

-- ========================================================
-- 2. USER_ACCOUNT：使用者帳號
-- Role：Student、Teacher、Admin
-- ========================================================

CREATE TABLE USER_ACCOUNT (
    UserID INT IDENTITY(1,1) NOT NULL,
    DepartmentID INT NOT NULL,
    FullName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    Phone NVARCHAR(20) NULL,
    Role NVARCHAR(20) NOT NULL,
    [Password] NVARCHAR(255) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),

    CONSTRAINT PK_USER_ACCOUNT PRIMARY KEY (UserID),

    CONSTRAINT FK_USER_ACCOUNT_DEPARTMENT
        FOREIGN KEY (DepartmentID)
        REFERENCES DEPARTMENT(DepartmentID),

    CONSTRAINT UQ_USER_ACCOUNT_Email UNIQUE (Email),

    CONSTRAINT CK_USER_ACCOUNT_Role
        CHECK (Role IN (N'Student', N'Teacher', N'Admin'))
);

-- ========================================================
-- 3. EQUIPMENT_CATEGORY：設備類別
-- ========================================================

CREATE TABLE EQUIPMENT_CATEGORY (
    CategoryID INT IDENTITY(1,1) NOT NULL,
    CategoryName NVARCHAR(50) NOT NULL,

    CONSTRAINT PK_EQUIPMENT_CATEGORY PRIMARY KEY (CategoryID),
    CONSTRAINT UQ_EQUIPMENT_CATEGORY_CategoryName UNIQUE (CategoryName)
);

-- ========================================================
-- 4. EQUIPMENT：設備資料
-- Status：Available、Borrowed、Maintenance、Retired
-- ========================================================

CREATE TABLE EQUIPMENT (
    EquipmentID INT IDENTITY(1,1) NOT NULL,
    CategoryID INT NOT NULL,
    EquipmentName NVARCHAR(100) NOT NULL,
    AssetTag NVARCHAR(50) NOT NULL,
    Brand NVARCHAR(50) NULL,
    Model NVARCHAR(50) NULL,
    PurchaseDate DATE NULL,
    Status NVARCHAR(20) NOT NULL DEFAULT N'Available',

    CONSTRAINT PK_EQUIPMENT PRIMARY KEY (EquipmentID),

    CONSTRAINT FK_EQUIPMENT_EQUIPMENT_CATEGORY
        FOREIGN KEY (CategoryID)
        REFERENCES EQUIPMENT_CATEGORY(CategoryID),

    CONSTRAINT UQ_EQUIPMENT_AssetTag UNIQUE (AssetTag),

    CONSTRAINT CK_EQUIPMENT_Status
        CHECK (Status IN (N'Available', N'Borrowed', N'Maintenance', N'Retired'))
);

-- ========================================================
-- 5. BORROW_REQUEST：借用申請主表
-- RequestStatus：Pending、Approved、Rejected、Cancelled
-- ApprovedBy 可為 NULL，代表尚未審核
-- ========================================================

CREATE TABLE BORROW_REQUEST (
    RequestID INT IDENTITY(1,1) NOT NULL,
    UserID INT NOT NULL,
    RequestDate DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ExpectedBorrowDate DATE NOT NULL,
    ExpectedReturnDate DATE NOT NULL,
    Purpose NVARCHAR(200) NOT NULL,
    RequestStatus NVARCHAR(20) NOT NULL DEFAULT N'Pending',
    ApprovedBy INT NULL,
    ApprovedAt DATETIME2 NULL,
    RejectReason NVARCHAR(200) NULL,

    CONSTRAINT PK_BORROW_REQUEST PRIMARY KEY (RequestID),

    CONSTRAINT FK_BORROW_REQUEST_USER_ACCOUNT
        FOREIGN KEY (UserID)
        REFERENCES USER_ACCOUNT(UserID),

    CONSTRAINT FK_BORROW_REQUEST_APPROVER
        FOREIGN KEY (ApprovedBy)
        REFERENCES USER_ACCOUNT(UserID),

    CONSTRAINT CK_BORROW_REQUEST_Status
        CHECK (RequestStatus IN (N'Pending', N'Approved', N'Rejected', N'Cancelled')),

    CONSTRAINT CK_BORROW_REQUEST_Date
        CHECK (ExpectedReturnDate >= ExpectedBorrowDate)
);

-- ========================================================
-- 6. BORROW_REQUEST_DETAIL：借用申請明細
-- 一筆申請可以包含多個設備
-- 同一筆申請不可重複借同一個設備
-- ========================================================

CREATE TABLE BORROW_REQUEST_DETAIL (
    RequestDetailID INT IDENTITY(1,1) NOT NULL,
    RequestID INT NOT NULL,
    EquipmentID INT NOT NULL,

    CONSTRAINT PK_BORROW_REQUEST_DETAIL PRIMARY KEY (RequestDetailID),

    CONSTRAINT FK_BORROW_REQUEST_DETAIL_BORROW_REQUEST
        FOREIGN KEY (RequestID)
        REFERENCES BORROW_REQUEST(RequestID),

    CONSTRAINT FK_BORROW_REQUEST_DETAIL_EQUIPMENT
        FOREIGN KEY (EquipmentID)
        REFERENCES EQUIPMENT(EquipmentID),

    CONSTRAINT UQ_BORROW_REQUEST_DETAIL_Request_Equipment
        UNIQUE (RequestID, EquipmentID)
);

-- ========================================================
-- 7. BORROW_RECORD：實際借出紀錄
-- 一筆核准的申請最多只會產生一筆借出紀錄
-- BorrowStatus：Borrowed、Returned、Lost
-- ========================================================

CREATE TABLE BORROW_RECORD (
    BorrowRecordID INT IDENTITY(1,1) NOT NULL,
    RequestID INT NOT NULL,
    BorrowedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    DueDate DATE NOT NULL,
    HandledBy INT NOT NULL,
    BorrowStatus NVARCHAR(20) NOT NULL DEFAULT N'Borrowed',

    CONSTRAINT PK_BORROW_RECORD PRIMARY KEY (BorrowRecordID),

    CONSTRAINT FK_BORROW_RECORD_BORROW_REQUEST
        FOREIGN KEY (RequestID)
        REFERENCES BORROW_REQUEST(RequestID),

    CONSTRAINT FK_BORROW_RECORD_HANDLER
        FOREIGN KEY (HandledBy)
        REFERENCES USER_ACCOUNT(UserID),

    CONSTRAINT UQ_BORROW_RECORD_RequestID UNIQUE (RequestID),

    CONSTRAINT CK_BORROW_RECORD_Status
        CHECK (BorrowStatus IN (N'Borrowed', N'Returned', N'Lost'))
);

-- ========================================================
-- 8. RETURN_RECORD：歸還紀錄
-- 一筆借出紀錄最多只會有一筆歸還紀錄
-- ConditionStatus：Good、Damaged、Lost
-- ========================================================

CREATE TABLE RETURN_RECORD (
    ReturnRecordID INT IDENTITY(1,1) NOT NULL,
    BorrowRecordID INT NOT NULL,
    ReturnedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    ConditionStatus NVARCHAR(20) NOT NULL,
    LateFee DECIMAL(10,2) NOT NULL DEFAULT 0,
    HandledBy INT NOT NULL,
    Note NVARCHAR(200) NULL,

    CONSTRAINT PK_RETURN_RECORD PRIMARY KEY (ReturnRecordID),

    CONSTRAINT FK_RETURN_RECORD_BORROW_RECORD
        FOREIGN KEY (BorrowRecordID)
        REFERENCES BORROW_RECORD(BorrowRecordID),

    CONSTRAINT FK_RETURN_RECORD_HANDLER
        FOREIGN KEY (HandledBy)
        REFERENCES USER_ACCOUNT(UserID),

    CONSTRAINT UQ_RETURN_RECORD_BorrowRecordID UNIQUE (BorrowRecordID),

    CONSTRAINT CK_RETURN_RECORD_ConditionStatus
        CHECK (ConditionStatus IN (N'Good', N'Damaged', N'Lost')),

    CONSTRAINT CK_RETURN_RECORD_LateFee
        CHECK (LateFee >= 0)
);

-- ========================================================
-- 9. MAINTENANCE_RECORD：設備維修紀錄
-- MaintenanceStatus：Reported、Processing、Completed、Cancelled
-- ========================================================

CREATE TABLE MAINTENANCE_RECORD (
    MaintenanceID INT IDENTITY(1,1) NOT NULL,
    EquipmentID INT NOT NULL,
    ReportedBy INT NOT NULL,
    IssueDescription NVARCHAR(300) NOT NULL,
    MaintenanceStatus NVARCHAR(20) NOT NULL DEFAULT N'Reported',
    ReportedAt DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    CompletedAt DATETIME2 NULL,
    Note NVARCHAR(200) NULL,

    CONSTRAINT PK_MAINTENANCE_RECORD PRIMARY KEY (MaintenanceID),

    CONSTRAINT FK_MAINTENANCE_RECORD_EQUIPMENT
        FOREIGN KEY (EquipmentID)
        REFERENCES EQUIPMENT(EquipmentID),

    CONSTRAINT FK_MAINTENANCE_RECORD_REPORTER
        FOREIGN KEY (ReportedBy)
        REFERENCES USER_ACCOUNT(UserID),

    CONSTRAINT CK_MAINTENANCE_RECORD_Status
        CHECK (MaintenanceStatus IN (N'Reported', N'Processing', N'Completed', N'Cancelled')),

    CONSTRAINT CK_MAINTENANCE_RECORD_CompletedAt
        CHECK (CompletedAt IS NULL OR CompletedAt >= ReportedAt)
);





-- ========================================================
-- 校園設備借用管理系統
-- INSERT 測試資料
-- MS SQL Server Version
-- ========================================================

-- ========================================================
-- 1. DEPARTMENT：系所或單位
-- ========================================================

INSERT INTO DEPARTMENT (DepartmentName)
VALUES
(N'資訊管理學系'),
(N'資訊工程學系'),
(N'電機工程學系'),
(N'管理學院'),
(N'教務處');

-- ========================================================
-- 2. USER_ACCOUNT：使用者帳號
-- Role：Student、Teacher、Admin
-- ========================================================

INSERT INTO USER_ACCOUNT
(DepartmentID, FullName, Email, Phone, Role, [Password], CreatedAt)
VALUES
(5, N'王志明', N'admin01@yzu.edu.tw', N'0911000001', N'Admin',   N'admin123',   '2026-05-01T08:30:00'),
(5, N'林雅婷', N'admin02@yzu.edu.tw', N'0911000002', N'Admin',   N'admin123',   '2026-05-01T08:40:00'),
(1, N'陳柏宇', N'student01@yzu.edu.tw', N'0922000001', N'Student', N'student123', '2026-05-02T09:00:00'),
(1, N'張家瑋', N'student02@yzu.edu.tw', N'0922000002', N'Student', N'student123', '2026-05-02T09:10:00'),
(2, N'黃品睿', N'student03@yzu.edu.tw', N'0922000003', N'Student', N'student123', '2026-05-03T10:00:00'),
(3, N'李承恩', N'student04@yzu.edu.tw', N'0922000004', N'Student', N'student123', '2026-05-03T10:20:00'),
(4, N'吳佳蓉', N'teacher01@yzu.edu.tw', N'0933000001', N'Teacher', N'teacher123', '2026-05-04T11:00:00'),
(1, N'鄭明哲', N'teacher02@yzu.edu.tw', N'0933000002', N'Teacher', N'teacher123', '2026-05-04T11:10:00'),
(2, N'周冠廷', N'teacher03@yzu.edu.tw', N'0933000003', N'Teacher', N'teacher123', '2026-05-05T13:00:00'),
(3, N'蔡宜庭', N'student05@yzu.edu.tw', N'0922000005', N'Student', N'student123', '2026-05-05T13:30:00');

-- ========================================================
-- 3. EQUIPMENT_CATEGORY：設備類別
-- ========================================================

INSERT INTO EQUIPMENT_CATEGORY (CategoryName)
VALUES
(N'筆記型電腦'),
(N'投影設備'),
(N'攝影設備'),
(N'音訊設備'),
(N'簡報輔助設備');

-- ========================================================
-- 4. EQUIPMENT：設備資料
-- Status：Available、Borrowed、Maintenance、Retired
-- ========================================================

INSERT INTO EQUIPMENT
(CategoryID, EquipmentName, AssetTag, Brand, Model, PurchaseDate, Status)
VALUES
(1, N'Lenovo ThinkPad E14', N'NB-001', N'Lenovo', N'ThinkPad E14', '2024-09-10', N'Available'),
(1, N'ASUS ExpertBook B5', N'NB-002', N'ASUS', N'ExpertBook B5', '2024-10-05', N'Borrowed'),
(1, N'Acer Swift 3', N'NB-003', N'Acer', N'Swift 3', '2023-11-18', N'Maintenance'),

(2, N'Epson 商務投影機', N'PJ-001', N'Epson', N'EB-X49', '2023-08-20', N'Available'),
(2, N'BenQ 無線投影機', N'PJ-002', N'BenQ', N'EH600', '2024-01-12', N'Borrowed'),

(3, N'Canon EOS R50 相機', N'CAM-001', N'Canon', N'EOS R50', '2024-03-15', N'Maintenance'),
(3, N'Sony ZV-E10 相機', N'CAM-002', N'Sony', N'ZV-E10', '2024-04-01', N'Available'),

(4, N'Rode 無線麥克風', N'MIC-001', N'Rode', N'Wireless GO II', '2023-12-12', N'Borrowed'),
(4, N'JBL 藍牙喇叭', N'SPK-001', N'JBL', N'Charge 5', '2024-02-18', N'Available'),

(5, N'Logitech 簡報筆', N'PRE-001', N'Logitech', N'R500', '2023-10-08', N'Available'),
(5, N'三腳架', N'TRI-001', N'Manfrotto', N'Compact Action', '2022-09-30', N'Maintenance'),
(5, N'舊款投影布幕', N'SCR-001', N'None', N'Old Screen', '2020-06-01', N'Retired');

-- ========================================================
-- 5. BORROW_REQUEST：借用申請主表
-- RequestStatus：Pending、Approved、Rejected、Cancelled
-- ========================================================

INSERT INTO BORROW_REQUEST
(UserID, RequestDate, ExpectedBorrowDate, ExpectedReturnDate, Purpose, RequestStatus, ApprovedBy, ApprovedAt, RejectReason)
VALUES
(3, '2026-06-10T09:20:00', '2026-06-20', '2026-06-27', N'資料庫期末專案展示，需要筆電與投影機。', N'Approved', 1, '2026-06-10T14:00:00', NULL),

(4, '2026-06-01T10:10:00', '2026-06-05', '2026-06-10', N'社團成果發表，需要攝影設備。', N'Approved', 2, '2026-06-01T15:30:00', NULL),

(5, '2026-06-18T13:40:00', '2026-06-25', '2026-06-28', N'課程分組報告，需要筆電。', N'Pending', NULL, NULL, NULL),

(6, '2026-06-12T11:00:00', '2026-06-15', '2026-06-16', N'臨時活動需要投影設備。', N'Rejected', 1, '2026-06-12T16:20:00', N'申請時間過短，設備已安排給其他活動。'),

(7, '2026-05-28T08:50:00', '2026-06-02', '2026-06-04', N'課堂錄影，需要相機與腳架。', N'Approved', 2, '2026-05-28T12:30:00', NULL),

(8, '2026-06-14T15:15:00', '2026-06-21', '2026-06-23', N'專題口頭報告，需要無線麥克風。', N'Approved', 1, '2026-06-14T16:00:00', NULL),

(9, '2026-06-16T09:30:00', '2026-06-22', '2026-06-24', N'系上活動原本需要簡報筆，後續取消。', N'Cancelled', NULL, NULL, NULL),

(10, '2026-06-19T10:45:00', '2026-06-26', '2026-06-27', N'學生專題展示，需要藍牙喇叭。', N'Pending', NULL, NULL, NULL);

-- ========================================================
-- 6. BORROW_REQUEST_DETAIL：借用申請明細
-- 一筆申請可以包含多個設備
-- ========================================================

INSERT INTO BORROW_REQUEST_DETAIL
(RequestID, EquipmentID)
VALUES
(1, 2),
(1, 5),

(2, 7),

(3, 1),

(4, 4),

(5, 6),
(5, 11),

(6, 8),

(7, 10),

(8, 9);

-- ========================================================
-- 7. BORROW_RECORD：實際借出紀錄
-- BorrowStatus：Borrowed、Returned、Lost
-- ========================================================

INSERT INTO BORROW_RECORD
(RequestID, BorrowedAt, DueDate, HandledBy, BorrowStatus)
VALUES
(1, '2026-06-20T09:00:00', '2026-06-27', 1, N'Borrowed'),

(2, '2026-06-05T10:00:00', '2026-06-10', 2, N'Returned'),

(5, '2026-06-02T09:30:00', '2026-06-04', 2, N'Returned'),

(6, '2026-06-21T13:00:00', '2026-06-23', 1, N'Borrowed');

-- ========================================================
-- 8. RETURN_RECORD：歸還紀錄
-- ConditionStatus：Good、Damaged、Lost
-- ========================================================

INSERT INTO RETURN_RECORD
(BorrowRecordID, ReturnedAt, ConditionStatus, LateFee, HandledBy, Note)
VALUES
(2, '2026-06-10T16:30:00', N'Good', 0, 2, N'設備正常歸還。'),

(3, '2026-06-05T11:20:00', N'Damaged', 100, 1, N'相機鏡頭蓋遺失，腳架關節鬆動，已轉維修處理。');

-- ========================================================
-- 9. MAINTENANCE_RECORD：設備維修紀錄
-- MaintenanceStatus：Reported、Processing、Completed、Cancelled
-- ========================================================

INSERT INTO MAINTENANCE_RECORD
(EquipmentID, ReportedBy, IssueDescription, MaintenanceStatus, ReportedAt, CompletedAt, Note)
VALUES
(3, 1, N'筆電無法正常開機，疑似電池或主機板異常。', N'Processing', '2026-06-08T09:00:00', NULL, N'已送交資訊組檢測。'),

(6, 7, N'相機鏡頭蓋遺失，外殼有輕微刮痕。', N'Processing', '2026-06-05T13:00:00', NULL, N'由任課教師回報，等待檢修。'),

(11, 2, N'三腳架支架鬆動，固定旋鈕無法鎖緊。', N'Reported', '2026-06-06T10:10:00', NULL, N'暫停借用。'),

(4, 6, N'投影機電源線接觸不良。', N'Completed', '2026-05-20T14:00:00', '2026-05-22T15:30:00', N'已更換電源線，目前可正常使用。');