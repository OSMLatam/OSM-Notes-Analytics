-- Creates datamart for users.
--
-- Author: Andres Gomez (AngocA)
-- Version: 2025-10-26

CREATE TABLE IF NOT EXISTS dwh.datamartUsers (
 -- Static values (username could change)
 dimension_user_id INTEGER, -- The dimension id user.
 user_id INTEGER, -- The OSM id user.
 username VARCHAR,
 date_starting_creating_notes DATE, -- Oldest opened note.
 date_starting_solving_notes DATE, -- Oldest closed note.
 first_open_note_id INTEGER, -- Oldest.
 first_commented_note_id INTEGER,
 first_closed_note_id INTEGER,
 first_reopened_note_id INTEGER,

 -- Dynamic values
 id_contributor_type SMALLINT, -- Note contributor type.
 last_year_activity CHAR(371),  -- Last year's actions. GitHub tile style.
 lastest_open_note_id INTEGER, -- Newest.
 lastest_commented_note_id INTEGER,
 lastest_closed_note_id INTEGER,
 lastest_reopened_note_id INTEGER,
 dates_most_open JSON, -- Day when the user opened the most notes.
 dates_most_closed JSON, -- Day when the user closed notes the most.
 hashtags JSON, -- List of used hashtag.
 countries_open_notes JSON, -- List of countries where opening notes.
 countries_solving_notes JSON, -- List of countries where closing notes.
 countries_open_notes_current_month JSON,
 countries_solving_notes_current_month JSON,
 countries_open_notes_current_day JSON,
 countries_solving_notes_current_day JSON,
 working_hours_of_week_opening JSON, -- Hours when the user creates notes.
 working_hours_of_week_commenting JSON, -- Hours when the user comments notes.
 working_hours_of_week_closing JSON, -- Hours when the user closes notes.
 history_whole_open INTEGER, -- Qty opened notes.
 history_whole_commented INTEGER, -- Qty commented notes.
 history_whole_closed INTEGER, -- Qty closed notes.
 history_whole_closed_with_comment INTEGER, -- Qty closed notes with comments.
 history_whole_reopened INTEGER, -- Qty reopened notes.
 history_year_open INTEGER, -- Qty in the current year.
 history_year_commented INTEGER,
 history_year_closed INTEGER,
 history_year_closed_with_comment INTEGER,
 history_year_reopened INTEGER,
 history_month_open INTEGER, -- Qty in the current month.
 history_month_commented INTEGER,
 history_month_closed INTEGER,
 history_month_closed_with_comment INTEGER,
 history_month_reopened INTEGER,
 history_day_open INTEGER, -- Qty in the current day.
 history_day_commented INTEGER,
 history_day_closed INTEGER,
 history_day_closed_with_comment INTEGER,
 history_day_reopened INTEGER,
 history_2013_open INTEGER, -- Qty in 2013
 history_2013_commented INTEGER,
 history_2013_closed INTEGER,
 history_2013_closed_with_comment INTEGER,
 history_2013_reopened INTEGER,
 ranking_countries_opening_2013 JSON,
 ranking_countries_closing_2013 JSON,
 json_exported BOOLEAN DEFAULT FALSE,
 avg_days_to_resolution DECIMAL(10,2),
 median_days_to_resolution DECIMAL(10,2),
 notes_resolved_count INTEGER,
 notes_still_open_count INTEGER,
 resolution_rate DECIMAL(5,2),
 applications_used JSON,
 most_used_application_id INTEGER,
 mobile_apps_count INTEGER,
 desktop_apps_count INTEGER,
 avg_comment_length DECIMAL(10,2),
 comments_with_url_count INTEGER,
 comments_with_url_pct DECIMAL(5,2),
 comments_with_mention_count INTEGER,
 comments_with_mention_pct DECIMAL(5,2),
 avg_comments_per_note DECIMAL(10,2),
 active_notes_count INTEGER,
 notes_backlog_size INTEGER,
 notes_age_distribution JSON,
 notes_created_last_30_days INTEGER,
 notes_resolved_last_30_days INTEGER
);
COMMENT ON TABLE dwh.datamartUsers IS
  'Contains all precalculated statistical values for users';
COMMENT ON COLUMN dwh.datamartUsers.dimension_user_id IS
  'Surrogated ID from dimension''user';
COMMENT ON COLUMN dwh.datamartUsers.user_id IS 'OSM id user';
COMMENT ON COLUMN dwh.datamartUsers.username IS
  'OSM username at the time of the lastest note activity';
