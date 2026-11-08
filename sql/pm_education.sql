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
