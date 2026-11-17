# AppRivera · Connectant la Ribera

Projecte Intermodular 2DAM · Iker Camarena | Carlos Collado | Eric Miñana

Directori comarcal de serveis socials i comunitaris de la Ribera Alta i la Ribera Baixa.
Aquest repositori conté **només la part d'usuari** (consulta): no hi ha part d'administració.

| Capa | Tecnologia | Carpeta |
| --- | --- | --- |
| Base de dades | PostgreSQL 16 | [`bd/`](bd) |
| API + importador | Java 21 · Javalin 6 · JDBC (Maven) | [`api/`](api) |
| Client | Flutter (estat amb `StatefulWidget` + `setState`, sense gestors d'estat) | [`app/`](app) |
| Servidor | Docker Compose | [`docker-compose.yml`](docker-compose.yml) |
| Dades del Sprint 1 | XML · CSV · JSON (originals, sense modificar) | [`dades/sprint-1/`](dades/sprint-1) |
| Dades complementàries | punts de 16 centres geocodificats amb CartoCiudad (IGN/CNIG) | [`dades/complements/`](dades/complements) |

La planificació i les decisions estan a [`docs/GUIA.md`](docs/GUIA.md).

## Arrencada ràpida

### 1. Servidor (BD + API)

Cal tindre Docker Desktop en marxa.

```bash
docker compose up -d --build
```

- `ribera-bd`: PostgreSQL 16 al port **5432** (BD `ribera`, usuari `ribera`, contrasenya `ribera`).
  La primera vegada executa `bd/01-esquema.sql` i crea les taules.
- `ribera-api`: API al port **8080**. En arrancar importa `dades/sprint-1` (sense duplicar res si
  ja estava importat) i mostra als logs els recomptes i les comprovacions:

```bash
docker compose logs api
```

Comprova que funciona: <http://localhost:8080/api/serveis>

Per esborrar la base de dades i començar de zero: `docker compose down -v`.

### 2. App Flutter

Tres pestanyes (Centres és la primera en obrir l'app):

- **Serveis**: l'assistent guiat «Carlos Collado» pregunta per a qui és l'ajuda, en quin municipi i quin tipus de
  lloc, i proposa els serveis que encaixen (només ofereix opcions amb resultats; també accepta text lliure).
- **Centres**: mapa amb filtres de serveis (col·lectiu, municipi, tipus de centre, servei concret); mostra els
  centres on es presten. Els que no tenen coordenades apareixen a la llista sota el mapa.
- **Entitats**: llista d'entitats amb filtre per forma jurídica.


```bash
cd app
flutter pub get
flutter run -d chrome
```

Per defecte l'app usa l'API a `http://localhost:8080`. Per canviar-la:

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:8080   # navegador
flutter run --dart-define=API_URL=http://10.0.2.2:8080               # emulador Android
```

El repo només inclou la plataforma web. Per afegir Android (o altres) sense tocar `lib/`:

```bash
cd app
flutter create . --platforms=android
```

## API (només lectura)

| Mètode i ruta | Descripció |
| --- | --- |
| `GET /api/municipis` | 47 municipis amb la comarca |
| `GET /api/catalegs` | col·lectius, tipus de centre, formes jurídiques, comarques |
| `GET /api/serveis?q=&municipi=&collectiu=&tipus_centre=` | cerca de serveis |
| `GET /api/serveis/{id}` | fitxa: col·lectius, contactes, horaris, prestacions i centres |
| `GET /api/centres?q=&municipi=&collectiu=&tipus_centre=&servei=&amb_punt=true` | centres (`servei`: on es presta aquest servei; `amb_punt`: només amb coordenades) |
| `GET /api/centres/{id}` | fitxa: titular, gestor, contactes, horaris, serveis |
| `GET /api/entitats?q=` · `GET /api/entitats/{id}` | entitats i la seua fitxa |

- `q` cerca per paraules, sense accents ni majúscules (nom, descripció, col·lectiu, entitat, municipi).
- `municipi` és l'**id** del municipi; en serveis vol dir «prestat en un centre d'aquest municipi»
  (prestació → centre → municipi), no la seu de l'entitat.
- `collectiu` i `tipus_centre` són codis (`COL_MAJORS`, `TC04`…).

## Desenvolupament sense Docker

```bash
# API (necessita un PostgreSQL local amb l'esquema creat)
cd api
mvn package
IMPORTAR_EN_ARRANCAR=true java -jar target/api.jar

# Només importar
java -cp target/api.jar ribera.importacio.ImportadorCli ../dades/sprint-1
```

Variables d'entorn: `BD_URL`, `BD_USUARI`, `BD_CONTRASENYA`, `PORT`, `IMPORTAR_EN_ARRANCAR`, `DIR_DADES`.

## Proves

```bash
# Java: parser CSV (sempre) + integració importador/API (amb una BD de proves que s'esborra!)
cd api
BD_PROVES_URL=jdbc:postgresql://localhost:5432/ribera_proves mvn test

# Flutter
cd app
flutter test
```

Les proves d'integració comproven els recomptes de `manifest.json`, totes les consultes de
`comprovacions.json`, que una segona càrrega no duplica res ni esborra correccions, i que una
referència trencada s'informa amb el camí exacte i desfà la importació.
