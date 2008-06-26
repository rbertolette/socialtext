BEGIN;

-- There is a missing cascading action on the person(id) foreign key. If we
-- call ST::UserID->delete, we'll get an app error as a result.

ALTER TABLE ONLY person
    DROP CONSTRAINT person_id_fk;

ALTER TABLE ONLY person
    ADD CONSTRAINT person_id_fk
            FOREIGN KEY (id)
            REFERENCES "UserId"(system_unique_id) ON DELETE CASCADE;

ALTER TABLE ONLY person
    DROP CONSTRAINT person_assistant_id_fk;

ALTER TABLE ONLY person
    ADD CONSTRAINT person_assistant_id_fk
            FOREIGN KEY (assistant_id)
            REFERENCES "UserId"(system_unique_id) ON DELETE CASCADE;

ALTER TABLE ONLY person
    DROP CONSTRAINT person_supervisor_id_fk;

ALTER TABLE ONLY person
    ADD CONSTRAINT person_supervisor_id_fk
            FOREIGN KEY (supervisor_id)
            REFERENCES "UserId"(system_unique_id) ON DELETE CASCADE;

ALTER TABLE ONLY person_watched_people__person
    DROP CONSTRAINT person_watched_people_fk;

ALTER TABLE ONLY person_watched_people__person
    ADD CONSTRAINT person_watched_people_fk
            FOREIGN KEY (person_id1)
            REFERENCES "UserId"(system_unique_id) ON DELETE CASCADE;

ALTER TABLE ONLY person_watched_people__person
    DROP CONSTRAINT person_watched_people_inverse_fk;

ALTER TABLE ONLY person_watched_people__person
    ADD CONSTRAINT person_watched_people_inverse_fk
            FOREIGN KEY (person_id2)
            REFERENCES "UserId"(system_unique_id) ON DELETE CASCADE;

ALTER TABLE ONLY tag_people__person_tags
    DROP CONSTRAINT person_tags_fk;

ALTER TABLE ONLY tag_people__person_tags
    ADD CONSTRAINT person_tags_fk
            FOREIGN KEY (person_id)
            REFERENCES "UserId"(system_unique_id) ON DELETE CASCADE;

ALTER TABLE event
    DROP CONSTRAINT event_actor_id_fk;

ALTER TABLE ONLY event
    ADD CONSTRAINT event_actor_id_fk
            FOREIGN KEY (actor_id)
            REFERENCES "UserId"(system_unique_id) ON DELETE CASCADE;

COMMIT;
