package ribera.importacio;

import com.fasterxml.jackson.databind.JsonNode;
import org.w3c.dom.Element;
import ribera.bd.Jdbc;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.TreeSet;

/**
 * Importa el paquet de dades del Sprint 1 (dades/sprint-1) a PostgreSQL.
 *
 * Ordre: fonts → catàlegs → territori → entitats.xml → centres.json → serveis.json
 * → punts complementaris (opcional) → comparació amb manifest i comprovacions.
 *
 * Política de repetició (càrrega idempotent, tot dins d'una transacció):
 *  - Identitat: font d'importació + tipus de registre + codi d'origen → ID generat
 *    (taula identitat_importacio). Mai es relaciona pel nom ni retallant prefixos.
 *  - Registres pare: si ja existeixen s'actualitzen; un valor nul de la font NO
 *    esborra un valor existent (no perdem correccions fetes a la BD).
 *  - Fills (contactes, horaris, franges) i relacions no es dupliquen.
 *  - Si una referència no existeix s'informa del fitxer i del camí concret i es
 *    desfà tota la importació. No es fabriquen registres.
 */
public class Importador extends BaseImportacio {

    public static final String FONT_IMPORTACIO = "ribera-sprint1";

    private final Path dir;
    private final Path dirComplements;

    public Importador(Connection connexio, Path directoriDades) {
        this(connexio, directoriDades, null);
    }

    /** @param directoriComplements carpeta opcional amb punts de centres revisats (pot ser null). */
    public Importador(Connection connexio, Path directoriDades, Path directoriComplements) {
        super(connexio);
        this.dir = directoriDades;
        this.dirComplements = directoriComplements;
    }

    /** Executa la importació completa en una transacció i retorna l'informe. */
    public InformeImportacio importa() throws Exception {
        boolean autoCommit = c.getAutoCommit();
        c.setAutoCommit(false);
        try {
            JsonNode manifest = json.readTree(dir.resolve("manifest.json").toFile());
            fontImportacioId = Jdbc.retornaId(c,
                    "INSERT INTO font_importacio (nom, versio, data_darrera_carrega) VALUES (?, ?, now()) "
                    + "ON CONFLICT (nom) DO UPDATE SET versio = EXCLUDED.versio, data_darrera_carrega = now() RETURNING id",
                    manifest.path("font_importacio").asText(FONT_IMPORTACIO), manifest.path("versio").asInt());

            importaFonts(dir.resolve("fonts.json"));
            importaCatalegs();
            importaTerritori();
            importaEntitats();
            importaCentres();
            importaServeis();
            importaPuntsComplementaris();

            if (!informe.correcte()) {
                c.rollback();
                return informe;
            }
            compara(manifest);
            c.commit();
            return informe;
        } catch (Exception e) {
            c.rollback();
            throw e;
        } finally {
            c.setAutoCommit(autoCommit);
        }
    }

    // ------------------------------------------------------------------ fonts, catàlegs i territori

    private void importaFonts(Path fitxer) throws Exception {
        for (JsonNode f : json.readTree(fitxer.toFile()).path("fonts")) {
            fonts.put(f.get("codi").asText(), Jdbc.retornaId(c, "INSERT INTO font (codi, referencia) VALUES (?, ?) "
                    + "ON CONFLICT (codi) DO UPDATE SET referencia = EXCLUDED.referencia RETURNING id",
                    f.get("codi").asText(), f.get("referencia").asText()));
        }
    }

    private void importaCatalegs() throws Exception {
        Map<String, Map<String, Long>> desti = Map.of(
                "forma_juridica", formesJuridiques, "tipus_centre", tipusCentre, "collectiu", collectius);
        int fila = 1;
        for (Map<String, String> r : LectorCsv.llegeix(dir.resolve("catalegs.csv"))) {
            fila++;
            String taula = r.get("tipus");
            if (!desti.containsKey(taula)) {
                informe.error("catalegs.csv", "fila " + fila + ".tipus", "tipus de catàleg desconegut «" + taula + "»");
                continue;
            }
            desti.get(taula).put(r.get("codi"), Jdbc.retornaId(c, "INSERT INTO " + taula + " (codi, nom) VALUES (?, ?) "
                    + "ON CONFLICT (codi) DO UPDATE SET nom = EXCLUDED.nom RETURNING id", r.get("codi"), r.get("nom")));
        }
    }

