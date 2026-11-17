# Guia de desenvolupament · Connectant la Ribera (part d'usuari)

**Objectiu del Sprint 1:** integrar les dades proporcionades (XML, CSV, JSON) en PostgreSQL,
servir-les amb una API Javalin/JDBC i consultar-les des d'un client Flutter amb directori,
filtres i mapa. Tot el codi, la interfície i la documentació són en valencià.

## Estructura

```
AppRivera/
├── docker-compose.yml      → postgres + api
├── bd/                     → esquema SQL (DDL)
├── api/                    → Java 21 + Javalin + JDBC (Maven)
│   └── ...importacio/      → càrrega de dades/sprint-1
├── dades/sprint-1/         → fitxers originals del sprint (no es modifiquen)
├── app/                    → Flutter (només usuari, sense Riverpod)
└── docs/                   → aquesta guia, diagrama ER, decisions
```

## Fases

1. **Base del repo**: estructura, README, `.gitignore`, dades originals.
2. **Base de dades** segons el diagrama ER ([`diagrama-er.png`](diagrama-er.png)):
   - Principals: `entitat`, `centre`, `servei`.
   - Relacions: `prestacio` (servei ↔ entitat, única), `prestacio_centre` (única),
     `titular_id` i `gestor_id` dins de `centre` (nul·lables).
   - Suport: `comarca`, `municipi`, catàlegs, `servei_collectiu`, `contacte`, `horari`,
     `franja`, `font`.
   - Identitat d'importació: font + tipus de registre + codi d'origen → ID generat.
3. **Docker**: PostgreSQL 16 + API; l'esquema es crea en arrancar.
4. **Importador Java**: ordre del LLEGEIX-ME, transacció, sense duplicats en repetir,
   parser CSV real (`\N` = nul), errors amb el camí exacte, comprovació contra
   `manifest.json` i `comprovacions.json`.
5. **API REST de només lectura**: municipis, catàlegs, serveis (amb filtres), centres,
   entitats.
6. **App Flutter**: directori amb cerca, filtres, fitxes de detall amb contactes clicables,
   mapa (`flutter_map` + OpenStreetMap amb atribució). Estat amb `StatefulWidget` + `setState` (sense gestors d'estat).
7. **Proves i documentació**.

## Decisions preses

- Els canvis es pugen directament a `main` amb commits menuts (`pull --rebase` abans de push).
- Plataforma principal de prova: **Flutter web**; URL de l'API per defecte `http://localhost:8080`.
- No hi ha login ni edició (sense part d'administrador).
- Les coordenades desconegudes queden nul·les: el mapa només mostra centres amb punt
  conegut; mai s'usa `(0,0)`.
- Els titulars i gestors no acreditats queden nuls; no es creen prestacions amb entitats fictícies.
