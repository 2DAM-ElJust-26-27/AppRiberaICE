-- =====================================================================
-- Connectant la Ribera · Esquema PostgreSQL (Sprint 1)
-- Basat en el diagrama ER: CENTRES, ENTITATS, SERVEIS
--   Titula / Gestiona  : centre -> entitat (titular_id, gestor_id)
--   Prestació          : servei <-> entitat  (taula prestacio)
--   Oferir en          : prestació <-> centre (taula prestacio_centre)
-- Els ID són generats per PostgreSQL. Els codis d'origen (ENT…, CEN…,
-- SER…, MUN…) es guarden a identitat_importacio, no a les taules.
-- =====================================================================

-- ---------- Procedència i identitat d'importació ----------

-- Fonts documentals de procedència (F01, W03…) de fonts.json
CREATE TABLE font (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codi        VARCHAR(20)  NOT NULL UNIQUE,
    referencia  TEXT         NOT NULL
);

-- Paquets d'importació (p. ex. 'ribera-sprint1')
CREATE TABLE font_importacio (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom     VARCHAR(60) NOT NULL UNIQUE,
    versio  INTEGER,
    data_darrera_carrega TIMESTAMPTZ
);

-- font + tipus de registre + codi d'origen -> ID generat
CREATE TABLE identitat_importacio (
    font_importacio_id  BIGINT      NOT NULL REFERENCES font_importacio(id),
    tipus_registre      VARCHAR(20) NOT NULL
        CHECK (tipus_registre IN ('comarca','municipi','entitat','centre','servei')),
    codi_origen         VARCHAR(40) NOT NULL,
    registre_id         BIGINT      NOT NULL,
    PRIMARY KEY (font_importacio_id, tipus_registre, codi_origen),
    UNIQUE (font_importacio_id, tipus_registre, registre_id)
);

-- ---------- Territori ----------

