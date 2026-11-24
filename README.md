# AppRibera · Connectant la Ribera

Projecte Intermodular 2DAM · Iker Camarena | Carlos Collado | Eric Miñana

Directori comarcal de serveis socials i comunitaris de la Ribera Alta i la Ribera Baixa.
Aquest repositori conté **només la part d'usuari** (consulta): no hi ha part d'administració.

| Capa | Tecnologia | Carpeta |
| --- | --- | --- |
| Base de dades | PostgreSQL 16 | [`bd/`](bd) |
| API + importador de consola | Java 21 · Javalin 6 · JDBC (Maven) | [`api/`](api) |
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
- `ribera-importador`: aplicació de consola Java que carrega `dades/` a la base de dades i
  s'acaba. Si la base de dades ja té dades, no fa res. Per veure què ha importat:

```bash
docker compose logs importador
```

- `ribera-api`: API al port **8080**. Arranca quan l'importador ha acabat.

Comprova que funciona: <http://localhost:8080/api/serveis>

Per esborrar la base de dades i començar de zero: `docker compose down -v`.

### 2. App Flutter

Tres pestanyes (Centres és la primera en obrir l'app):

- **Serveis**: l'assistent guiat «Kevin» pregunta per a qui és l'ajuda, en quin municipi i quin tipus de
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

| Ruta | Què torna |
| --- | --- |
| `GET /api/centres` | tots els centres (amb latitud i longitud si en tenen) |
| `GET /api/centres?servei={id}` | només els centres on es fa aquest servei |
| `GET /api/centres/{id}` | fitxa: titular, gestor, contactes, horaris i serveis |
| `GET /api/serveis` | tots els serveis amb els seus col·lectius, municipis i tipus de centre |
| `GET /api/serveis?municipi={id}` | serveis prestats en un centre d'aquest municipi |
| `GET /api/serveis/{id}` | fitxa: col·lectius, contactes, horaris, entitats i centres |
| `GET /api/entitats` · `GET /api/entitats/{id}` | entitats i la seua fitxa |

## Desenvolupament sense Docker

```bash
# Necessita un PostgreSQL local amb l'esquema de bd/ creat
cd api
mvn package

# 1. Importador (aplicació de consola): carrega dades/ si la base de dades està buida
java -cp target/api.jar ribera.Importador ../dades/sprint-1 ../dades/complements

# 2. API
java -jar target/api.jar
```

Variables d'entorn: `BD_URL`, `BD_USUARI`, `BD_CONTRASENYA`.

## Proves

```bash
# Java: lector CSV (sempre) + importador i API (amb una BD de proves que s'esborra!)
cd api
BD_PROVES_URL=jdbc:postgresql://localhost:5432/ribera_proves mvn test

# Flutter
cd app
flutter test
```

Les proves d'integració comproven els recomptes de `manifest.json`, algunes consultes de
`comprovacions.json` i les respostes de l'API (llistes, fitxes i errors 404/400).