COMMENT ON COLUMN dwh.datamartUsers.date_starting_creating_notes IS
  'Oldest opened note';
COMMENT ON COLUMN dwh.datamartUsers.date_starting_solving_notes IS
  'Oldest closed note';
COMMENT ON COLUMN dwh.datamartUsers.first_open_note_id IS 'First opened note';
COMMENT ON COLUMN dwh.datamartUsers.first_commented_note_id IS
  'First commented note';
COMMENT ON COLUMN dwh.datamartUsers.first_closed_note_id IS
  'First closed note';
COMMENT ON COLUMN dwh.datamartUsers.first_reopened_note_id IS
  'First reopened note';
COMMENT ON COLUMN dwh.datamartUsers.id_contributor_type IS
  'Note contributor type';
COMMENT ON COLUMN dwh.datamartUsers.last_year_activity IS
  'Last year''s actions. GitHub tile style.';
COMMENT ON COLUMN dwh.datamartUsers.lastest_open_note_id IS
  'Most recent opened note';
COMMENT ON COLUMN dwh.datamartUsers.lastest_commented_note_id IS
  'Most recent commented note';
COMMENT ON COLUMN dwh.datamartUsers.lastest_closed_note_id IS
  'Most recent closed note';
COMMENT ON COLUMN dwh.datamartUsers.lastest_reopened_note_id IS
  'Most recent reopened note';
COMMENT ON COLUMN dwh.datamartUsers.dates_most_open IS
  'The dates on which the user opened the most notes';
COMMENT ON COLUMN dwh.datamartUsers.dates_most_closed IS
  'The dates on which the user closed the most notes';
COMMENT ON COLUMN dwh.datamartUsers.hashtags IS 'List of used hashtag';
COMMENT ON COLUMN dwh.datamartUsers.countries_open_notes IS
  'List of countries where opening notes';
COMMENT ON COLUMN dwh.datamartUsers.countries_solving_notes IS
  'List of countries where closing notes';
COMMENT ON COLUMN dwh.datamartUsers.countries_open_notes_current_month IS
  'List of countries where opening notes in the current month';
COMMENT ON COLUMN dwh.datamartUsers.countries_solving_notes_current_month IS
  'List of countries where closing notes in the current month';
COMMENT ON COLUMN dwh.datamartUsers.countries_open_notes_current_day IS
  'List of countries where opening notes today';
COMMENT ON COLUMN dwh.datamartUsers.countries_solving_notes_current_day IS
  'List of countries where closing notes today';
COMMENT ON COLUMN dwh.datamartUsers.working_hours_of_week_opening IS
  'Hours when the user creates notes';
COMMENT ON COLUMN dwh.datamartUsers.working_hours_of_week_commenting IS
  'Hours when the user comments notes';
COMMENT ON COLUMN dwh.datamartUsers.working_hours_of_week_closing IS
  'Hours when the user closes notes';
COMMENT ON COLUMN dwh.datamartUsers.history_whole_open IS
  'Qty opened notes in the whole history';
COMMENT ON COLUMN dwh.datamartUsers.history_whole_commented IS
  'Qty commented notes in the whole history';
COMMENT ON COLUMN dwh.datamartUsers.history_whole_closed IS
  'Qty closed notes in the whole history';
COMMENT ON COLUMN dwh.datamartUsers.history_whole_closed_with_comment IS
  'Qty closed notes with comments in the whole history';
COMMENT ON COLUMN dwh.datamartUsers.history_whole_reopened IS
  'Qty reopened notes in the whole history';
COMMENT ON COLUMN dwh.datamartUsers.history_year_open IS
  'Qty of notes opened in the current year';
COMMENT ON COLUMN dwh.datamartUsers.history_year_commented IS
  'Qty of notes commented in the current year';
COMMENT ON COLUMN dwh.datamartUsers.history_year_closed IS
  'Qty of notes closed in the current year';
COMMENT ON COLUMN dwh.datamartUsers.history_year_closed_with_comment IS
  'Qty of notes closed with comment in the current year';
COMMENT ON COLUMN dwh.datamartUsers.history_year_reopened IS
  'Qty of notes reopened in the current year';
COMMENT ON COLUMN dwh.datamartUsers.history_month_open IS
  'Qty of notes opened in the current month';
COMMENT ON COLUMN dwh.datamartUsers.history_month_commented IS
  'Qty of notes commented in the current month';
COMMENT ON COLUMN dwh.datamartUsers.history_month_closed IS
  'Qty of notes closed in the current month';