    private void importaTerritori() throws Exception {
        Map<String, String> nomsComarca = new HashMap<>();
        int fila = 1;
        for (Map<String, String> r : LectorCsv.llegeix(dir.resolve("territori.csv"))) {
            String cami = "fila " + (++fila);
            String codiCom = r.get("comarca_codi"), nomCom = r.get("comarca_nom");
            String anterior = nomsComarca.putIfAbsent(codiCom, nomCom);
            if (anterior != null && !anterior.equals(nomCom)) {
                informe.error("territori.csv", cami + ".comarca_nom",
                        "la comarca " + codiCom + " té noms contradictoris: «" + anterior + "» i «" + nomCom + "»");
                continue;
            }
            long comarcaId = desa("comarca", "comarca", codiCom, camps("nom", nomCom));
            desa("municipi", "municipi", r.get("codi"), camps("nom", r.get("nom"), "comarca_id", comarcaId,
                    "font_id", font(r.get("font_codi"), "territori.csv", cami + ".font_codi")));
        }
    }

    // ------------------------------------------------------------------ entitats, centres i serveis

    private void importaEntitats() throws Exception {
        DocumentBuilderFactory f = DocumentBuilderFactory.newInstance();
        f.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        f.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        f.setExpandEntityReferences(false);
        Element arrel = f.newDocumentBuilder().parse(dir.resolve("entitats.xml").toFile()).getDocumentElement();

        String fitxer = "entitats.xml";
        List<Element> entitats = fills(arrel);
        for (int i = 0; i < entitats.size(); i++) {
            JsonNode n = xmlAJson(entitats.get(i));
            String cami = "entitat[" + i + "]";
            String codi = txt(n, "codi");
            if (codi == null || codi.isBlank()) { informe.error(fitxer, cami + ".codi", "falta el codi"); continue; }

            long id = desa("entitat", "entitat", codi, camps(
                    "nom", txt(n, "nom"),
                    "forma_juridica_id", cataleg(formesJuridiques, txt(n, "forma_juridica_codi"), fitxer, cami + ".forma_juridica_codi"),
                    "sector", txt(n, "sector"),
                    "adreca", adrecaNeta(txt(n, "adreca")),
                    "municipi_id", referencia("municipi", txt(n, "municipi_codi"), fitxer, cami + ".municipi_codi"),
                    "codi_postal", txt(n, "codi_postal"),
                    "font_id", font(n, "font_codi", fitxer, cami),
                    "adreca_font_id", font(n, "adreca_font_codi", fitxer, cami)));
            contactes("entitat_id", id, n.path("contactes"), fitxer, cami);
            horaris("entitat_id", id, n.path("horaris"), fitxer, cami);
        }
    }

    private void importaCentres() throws Exception {
        String fitxer = "centres.json";
        JsonNode arrel = json.readTree(dir.resolve(fitxer).toFile());
        for (int i = 0; i < arrel.size(); i++) {
            JsonNode n = arrel.get(i);
            String cami = "centres[" + i + "]";
            String codi = txt(n, "codi");
            if (codi == null) { informe.error(fitxer, cami + ".codi", "falta el codi"); continue; }

            BigDecimal lat = num(n, "latitud"), lon = num(n, "longitud");
            if ((lat == null) != (lon == null)) {
                informe.error(fitxer, cami, "latitud i longitud han d'estar les dues o cap");
                continue;
            }
            if (lat != null && lat.signum() == 0 && lon.signum() == 0) {
                informe.error(fitxer, cami, "el punt (0,0) no és una coordenada vàlida; useu null si és desconeguda");
                continue;
            }
            long id = desa("centre", "centre", codi, camps(
                    "nom", txt(n, "nom"),
                    "tipus_centre_id", cataleg(tipusCentre, txt(n, "tipus_centre_codi"), fitxer, cami + ".tipus_centre_codi"),
                    "titular_id", referencia("entitat", txt(n, "titular_codi"), fitxer, cami + ".titular_codi"),
                    "gestor_id", referencia("entitat", txt(n, "gestor_codi"), fitxer, cami + ".gestor_codi"),
                    "adreca", adrecaNeta(txt(n, "adreca")),
                    "municipi_id", referencia("municipi", txt(n, "municipi_codi"), fitxer, cami + ".municipi_codi"),
                    "codi_postal", txt(n, "codi_postal"),
                    "latitud", lat,
                    "longitud", lon,
                    "precisio_punt", txt(n, "precisio_punt"),
                    "font_punt_id", font(n, "font_punt", fitxer, cami),
                    "imatge", txt(n, "imatge"),
                    "font_id", font(n, "font_codi", fitxer, cami),
                    "adreca_font_id", font(n, "adreca_font_codi", fitxer, cami)));
            contactes("centre_id", id, n.path("contactes"), fitxer, cami);
            horaris("centre_id", id, n.path("horaris"), fitxer, cami);
        }
    }

