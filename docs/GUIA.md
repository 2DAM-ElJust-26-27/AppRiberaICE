# Guia de desenvolupament · Connectant la Ribera (part d'usuari)

**Objectiu del Sprint 1:** integrar les dades proporcionades (XML, CSV, JSON) en PostgreSQL,
servir-les amb una API Javalin/JDBC i consultar-les des d'un client Flutter amb mapa,
assistent i fitxes. Tot el codi, la interfície i la documentació són en valencià.

## Estructura

```
AppRibera/
├── docker-compose.yml      → contenidors bd (PostgreSQL) i api (Java)
├── bd/01-esquema.sql       → taules de la base de dades
├── dades/sprint-1/         → fitxers originals del sprint (no es modifiquen)
├── dades/complements/      → coordenades buscades a CartoCiudad
├── api/src/main/java/ribera/
│   ├── Aplicacio.java      → arrancada i rutes de l'API
│   ├── Consultes.java      → els SELECT de cada ruta
│   ├── BaseDades.java      → connexió i mètodes per fer consultes
│   ├── Importador.java     → carrega els fitxers a la base de dades
│   └── LectorCsv.java      → llig CSV amb comes dins de cometes
├── app/lib/
│   ├── main.dart           → pestanyes (barra a baix o vertical a la dreta)
│   ├── models.dart         → Centre, Servei i Entitat amb fromJson
│   ├── api.dart            → peticions HTTP a l'API
│   ├── widgets.dart        → peces comunes de les fitxes
│   └── pantalles/          → centres, assistent, entitats i les tres fitxes
└── docs/                   → aquesta guia i el diagrama ER
```

## Com funciona

1. **Base de dades** segons el diagrama ER ([`diagrama-er.png`](diagrama-er.png)):
   `entitat`, `centre` i `servei`, relacionats per `prestacio` (quina entitat fa el servei)
   i `prestacio_centre` (en quin centre es fa). Contactes i horaris van en taules a part.
2. **Docker** arranca PostgreSQL (que crea les taules la primera vegada) i l'API.
3. **Importador**: si la base de dades està buida, l'API llig els fitxers en ordre
   (catàlegs, territori, entitats, centres, serveis, punts) dins d'una transacció.
   Guarda en mapes quin ID ha rebut cada codi (CEN05 → 12) per enllaçar les taules.
4. **API**: totes les rutes són GET. `Consultes` torna mapes i llistes i Javalin els
   converteix a JSON. Vegeu les rutes al [README](../README.md).
5. **App**: cada pestanya demana les dades amb `api.dart` i les mostra amb `FutureBuilder`.
   Els canvis de pantalla (filtre, mapa o llista, preguntes de l'assistent) es fan amb `setState`.

## Decisions preses

- Plataforma principal de prova: **Flutter web**; URL de l'API per defecte `http://localhost:8080`.
- No hi ha login ni edició (sense part d'administrador): l'API només consulta.
- Sense gestors d'estat (Riverpod, Provider): només `StatefulWidget`, `setState` i `FutureBuilder`.
- Les coordenades desconegudes queden nul·les: el mapa només mostra centres amb punt
  conegut i la resta ixen a la llista. Mai s'usa `(0,0)`.
- No s'inventen dades: titulars i gestors que no consten queden buits.