COMMENT ON COLUMN dwh.datamartUsers.history_month_closed_with_comment IS
  'Qty of notes closed with comment in the current month';
COMMENT ON COLUMN dwh.datamartUsers.history_month_reopened IS
  'Qty of notes reopened in the current month';
COMMENT ON COLUMN dwh.datamartUsers.history_day_open IS
  'Qty of notes opened in the current day';
COMMENT ON COLUMN dwh.datamartUsers.history_day_commented IS
  'Qty of notes commented in the current day';
COMMENT ON COLUMN dwh.datamartUsers.history_day_closed IS
  'Qty of notes closed in the current day';
COMMENT ON COLUMN dwh.datamartUsers.history_day_closed_with_comment IS
  'Qty of notes closed with comments in the current day';
COMMENT ON COLUMN dwh.datamartUsers.history_day_reopened IS
  'Qty of notes reopened in the current day';
COMMENT ON COLUMN dwh.datamartUsers.history_2013_open IS
  'Qty of notes opened in 2013';
COMMENT ON COLUMN dwh.datamartUsers.history_2013_commented IS
  'Qty of notes commented in 2013';
COMMENT ON COLUMN dwh.datamartUsers.history_2013_closed IS
  'Qty of notes closed in 2013';
COMMENT ON COLUMN dwh.datamartUsers.history_2013_closed_with_comment IS
  'Qty of notes closed with comment in 2013';
COMMENT ON COLUMN dwh.datamartUsers.history_2013_reopened IS
  'Qty of notes reopened in 2013';
COMMENT ON COLUMN dwh.datamartUsers.ranking_countries_opening_2013 IS
  'Ranking of countries where creating notes on year 2013';
COMMENT ON COLUMN dwh.datamartUsers.ranking_countries_closing_2013 IS
  'Ranking of countries where closing notes on year 2013';
COMMENT ON COLUMN dwh.datamartUsers.json_exported IS
  'Flag indicating if user data has been exported to JSON';
COMMENT ON COLUMN dwh.datamartUsers.avg_days_to_resolution IS
  'Average days to resolve notes (from open to most recent close) by this user';
COMMENT ON COLUMN dwh.datamartUsers.median_days_to_resolution IS
  'Median days to resolve notes (from open to most recent close) by this user';
COMMENT ON COLUMN dwh.datamartUsers.notes_resolved_count IS
  'Number of notes that have been closed by this user';
COMMENT ON COLUMN dwh.datamartUsers.notes_still_open_count IS
  'Number of notes opened by this user but never closed';
COMMENT ON COLUMN dwh.datamartUsers.resolution_rate IS
  'Percentage of notes resolved by this user (closed/total opened)';
COMMENT ON COLUMN dwh.datamartUsers.applications_used IS
  'JSON array of applications used by this user to create notes';
COMMENT ON COLUMN dwh.datamartUsers.most_used_application_id IS
  'ID of the most used application by this user';
COMMENT ON COLUMN dwh.datamartUsers.mobile_apps_count IS
  'Number of mobile applications used by this user';
COMMENT ON COLUMN dwh.datamartUsers.desktop_apps_count IS
  'Number of desktop/web applications used by this user';
COMMENT ON COLUMN dwh.datamartUsers.avg_comment_length IS
  'Average length of comments in characters by this user';
COMMENT ON COLUMN dwh.datamartUsers.comments_with_url_count IS
  'Number of comments containing URLs by this user';
COMMENT ON COLUMN dwh.datamartUsers.comments_with_url_pct IS
  'Percentage of comments containing URLs by this user';
COMMENT ON COLUMN dwh.datamartUsers.comments_with_mention_count IS
  'Number of comments containing mentions by this user';
COMMENT ON COLUMN dwh.datamartUsers.comments_with_mention_pct IS
  'Percentage of comments containing mentions by this user';
COMMENT ON COLUMN dwh.datamartUsers.avg_comments_per_note IS
  'Average number of comments per note by this user';
COMMENT ON COLUMN dwh.datamartUsers.active_notes_count IS
  'Number of notes currently open by this user';
COMMENT ON COLUMN dwh.datamartUsers.notes_backlog_size IS
  'Number of notes opened by this user but not yet resolved';
COMMENT ON COLUMN dwh.datamartUsers.notes_age_distribution IS
  'JSON distribution of note ages by this user (0-7 days, 8-30 days, 31-90 days, 90+ days)';