    private void importaServeis() throws Exception {
        String fitxer = "serveis.json";
        JsonNode arrel = json.readTree(dir.resolve(fitxer).toFile());
        for (int i = 0; i < arrel.size(); i++) {
            JsonNode n = arrel.get(i);
            String cami = "serveis[" + i + "]";
            String codi = txt(n, "codi");
            if (codi == null) { informe.error(fitxer, cami + ".codi", "falta el codi"); continue; }

            long id = desa("servei", "servei", codi, camps(
                    "nom", txt(n, "nom"),
                    "descripcio", txt(n, "descripcio"),
                    "modalitat_codi", txt(n, "modalitat_codi"),
                    "via_acces", txt(n, "via_acces"),
                    "cobertura", txt(n, "cobertura"),
                    "imatge", txt(n, "imatge"),
                    "observacions", txt(n, "observacions"),
                    "font_id", font(n, "font_codi", fitxer, cami)));

            JsonNode cols = n.path("collectius");
            for (int j = 0; j < cols.size(); j++) {
                Long colId = cataleg(collectius, cols.get(j).asText(), fitxer, cami + ".collectius[" + j + "]");
                if (colId != null) {
                    Jdbc.executa(c, "INSERT INTO servei_collectiu (servei_id, collectiu_id) VALUES (?, ?) ON CONFLICT DO NOTHING", id, colId);
                }
            }
            contactes("servei_id", id, n.path("contactes"), fitxer, cami);
            horaris("servei_id", id, n.path("horaris"), fitxer, cami);
            prestacions(id, n.path("prestacions"), fitxer, cami);
        }
    }

    /** Prestacions d'un servei: (servei, entitat) única i, per a cadascuna, els centres on es fa. */
    private void prestacions(long serveiId, JsonNode llista, String fitxer, String cami) throws Exception {
        for (int j = 0; j < llista.size(); j++) {
            JsonNode p = llista.get(j);
            String cp = cami + ".prestacions[" + j + "]";
            if (txt(p, "entitat_codi") == null) {
                informe.error(fitxer, cp + ".entitat_codi", "una prestació necessita una entitat (no se'n crea cap de fictícia)");
                continue;
            }
            Long entitatId = referencia("entitat", txt(p, "entitat_codi"), fitxer, cp + ".entitat_codi");
            Long fontId = font(p, "font_codi", fitxer, cp);
            if (entitatId == null) continue;
            long prestacioId = Jdbc.retornaId(c, "INSERT INTO prestacio (servei_id, entitat_id, font_id) VALUES (?, ?, ?) "
                    + "ON CONFLICT (servei_id, entitat_id) DO UPDATE SET font_id = COALESCE(EXCLUDED.font_id, prestacio.font_id) "
                    + "RETURNING id", serveiId, entitatId, fontId);

            JsonNode centres = p.path("centres");
            for (int k = 0; k < centres.size(); k++) {
                JsonNode pc = centres.get(k);
                String cpc = cp + ".centres[" + k + "]";
                if (txt(pc, "centre_codi") == null) informe.error(fitxer, cpc + ".centre_codi", "falta el codi del centre");
                Long centreId = referencia("centre", txt(pc, "centre_codi"), fitxer, cpc + ".centre_codi");
                Long fontPc = font(pc, "font_codi", fitxer, cpc);
                if (centreId == null) continue;
                Jdbc.executa(c, "INSERT INTO prestacio_centre (prestacio_id, centre_id, font_id) VALUES (?, ?, ?) "
                        + "ON CONFLICT (prestacio_id, centre_id) DO UPDATE SET font_id = COALESCE(EXCLUDED.font_id, prestacio_centre.font_id)",
                        prestacioId, centreId, fontPc);
            }
        }
    }