CREATE TABLE comarca (
    id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom  VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE municipi (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom         VARCHAR(120) NOT NULL,
    comarca_id  BIGINT NOT NULL REFERENCES comarca(id),
    font_id     BIGINT REFERENCES font(id),
    UNIQUE (nom, comarca_id)
);

-- ---------- Catàlegs ----------

CREATE TABLE forma_juridica (
    id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codi  VARCHAR(20)  NOT NULL UNIQUE,
    nom   VARCHAR(120) NOT NULL
);

CREATE TABLE tipus_centre (
    id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codi  VARCHAR(20)  NOT NULL UNIQUE,
    nom   VARCHAR(120) NOT NULL
);

CREATE TABLE collectiu (
    id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codi  VARCHAR(30)  NOT NULL UNIQUE,
    nom   VARCHAR(160) NOT NULL
);

-- ---------- Entitats principals ----------

CREATE TABLE entitat (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom                VARCHAR(200) NOT NULL,
    forma_juridica_id  BIGINT REFERENCES forma_juridica(id),
    sector             VARCHAR(40),
    adreca             VARCHAR(250),
    municipi_id        BIGINT REFERENCES municipi(id),
    codi_postal        VARCHAR(10),          -- text: no identifica municipis
    font_id            BIGINT REFERENCES font(id),
    adreca_font_id     BIGINT REFERENCES font(id)
);

CREATE TABLE centre (
    id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom              VARCHAR(200) NOT NULL,
    tipus_centre_id  BIGINT REFERENCES tipus_centre(id),
    titular_id       BIGINT REFERENCES entitat(id),   -- Titula
    gestor_id        BIGINT REFERENCES entitat(id),   -- Gestiona
    adreca           VARCHAR(250),
    municipi_id      BIGINT REFERENCES municipi(id),
    codi_postal      VARCHAR(10),
    latitud          NUMERIC(9,6),
    longitud         NUMERIC(9,6),
    precisio_punt    VARCHAR(30),
    font_punt_id     BIGINT REFERENCES font(id),
    imatge           TEXT,
    font_id          BIGINT REFERENCES font(id),
    adreca_font_id   BIGINT REFERENCES font(id),
    -- un punt és complet o no existeix (mai (0,0) com a "desconegut")
    CONSTRAINT centre_punt_complet CHECK ((latitud IS NULL) = (longitud IS NULL)),
    CONSTRAINT centre_latitud_rang  CHECK (latitud  IS NULL OR latitud  BETWEEN -90  AND 90),
    CONSTRAINT centre_longitud_rang CHECK (longitud IS NULL OR longitud BETWEEN -180 AND 180),
    CONSTRAINT centre_punt_no_zero  CHECK (latitud IS NULL OR NOT (latitud = 0 AND longitud = 0))
);

CREATE TABLE servei (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom             VARCHAR(250) NOT NULL,
    descripcio      TEXT,
    modalitat_codi  VARCHAR(30),
    via_acces       TEXT,
    cobertura       TEXT,
    imatge          TEXT,
    observacions    TEXT,
    font_id         BIGINT REFERENCES font(id)
);

-- Relació múltiple servei <-> col·lectiu
CREATE TABLE servei_collectiu (
    servei_id     BIGINT NOT NULL REFERENCES servei(id) ON DELETE CASCADE,
    collectiu_id  BIGINT NOT NULL REFERENCES collectiu(id),
    PRIMARY KEY (servei_id, collectiu_id)
);

-- ---------- Relacions del diagrama ----------

-- Prestació: una entitat presta un servei (parella única)
CREATE TABLE prestacio (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    servei_id   BIGINT NOT NULL REFERENCES servei(id) ON DELETE CASCADE,
    entitat_id  BIGINT NOT NULL REFERENCES entitat(id),
    font_id     BIGINT REFERENCES font(id),
    UNIQUE (servei_id, entitat_id)
);

-- Oferir en: la prestació es fa en un centre (parella única)
CREATE TABLE prestacio_centre (
    prestacio_id  BIGINT NOT NULL REFERENCES prestacio(id) ON DELETE CASCADE,
    centre_id     BIGINT NOT NULL REFERENCES centre(id),
    font_id       BIGINT REFERENCES font(id),
    PRIMARY KEY (prestacio_id, centre_id)
);

-- ---------- Fills incrustats: contactes i horaris ----------

CREATE TABLE contacte (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entitat_id  BIGINT REFERENCES entitat(id) ON DELETE CASCADE,
    centre_id   BIGINT REFERENCES centre(id)  ON DELETE CASCADE,
    servei_id   BIGINT REFERENCES servei(id)  ON DELETE CASCADE,
    tipus       VARCHAR(30)  NOT NULL,        -- telèfon, correu, web…
    valor       VARCHAR(250) NOT NULL,
    font_id     BIGINT REFERENCES font(id),
    ordre       INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT contacte_un_pare CHECK (num_nonnulls(entitat_id, centre_id, servei_id) = 1)
);

CREATE TABLE horari (
    id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entitat_id     BIGINT REFERENCES entitat(id) ON DELETE CASCADE,
    centre_id      BIGINT REFERENCES centre(id)  ON DELETE CASCADE,
    servei_id      BIGINT REFERENCES servei(id)  ON DELETE CASCADE,
    tipus          VARCHAR(40),
    descripcio     TEXT,                         -- text documental («amb cita»…)
    zona_horaria   VARCHAR(40) NOT NULL DEFAULT 'Europe/Madrid',
    vigent_des_de  DATE,
    vigent_fins_a  DATE,
    font_id        BIGINT REFERENCES font(id),
    ordre          INTEGER NOT NULL DEFAULT 0,
    CONSTRAINT horari_un_pare CHECK (num_nonnulls(entitat_id, centre_id, servei_id) = 1),
    CONSTRAINT horari_vigencia CHECK (vigent_fins_a IS NULL OR vigent_des_de IS NULL OR vigent_fins_a >= vigent_des_de)
);

CREATE TABLE franja (
    id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    horari_id          BIGINT   NOT NULL REFERENCES horari(id) ON DELETE CASCADE,
    dia_setmana        SMALLINT NOT NULL CHECK (dia_setmana BETWEEN 1 AND 7),  -- ISO: 1 = dilluns
    hora_inici         TIME     NOT NULL,
    hora_fi            TIME     NOT NULL,
    final_dia_seguent  BOOLEAN  NOT NULL DEFAULT FALSE,
    UNIQUE (horari_id, dia_setmana, hora_inici, hora_fi, final_dia_seguent)
);

-- ---------- Índexs per a les consultes de l'API ----------

CREATE INDEX idx_municipi_comarca   ON municipi(comarca_id);
CREATE INDEX idx_centre_municipi    ON centre(municipi_id);
CREATE INDEX idx_centre_tipus       ON centre(tipus_centre_id);
CREATE INDEX idx_entitat_municipi   ON entitat(municipi_id);
CREATE INDEX idx_prestacio_entitat  ON prestacio(entitat_id);
CREATE INDEX idx_prest_centre_centre ON prestacio_centre(centre_id);
CREATE INDEX idx_servei_col_col     ON servei_collectiu(collectiu_id);
CREATE INDEX idx_contacte_entitat   ON contacte(entitat_id);
CREATE INDEX idx_contacte_centre    ON contacte(centre_id);
CREATE INDEX idx_contacte_servei    ON contacte(servei_id);
CREATE INDEX idx_horari_entitat     ON horari(entitat_id);
CREATE INDEX idx_horari_centre      ON horari(centre_id);
CREATE INDEX idx_horari_servei      ON horari(servei_id);
