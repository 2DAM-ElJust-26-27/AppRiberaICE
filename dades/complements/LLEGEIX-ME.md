# Dades complementàries · punts dels centres

El paquet del Sprint 1 només aporta el punt de CEN05. Per a la demostració del mapa
completem altres punts **sense modificar les fonts inicials** (`dades/sprint-1`), amb una
font documentada i revisió explícita, tal com permet el LLEGEIX-ME del sprint.

- **Font:** geocodificador oficial de CartoCiudad (IGN/CNIG), codi de procedència `G01`
  (vegeu `fonts.json`). Consultat el 2026-11-16 a partir de l'adreça de cada centre.
- **Revisió:** cada fila s'ha comprovat manualment: municipi correcte i carrer coincident.
  La columna `resultat_geocodificador` indica què va retornar el servei.
- **Precisió (`precisio_punt`):**
  - `portal`: el número exacte de l'adreça.
  - `portal_proxim`: el número no consta i s'usa el portal veí (pocs metres).
  - `carrer`: adreça sense número (s/n): punt representatiu del carrer, no de l'edifici.
  - `toponim`: el geocodificador coneix el centre pel nom.
- **No tenen punt:** CEN06 (el carrer no consta a CartoCiudad), CEN14, CEN15 i CEN21 (sense
  adreça). No s'inventen coordenades ni s'usa `(0,0)`.

L'importador aplica aquest fitxer després del paquet principal i **només omple els centres
que encara no tenen punt**: no sobreescriu CEN05 ni cap punt corregit a la base de dades.
Cap d'aquests punts és una mesura GPS verificada.
