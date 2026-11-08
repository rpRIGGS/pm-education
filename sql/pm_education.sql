CREATE TABLE IF NOT EXISTS pm_education_enrollments (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    citizenid VARCHAR(64) NOT NULL,
    institution_id VARCHAR(80) NOT NULL,
    course_id VARCHAR(80) NOT NULL,
    status ENUM('enrolled','in_progress','completed','withdrawn','dismissed') NOT NULL DEFAULT 'enrolled',
    enrolled_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_student (citizenid, status),
    UNIQUE KEY uq_student_course (citizenid, institution_id, course_id),
    KEY idx_course (institution_id, course_id)
);

CREATE TABLE IF NOT EXISTS pm_education_attempts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    enrollment_id BIGINT UNSIGNED NOT NULL,
    citizenid VARCHAR(64) NOT NULL,
    score_percent INT UNSIGNED NOT NULL,
    passed TINYINT(1) NOT NULL,
    answers_json LONGTEXT NOT NULL,
    submitted_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_enrollment (enrollment_id),
    KEY idx_citizen (citizenid)
);

-- POST instructor assessments: append to existing PM Education schema.
CREATE TABLE IF NOT EXISTS pm_education_practical_results (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
 enrollment_id BIGINT UNSIGNED NOT NULL,
 citizenid VARCHAR(64) NOT NULL,
 institution_id VARCHAR(80) NOT NULL,
 course_id VARCHAR(80) NOT NULL,
 requirement_id VARCHAR(80) NOT NULL,
 result ENUM('pass','fail','incomplete') NOT NULL,
 notes TEXT NULL,
 examiner_citizenid VARCHAR(64) NOT NULL,
 recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(id),
 KEY idx_enrollment_requirement (enrollment_id, requirement_id, recorded_at),
 KEY idx_examiner (examiner_citizenid)
);

-- Authoritative milestone awards; printed inventory items are optional and not issued here.
CREATE TABLE IF NOT EXISTS pm_education_credentials (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
 enrollment_id BIGINT UNSIGNED NOT NULL,
 citizenid VARCHAR(64) NOT NULL,
 institution_id VARCHAR(80) NOT NULL,
 credential_id VARCHAR(80) NOT NULL,
 credential_label VARCHAR(160) NOT NULL,
 status ENUM('active','suspended','revoked','expired') NOT NULL DEFAULT 'active',
 issued_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 expires_at TIMESTAMP NULL DEFAULT NULL,
 PRIMARY KEY (id),
 UNIQUE KEY uq_enrollment_credential (enrollment_id, credential_id),
 KEY idx_citizen_credential (citizenid, credential_id, status)
);

-- Append-only history of credential status decisions.
CREATE TABLE IF NOT EXISTS pm_education_credential_audit (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
 credential_id BIGINT UNSIGNED NOT NULL,
 institution_id VARCHAR(80) NOT NULL,
 subject_citizenid VARCHAR(64) NOT NULL,
 actor_citizenid VARCHAR(64) NOT NULL,
 previous_status VARCHAR(24) NOT NULL,
 new_status VARCHAR(24) NOT NULL,
 reason VARCHAR(1000) NOT NULL,
 recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(id),
 KEY idx_credential_history (credential_id, id)
);

-- Durable payment attempts and reconciliation queue. Do not delete failed refunds.
CREATE TABLE IF NOT EXISTS pm_education_payments (
 id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
 citizenid VARCHAR(64) NOT NULL,
 institution_id VARCHAR(80) NOT NULL,
 course_id VARCHAR(80) NOT NULL,
 enrollment_id BIGINT UNSIGNED NULL,
 payment_type ENUM('enrollment','exam') NOT NULL,
 money_type VARCHAR(16) NOT NULL DEFAULT 'cash',
 amount INT UNSIGNED NOT NULL,
 status ENUM('pending','charged','completed','refunded','refund_failed','failed') NOT NULL DEFAULT 'pending',
 details VARCHAR(255) NULL,
 created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
 PRIMARY KEY(id),
 KEY idx_payment_student (citizenid, created_at),
 KEY idx_payment_reconcile (status, updated_at)
);