COMMENT ON COLUMN dwh.datamartUsers.notes_created_last_30_days IS
  'Number of notes created by this user in the last 30 days';
COMMENT ON COLUMN dwh.datamartUsers.notes_resolved_last_30_days IS
  'Number of notes resolved by this user in the last 30 days';

CREATE TABLE IF NOT EXISTS dwh.badges (
 badge_id SERIAL,
 badge_name VARCHAR(64),
 description TEXT
);
COMMENT ON TABLE dwh.badges IS 'List of available badges';
COMMENT ON COLUMN dwh.badges.badge_id IS 'Id of the badge';
COMMENT ON COLUMN dwh.badges.badge_name IS 'Name of the badge';
COMMENT ON COLUMN dwh.badges.description IS 'Description of the badge';

CREATE TABLE IF NOT EXISTS dwh.badges_per_users (
 id_user INTEGER NOT NULL,
 id_badge INTEGER NOT NULL,
 date_awarded DATE NOT NULL,
 comment TEXT NULL
);
COMMENT ON TABLE dwh.badges_per_users IS 'List of badges granted to users';
COMMENT ON COLUMN dwh.badges_per_users.id_user IS
  'User id who has been granted a badge';
COMMENT ON COLUMN dwh.badges_per_users.id_badge IS 'Id of the granted badge';
COMMENT ON COLUMN dwh.badges_per_users.date_awarded IS
  'Date when the badge was granted';
COMMENT ON COLUMN dwh.badges_per_users.comment IS 'Comment about the grant';

CREATE TABLE IF NOT EXISTS dwh.contributor_types (
 contributor_type_id SERIAL,
 contributor_type_name VARCHAR(64) NOT NULL
);

CREATE TABLE IF NOT EXISTS dwh.max_date_users_processed (
  date date NOT NULL
);
COMMENT ON TABLE dwh.max_date_users_processed IS
  'Max date for users processed, to move the activities';
COMMENT ON COLUMN dwh.max_date_users_processed.date IS
  'Value of the max date of users processed';

-- Primary keys.
ALTER TABLE dwh.datamartUsers
 ADD CONSTRAINT pk_datamartUsers
 PRIMARY KEY (dimension_user_id);

ALTER TABLE dwh.badges
 ADD CONSTRAINT pk_badges
 PRIMARY KEY (badge_id);

ALTER TABLE dwh.badges_per_users
 ADD CONSTRAINT pk_badge_users
 PRIMARY KEY (id_user, id_badge);

ALTER TABLE dwh.contributor_types
 ADD CONSTRAINT pk_contributor_types
 PRIMARY KEY (contributor_type_id);

-- Foreign keys.
ALTER TABLE dwh.datamartUsers
 ADD CONSTRAINT fk_contributor_type
 FOREIGN KEY (id_contributor_type)
 REFERENCES dwh.contributor_types (contributor_type_id);

ALTER TABLE dwh.badges_per_users
 ADD CONSTRAINT fk_b_p_u_id_badge
 FOREIGN KEY (id_badge)
 REFERENCES dwh.badges (badge_id);

ALTER TABLE dwh.badges_per_users
 ADD CONSTRAINT fk_b_p_u_id_user
 FOREIGN KEY (id_user)
 REFERENCES dwh.datamartUsers (dimension_user_id);

-- Insert values
-- TODO datamart - populate badges.
INSERT INTO dwh.badges (badge_name) VALUES
 ('Test');

-- Contributor types.
INSERT INTO dwh.contributor_types (contributor_type_name) VALUES
 ('Normal Notero'), -- 1
 ('Just starting notero'), --2
 ('Newbie Notero'), -- 3
 ('All-time notero'), -- 4
 ('Hit-and-run notero'), -- 5
 ('Junior notero'), -- 6
 ('Inactive notero'), -- 7
 ('Retired notero'), -- 8
 ('Forgotten notero'), -- 9
 ('Exporadic notero'), -- 10
 ('Start closing notero'), -- 11
 ('Casual notero'), -- 12
 ('Power closing notero'), -- 13
 ('Power notero'), -- 14
 ('Crazy closing notero'), -- 15
 ('Crazy notero'), -- 16
 ('Addicted closing notero'), -- 17
 ('Addicted notero'), -- 18
 ('Epic closing notero'), -- 19
 ('Epic notero'), -- 20
 ('Bot closing notero'), -- 21
 ('Robot notero'), -- 22
 ('OoM Exception notero') -- 23
 ;

-- Processes all users.
UPDATE dwh.dimension_users
  SET modified = TRUE;