    // ------------------------------------------------------------------ punts complementaris

    /**
     * Punts de centres d'una font complementària documentada (dades/complements).
     * Només omplin centres sense punt: no sobreescriuen el de la font inicial ni cap correcció.
     */
    private void importaPuntsComplementaris() throws Exception {
        if (dirComplements == null || !Files.exists(dirComplements.resolve("punts-centres.csv"))) return;
        String fitxer = "complements/punts-centres.csv";
        if (Files.exists(dirComplements.resolve("fonts.json"))) importaFonts(dirComplements.resolve("fonts.json"));

        int fila = 1;
        for (Map<String, String> r : LectorCsv.llegeix(dirComplements.resolve("punts-centres.csv"))) {
            String cami = "fila " + (++fila);
            Long centreId = referencia("centre", r.get("codi"), fitxer, cami + ".codi");
            Long fontId = font(r.get("font_codi"), fitxer, cami + ".font_codi");
            BigDecimal lat, lon;
            try {
                lat = new BigDecimal(r.get("latitud"));
                lon = new BigDecimal(r.get("longitud"));
            } catch (RuntimeException e) {
                informe.error(fitxer, cami, "latitud/longitud no vàlides");
                continue;
            }
            if (lat.signum() == 0 && lon.signum() == 0) {
                informe.error(fitxer, cami, "el punt (0,0) no és vàlid");
                continue;
            }
            if (centreId == null) continue;
            if (Jdbc.executa(c, "UPDATE centre SET latitud = ?, longitud = ?, precisio_punt = ?, font_punt_id = ? "
                    + "WHERE id = ? AND latitud IS NULL AND longitud IS NULL", lat, lon, r.get("precisio_punt"), fontId, centreId) > 0) {
                informe.nou("punt_complementari");
            }
        }
    }

    // ------------------------------------------------------------------ recomptes i comprovacions

    private static final Map<String, String> TAULES_RECOMPTE = Map.of(
            "entitats", "entitat", "centres", "centre", "serveis", "servei", "prestacions", "prestacio",
            "prestacions_centres", "prestacio_centre", "contactes", "contacte", "horaris", "horari", "municipis", "municipi");

    private void compara(JsonNode manifest) throws Exception {
        JsonNode rec = manifest.path("recomptes");
        for (var e : new java.util.TreeMap<>(TAULES_RECOMPTE).entrySet()) {
            if (!rec.has(e.getKey())) continue;
            informe.recomptes.put(e.getKey(), new long[]{rec.get(e.getKey()).asLong(), Jdbc.compta(c, "SELECT count(*) FROM " + e.getValue())});
        }
        if (!informe.recomptesCorrectes()) {
            informe.avisos.add("Els recomptes no coincideixen amb manifest.json (normal si la BD té fitxes afegides fora del paquet).");
        }

        Path fitxerComp = dir.resolve("comprovacions.json");
        if (!Files.exists(fitxerComp)) return;
        JsonNode comp = json.readTree(fitxerComp.toFile());
        for (var noms = comp.fieldNames(); noms.hasNext(); ) {
            String nom = noms.next();
            if (!Comprovacions.CONSULTES.containsKey(nom)) {
                informe.avisos.add("Comprovació sense consulta definida: " + nom);
                continue;
            }
            TreeSet<String> esperat = new TreeSet<>();
            comp.get(nom).forEach(x -> esperat.add(x.asText()));
            TreeSet<String> obtingut = new TreeSet<>(Comprovacions.executa(c, nom, fontImportacioId));
            informe.comprovacions.put(nom, List.of(new ArrayList<>(esperat), new ArrayList<>(obtingut)));
        }
    }
}
