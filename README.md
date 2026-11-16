# AppRivera · Connectant la Ribera

Projecte Intermodular 2DAM · Iker Camarena | Carlos Collado | Eric Miñana

Directori comarcal de serveis socials i comunitaris de la Ribera Alta i la Ribera Baixa.
Aquest repositori conté **només la part d'usuari** (consulta): no hi ha part d'administració.

| Capa | Tecnologia | Carpeta |
| --- | --- | --- |
| Base de dades | PostgreSQL 16 | [`bd/`](bd) |
| API | Java 21 · Javalin · JDBC | [`api/`](api) |
| Importador de dades | Java (mateix projecte Maven) | [`api/`](api) |
| Client | Flutter (sense Riverpod) | [`app/`](app) |
| Servidor | Docker Compose | [`docker-compose.yml`](docker-compose.yml) |
| Dades del Sprint 1 | XML · CSV · JSON (originals) | [`dades/sprint-1/`](dades/sprint-1) |

La planificació i les decisions estan a [`docs/GUIA.md`](docs/GUIA.md).

## Arrencada ràpida

_(s'anirà completant a mesura que avancen les fases)_
