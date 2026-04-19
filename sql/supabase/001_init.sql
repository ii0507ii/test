-- Supabase PM DB 초기 스키마
-- 문서: DB-SCHEMA-001 v0.1 §4
-- 대상: Supabase PostgreSQL (Auth schema 전제)

BEGIN;

-- pm_projects ----------------------------------------------------------------
CREATE TABLE public.pm_projects (
    id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name         text        NOT NULL,
    description  text,
    status       text        NOT NULL DEFAULT 'active'
                             CHECK (status IN ('active', 'archived')),
    created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_pm_projects_owner ON public.pm_projects (owner_id);

-- pm_milestones --------------------------------------------------------------
CREATE TABLE public.pm_milestones (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id  uuid        NOT NULL REFERENCES public.pm_projects(id) ON DELETE CASCADE,
    code        text        NOT NULL,
    title       text        NOT NULL,
    due_date    date,
    status      text        NOT NULL DEFAULT 'planned'
                            CHECK (status IN ('planned', 'in_progress', 'done')),
    created_at  timestamptz NOT NULL DEFAULT now(),
    UNIQUE (project_id, code)
);

-- pm_tasks -------------------------------------------------------------------
CREATE TABLE public.pm_tasks (
    id                     uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
    project_id             uuid         NOT NULL REFERENCES public.pm_projects(id) ON DELETE CASCADE,
    milestone_id           uuid         REFERENCES public.pm_milestones(id) ON DELETE SET NULL,
    title                  text         NOT NULL,
    description            text,
    priority               text         NOT NULL DEFAULT 'mid'
                                        CHECK (priority IN ('low', 'mid', 'high')),
    status                 text         NOT NULL DEFAULT 'todo'
                                        CHECK (status IN ('todo', 'doing', 'done', 'blocked')),
    estimate_hours         numeric(6,2),
    owen_requirement_ref   text,
    created_at             timestamptz  NOT NULL DEFAULT now(),
    updated_at             timestamptz  NOT NULL DEFAULT now()
);

CREATE INDEX idx_pm_tasks_project   ON public.pm_tasks (project_id);
CREATE INDEX idx_pm_tasks_milestone ON public.pm_tasks (milestone_id);
CREATE INDEX idx_pm_tasks_status    ON public.pm_tasks (status);

-- pm_task_comments -----------------------------------------------------------
CREATE TABLE public.pm_task_comments (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id     uuid        NOT NULL REFERENCES public.pm_tasks(id) ON DELETE CASCADE,
    author_id   uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    body        text        NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_pm_comments_task ON public.pm_task_comments (task_id);

-- updated_at 트리거 ----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.pm_set_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pm_tasks_updated BEFORE UPDATE ON public.pm_tasks
    FOR EACH ROW EXECUTE FUNCTION public.pm_set_updated_at();

-- RLS ------------------------------------------------------------------------
ALTER TABLE public.pm_projects      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pm_milestones    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pm_tasks         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pm_task_comments ENABLE ROW LEVEL SECURITY;

-- pm_projects: 소유자만
CREATE POLICY pm_projects_owner_all ON public.pm_projects
    FOR ALL TO authenticated
    USING  (owner_id = auth.uid())
    WITH CHECK (owner_id = auth.uid());

-- pm_milestones: 프로젝트 소유자만
CREATE POLICY pm_milestones_owner_all ON public.pm_milestones
    FOR ALL TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.pm_projects p
        WHERE p.id = pm_milestones.project_id AND p.owner_id = auth.uid()
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.pm_projects p
        WHERE p.id = pm_milestones.project_id AND p.owner_id = auth.uid()
    ));

-- pm_tasks: 프로젝트 소유자만
CREATE POLICY pm_tasks_owner_all ON public.pm_tasks
    FOR ALL TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.pm_projects p
        WHERE p.id = pm_tasks.project_id AND p.owner_id = auth.uid()
    ))
    WITH CHECK (EXISTS (
        SELECT 1 FROM public.pm_projects p
        WHERE p.id = pm_tasks.project_id AND p.owner_id = auth.uid()
    ));

-- pm_task_comments: 작성자 본인 + 프로젝트 소유자 읽기
CREATE POLICY pm_comments_select ON public.pm_task_comments
    FOR SELECT TO authenticated
    USING (EXISTS (
        SELECT 1 FROM public.pm_tasks t
        JOIN public.pm_projects p ON p.id = t.project_id
        WHERE t.id = pm_task_comments.task_id AND p.owner_id = auth.uid()
    ));

CREATE POLICY pm_comments_insert ON public.pm_task_comments
    FOR INSERT TO authenticated
    WITH CHECK (author_id = auth.uid());

CREATE POLICY pm_comments_author_modify ON public.pm_task_comments
    FOR UPDATE TO authenticated
    USING (author_id = auth.uid())
    WITH CHECK (author_id = auth.uid());

CREATE POLICY pm_comments_author_delete ON public.pm_task_comments
    FOR DELETE TO authenticated
    USING (author_id = auth.uid());

COMMIT;
