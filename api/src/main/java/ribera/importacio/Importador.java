package ribera.importacio;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import ribera.bd.Jdbc;

import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import java.math.BigDecimal;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.Date;
import java.sql.SQLException;
import java.sql.Time;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.TreeSet;

/**
 * Importa el paquet de dades del Sprint 1 (dades/sprint-1) a PostgreSQL.
 *
 * Ordre: fonts → catàlegs → territori → entitats.xml → centres.json → serveis.json.
 *
 * Política de repetició (càrrega idempotent, tot dins d'una transacció):
 *  - Identitat: font d'importació + tipus de registre + codi d'origen → ID generat
 *    (taula identitat_importacio). Mai es relaciona pel nom ni retallant prefixos.
 *  - Registres pare: si ja existeixen s'actualitzen; un valor nul de la font NO
 *    esborra un valor existent (no perdem correccions fetes a la BD).
 *  - Fills incrustats (contactes, horaris, franges): s'insereixen només si no
 *    existeix ja un fill igual del mateix pare (clau natural), per no duplicar.
 *  - Relacions: prestació (servei, entitat) i prestació–centre són úniques.
 *  - Si una referència no existeix s'informa del fitxer i del camí concret i es
 *    desfà tota la importació. No es fabriquen registres.
 */
public class Importador {

    public static final String FONT_IMPORTACIO = "ribera-sprint1";

    private final Connection c;
    private final Path dir;
    private final InformeImportacio informe = new InformeImportacio();
    private final ObjectMapper json = new ObjectMapper();

    private long fontImportacioId;
    private final Map<String, Long> fonts = new HashMap<>();
    private final Map<String, Long> formesJuridiques = new HashMap<>();
    private final Map<String, Long> tipusCentre = new HashMap<>();
    private final Map<String, Long> collectius = new HashMap<>();

    public Importador(Connection connexio, Path directoriDades) {
        this.c = connexio;
        this.dir = directoriDades;
    }

    /** Executa la importació completa en una transacció i retorna l'informe. */
    public InformeImportacio importa() throws Exception {
        boolean autoCommit = c.getAutoCommit();
        c.setAutoCommit(false);
        try {
            JsonNode manifest = json.readTree(dir.resolve("manifest.json").toFile());
            String nomFont = manifest.path("font_importacio").asText(FONT_IMPORTACIO);
            fontImportacioId = Jdbc.retornaId(c,
                    "INSERT INTO font_importacio (nom, versio, data_darrera_carrega) VALUES (?, ?, now()) "
                    + "ON CONFLICT (nom) DO UPDATE SET versio = EXCLUDED.versio, data_darrera_carrega = now() RETURNING id",
                    nomFont, manifest.path("versio").asInt());

            importaFonts();
            importaCatalegs();
            importaTerritori();
            importaEntitats();
            importaCentres();
            importaServeis();

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

    // ------------------------------------------------------------------ fonts i catàlegs

    private void importaFonts() throws Exception {
        JsonNode arrel = json.readTree(dir.resolve("fonts.json").toFile());
        for (JsonNode f : arrel.path("fonts")) {
            long id = Jdbc.retornaId(c,
                    "INSERT INTO font (codi, referencia) VALUES (?, ?) "
                    + "ON CONFLICT (codi) DO UPDATE SET referencia = EXCLUDED.referencia RETURNING id",
                    f.get("codi").asText(), f.get("referencia").asText());
            fonts.put(f.get("codi").asText(), id);
        }
    }

    private void importaCatalegs() throws Exception {
        int fila = 1;
        for (Map<String, String> r : LectorCsv.llegeix(dir.resolve("catalegs.csv"))) {
            fila++;
            String taula = switch (r.get("tipus")) {
                case "forma_juridica" -> "forma_juridica";
                case "tipus_centre" -> "tipus_centre";
                case "collectiu" -> "collectiu";
                default -> null;
            };
            if (taula == null) {
                informe.error("catalegs.csv", "fila " + fila + ".tipus", "tipus de catàleg desconegut «" + r.get("tipus") + "»");
                continue;
            }
            long id = Jdbc.retornaId(c, "INSERT INTO " + taula + " (codi, nom) VALUES (?, ?) "
                    + "ON CONFLICT (codi) DO UPDATE SET nom = EXCLUDED.nom RETURNING id", r.get("codi"), r.get("nom"));
            switch (taula) {
                case "forma_juridica" -> formesJuridiques.put(r.get("codi"), id);
                case "tipus_centre" -> tipusCentre.put(r.get("codi"), id);
                default -> collectius.put(r.get("codi"), id);
            }
        }
    }

    private void importaTerritori() throws Exception {
        Map<String, String> nomsComarca = new LinkedHashMap<>();
        Map<String, Long> comarques = new HashMap<>();
        int fila = 1;
        for (Map<String, String> r : LectorCsv.llegeix(dir.resolve("territori.csv"))) {
            fila++;
            String cami = "fila " + fila;
            String codiCom = r.get("comarca_codi"), nomCom = r.get("comarca_nom");
            String anterior = nomsComarca.putIfAbsent(codiCom, nomCom);
            if (anterior != null && !anterior.equals(nomCom)) {
                informe.error("territori.csv", cami + ".comarca_nom",
                        "la comarca " + codiCom + " té noms contradictoris: «" + anterior + "» i «" + nomCom + "»");
                continue;
            }
            Long comarcaId = comarques.get(codiCom);
            if (comarcaId == null) {
                comarcaId = resol("comarca", codiCom);
                if (comarcaId == null) {
                    comarcaId = Jdbc.retornaId(c, "INSERT INTO comarca (nom) VALUES (?) "
                            + "ON CONFLICT (nom) DO UPDATE SET nom = EXCLUDED.nom RETURNING id", nomCom);
                    registra("comarca", codiCom, comarcaId);
                } else {
                    Jdbc.executa(c, "UPDATE comarca SET nom = ? WHERE id = ?", nomCom, comarcaId);
                }
                comarques.put(codiCom, comarcaId);
            }
            Long fontId = font(r.get("font_codi"), "territori.csv", cami + ".font_codi");
            Long id = resol("municipi", r.get("codi"));
            if (id == null) {
                id = Jdbc.retornaId(c, "INSERT INTO municipi (nom, comarca_id, font_id) VALUES (?, ?, ?) RETURNING id",
                        r.get("nom"), comarcaId, fontId);
                registra("municipi", r.get("codi"), id);
                informe.nou("municipi");
            } else {
                Jdbc.executa(c, "UPDATE municipi SET nom = ?, comarca_id = ?, font_id = COALESCE(?::bigint, font_id) WHERE id = ?",
                        r.get("nom"), comarcaId, fontId, id);
            }
        }
    }

    // ------------------------------------------------------------------ entitats (XML)

    private void importaEntitats() throws Exception {
        DocumentBuilderFactory f = DocumentBuilderFactory.newInstance();
        f.setFeature(XMLConstants.FEATURE_SECURE_PROCESSING, true);
        f.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        f.setExpandEntityReferences(false);
        Document doc = f.newDocumentBuilder().parse(dir.resolve("entitats.xml").toFile());

        List<Element> entitats = fills(doc.getDocumentElement(), "entitat");
        for (int i = 0; i < entitats.size(); i++) {
            Element e = entitats.get(i);
            String fitxer = "entitats.xml";
            String cami = "entitat[" + (i + 1) + "]";
            String codi = e.getAttribute("codi");
            if (codi.isBlank()) { informe.error(fitxer, cami + "/@codi", "falta el codi"); continue; }

            Long formaId = cataleg(formesJuridiques, text(e, "forma_juridica_codi"), fitxer, cami + "/forma_juridica_codi");
            Long municipiId = referencia("municipi", text(e, "municipi_codi"), fitxer, cami + "/municipi_codi");
            Long fontId = font(text(e, "font_codi"), fitxer, cami + "/font_codi");
            Long adrecaFontId = font(text(e, "adreca_font_codi"), fitxer, cami + "/adreca_font_codi");

            Long id = resol("entitat", codi);
            if (id == null) {
                id = Jdbc.retornaId(c, "INSERT INTO entitat (nom, forma_juridica_id, sector, adreca, municipi_id, codi_postal, font_id, adreca_font_id) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
                        text(e, "nom"), formaId, text(e, "sector"), adrecaNeta(text(e, "adreca")), municipiId, text(e, "codi_postal"), fontId, adrecaFontId);
                registra("entitat", codi, id);
                informe.nou("entitat");
            } else {
                Jdbc.executa(c, "UPDATE entitat SET nom = COALESCE(?::text, nom), forma_juridica_id = COALESCE(?::bigint, forma_juridica_id), "
                        + "sector = COALESCE(?::text, sector), adreca = COALESCE(?::text, adreca), municipi_id = COALESCE(?::bigint, municipi_id), "
                        + "codi_postal = COALESCE(?::text, codi_postal), font_id = COALESCE(?::bigint, font_id), "
                        + "adreca_font_id = COALESCE(?::bigint, adreca_font_id) WHERE id = ?",
                        text(e, "nom"), formaId, text(e, "sector"), adrecaNeta(text(e, "adreca")), municipiId, text(e, "codi_postal"), fontId, adrecaFontId, id);
            }

            Element contactes = fill(e, "contactes");
            if (contactes != null) {
                List<Element> lc = fills(contactes, "contacte");
                for (int j = 0; j < lc.size(); j++) {
                    Element ct = lc.get(j);
                    String cc = cami + "/contactes/contacte[" + (j + 1) + "]";
                    contacte("entitat_id", id, text(ct, "tipus"), text(ct, "valor"), font(text(ct, "font_codi"), fitxer, cc + "/font_codi"), j, fitxer, cc);
                }
            }
            Element horaris = fill(e, "horaris");
            if (horaris != null) {
                List<Element> lh = fills(horaris, "horari");
                for (int j = 0; j < lh.size(); j++) {
                    Element h = lh.get(j);
                    String ch = cami + "/horaris/horari[" + (j + 1) + "]";
                    List<Franja> franges = new ArrayList<>();
                    Element fr = fill(h, "franges");
                    if (fr != null) {
                        List<Element> lf = fills(fr, "franja");
                        for (int k = 0; k < lf.size(); k++) {
                            Element x = lf.get(k);
                            franges.add(new Franja(text(x, "dia_setmana"), text(x, "hora_inici"), text(x, "hora_fi"),
                                    "true".equalsIgnoreCase(text(x, "final_dia_seguent")), ch + "/franges/franja[" + (k + 1) + "]"));
                        }
                    }
                    horari("entitat_id", id, text(h, "tipus"), text(h, "descripcio"), text(h, "zona_horaria"),
                            text(h, "vigent_des_de"), text(h, "vigent_fins_a"), font(text(h, "font_codi"), fitxer, ch + "/font_codi"),
                            franges, j, fitxer, ch);
                }
            }
        }
    }

    // ------------------------------------------------------------------ centres (JSON)

    private void importaCentres() throws Exception {
        String fitxer = "centres.json";
        JsonNode arrel = json.readTree(dir.resolve(fitxer).toFile());
        for (int i = 0; i < arrel.size(); i++) {
            JsonNode n = arrel.get(i);
            String cami = "centres[" + i + "]";
            String codi = txt(n, "codi");
            if (codi == null) { informe.error(fitxer, cami + ".codi", "falta el codi"); continue; }

            Long tipusId = cataleg(tipusCentre, txt(n, "tipus_centre_codi"), fitxer, cami + ".tipus_centre_codi");
            Long titularId = referencia("entitat", txt(n, "titular_codi"), fitxer, cami + ".titular_codi");
            Long gestorId = referencia("entitat", txt(n, "gestor_codi"), fitxer, cami + ".gestor_codi");
            Long municipiId = referencia("municipi", txt(n, "municipi_codi"), fitxer, cami + ".municipi_codi");
            Long fontId = font(txt(n, "font_codi"), fitxer, cami + ".font_codi");
            Long adrecaFontId = font(txt(n, "adreca_font_codi"), fitxer, cami + ".adreca_font_codi");
            Long fontPuntId = font(txt(n, "font_punt"), fitxer, cami + ".font_punt");
            BigDecimal lat = num(n, "latitud"), lon = num(n, "longitud");
            if ((lat == null) != (lon == null)) {
                informe.error(fitxer, cami, "latitud i longitud han d'estar les dues o cap");
                continue;
            }
            if (lat != null && lat.signum() == 0 && lon.signum() == 0) {
                informe.error(fitxer, cami, "el punt (0,0) no és una coordenada vàlida; useu null si és desconeguda");
                continue;
            }

            Long id = resol("centre", codi);
            Object[] valors = {txt(n, "nom"), tipusId, titularId, gestorId, adrecaNeta(txt(n, "adreca")), municipiId, txt(n, "codi_postal"),
                    lat, lon, txt(n, "precisio_punt"), fontPuntId, txt(n, "imatge"), fontId, adrecaFontId};
            if (id == null) {
                id = Jdbc.retornaId(c, "INSERT INTO centre (nom, tipus_centre_id, titular_id, gestor_id, adreca, municipi_id, codi_postal, "
                        + "latitud, longitud, precisio_punt, font_punt_id, imatge, font_id, adreca_font_id) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id", valors);
                registra("centre", codi, id);
                informe.nou("centre");
            } else {
                Object[] amb = new Object[valors.length + 1];
                System.arraycopy(valors, 0, amb, 0, valors.length);
                amb[valors.length] = id;
                // El punt s'actualitza sencer: només si la font en porta un (no esborrem punts revisats).
                Jdbc.executa(c, "UPDATE centre SET nom = COALESCE(?::text, nom), tipus_centre_id = COALESCE(?::bigint, tipus_centre_id), "
                        + "titular_id = COALESCE(?::bigint, titular_id), gestor_id = COALESCE(?::bigint, gestor_id), "
                        + "adreca = COALESCE(?::text, adreca), municipi_id = COALESCE(?::bigint, municipi_id), "
                        + "codi_postal = COALESCE(?::text, codi_postal), "
                        + "latitud = COALESCE(?::numeric, latitud), longitud = COALESCE(?::numeric, longitud), "
                        + "precisio_punt = COALESCE(?::text, precisio_punt), font_punt_id = COALESCE(?::bigint, font_punt_id), "
                        + "imatge = COALESCE(?::text, imatge), font_id = COALESCE(?::bigint, font_id), "
                        + "adreca_font_id = COALESCE(?::bigint, adreca_font_id) WHERE id = ?", amb);
            }
            contactesJson("centre_id", id, n.path("contactes"), fitxer, cami);
            horarisJson("centre_id", id, n.path("horaris"), fitxer, cami);
        }
    }

    // ------------------------------------------------------------------ serveis (JSON)

    private void importaServeis() throws Exception {
        String fitxer = "serveis.json";
        JsonNode arrel = json.readTree(dir.resolve(fitxer).toFile());
        for (int i = 0; i < arrel.size(); i++) {
            JsonNode n = arrel.get(i);
            String cami = "serveis[" + i + "]";
            String codi = txt(n, "codi");
            if (codi == null) { informe.error(fitxer, cami + ".codi", "falta el codi"); continue; }
            Long fontId = font(txt(n, "font_codi"), fitxer, cami + ".font_codi");

            Object[] valors = {txt(n, "nom"), txt(n, "descripcio"), txt(n, "modalitat_codi"), txt(n, "via_acces"),
                    txt(n, "cobertura"), txt(n, "imatge"), txt(n, "observacions"), fontId};
            Long id = resol("servei", codi);
            if (id == null) {
                id = Jdbc.retornaId(c, "INSERT INTO servei (nom, descripcio, modalitat_codi, via_acces, cobertura, imatge, observacions, font_id) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id", valors);
                registra("servei", codi, id);
                informe.nou("servei");
            } else {
                Object[] amb = new Object[valors.length + 1];
                System.arraycopy(valors, 0, amb, 0, valors.length);
                amb[valors.length] = id;
                Jdbc.executa(c, "UPDATE servei SET nom = COALESCE(?::text, nom), descripcio = COALESCE(?::text, descripcio), "
                        + "modalitat_codi = COALESCE(?::text, modalitat_codi), via_acces = COALESCE(?::text, via_acces), "
                        + "cobertura = COALESCE(?::text, cobertura), imatge = COALESCE(?::text, imatge), "
                        + "observacions = COALESCE(?::text, observacions), font_id = COALESCE(?::bigint, font_id) WHERE id = ?", amb);
            }

            // col·lectius: llista de codis → relació múltiple
            JsonNode cols = n.path("collectius");
            for (int j = 0; j < cols.size(); j++) {
                Long colId = cataleg(collectius, cols.get(j).asText(), fitxer, cami + ".collectius[" + j + "]");
                if (colId != null) {
                    Jdbc.executa(c, "INSERT INTO servei_collectiu (servei_id, collectiu_id) VALUES (?, ?) ON CONFLICT DO NOTHING", id, colId);
                }
            }
            contactesJson("servei_id", id, n.path("contactes"), fitxer, cami);
            horarisJson("servei_id", id, n.path("horaris"), fitxer, cami);

            // prestacions: (servei, entitat) única; després prestació–centre
            JsonNode prest = n.path("prestacions");
            for (int j = 0; j < prest.size(); j++) {
                JsonNode p = prest.get(j);
                String cp = cami + ".prestacions[" + j + "]";
                String codiEntitat = txt(p, "entitat_codi");
                if (codiEntitat == null) {
                    informe.error(fitxer, cp + ".entitat_codi", "una prestació necessita una entitat (no se'n crea cap de fictícia)");
                    continue;
                }
                Long entitatId = referencia("entitat", codiEntitat, fitxer, cp + ".entitat_codi");
                Long fontPrest = font(txt(p, "font_codi"), fitxer, cp + ".font_codi");
                if (entitatId == null) continue;
                Long prestacioId = Jdbc.retornaId(c, "INSERT INTO prestacio (servei_id, entitat_id, font_id) VALUES (?, ?, ?) "
                        + "ON CONFLICT (servei_id, entitat_id) DO UPDATE SET font_id = COALESCE(EXCLUDED.font_id, prestacio.font_id) "
                        + "RETURNING id", id, entitatId, fontPrest);
                JsonNode centres = p.path("centres");
                for (int k = 0; k < centres.size(); k++) {
                    JsonNode pc = centres.get(k);
                    String cpc = cp + ".centres[" + k + "]";
                    Long centreId = referencia("centre", txt(pc, "centre_codi"), fitxer, cpc + ".centre_codi");
                    if (txt(pc, "centre_codi") == null) informe.error(fitxer, cpc + ".centre_codi", "falta el codi del centre");
                    Long fontPc = font(txt(pc, "font_codi"), fitxer, cpc + ".font_codi");
                    if (centreId == null) continue;
                    Jdbc.executa(c, "INSERT INTO prestacio_centre (prestacio_id, centre_id, font_id) VALUES (?, ?, ?) "
                            + "ON CONFLICT (prestacio_id, centre_id) DO UPDATE SET font_id = COALESCE(EXCLUDED.font_id, prestacio_centre.font_id)",
                            prestacioId, centreId, fontPc);
                }
            }
        }
    }

    // ------------------------------------------------------------------ fills incrustats

    private record Franja(String dia, String inici, String fi, boolean diaSeguent, String cami) {}

    private void contactesJson(String colPare, long pareId, JsonNode llista, String fitxer, String cami) throws SQLException {
        for (int j = 0; j < llista.size(); j++) {
            JsonNode ct = llista.get(j);
            String cc = cami + ".contactes[" + j + "]";
            contacte(colPare, pareId, txt(ct, "tipus"), txt(ct, "valor"), font(txt(ct, "font_codi"), fitxer, cc + ".font_codi"), j, fitxer, cc);
        }
    }

    private void horarisJson(String colPare, long pareId, JsonNode llista, String fitxer, String cami) throws SQLException {
        for (int j = 0; j < llista.size(); j++) {
            JsonNode h = llista.get(j);
            String ch = cami + ".horaris[" + j + "]";
            List<Franja> franges = new ArrayList<>();
            JsonNode fr = h.path("franges");
            for (int k = 0; k < fr.size(); k++) {
                JsonNode x = fr.get(k);
                franges.add(new Franja(txt(x, "dia_setmana"), txt(x, "hora_inici"), txt(x, "hora_fi"),
                        x.path("final_dia_seguent").asBoolean(false), ch + ".franges[" + k + "]"));
            }
            horari(colPare, pareId, txt(h, "tipus"), txt(h, "descripcio"), txt(h, "zona_horaria"), txt(h, "vigent_des_de"),
                    txt(h, "vigent_fins_a"), font(txt(h, "font_codi"), fitxer, ch + ".font_codi"), franges, j, fitxer, ch);
        }
    }

    /** Insereix el contacte si el pare encara no en té un amb el mateix tipus i valor. */
    private void contacte(String colPare, long pareId, String tipus, String valor, Long fontId, int ordre,
                          String fitxer, String cami) throws SQLException {
        if (tipus == null || valor == null || valor.isBlank()) {
            informe.error(fitxer, cami, "un contacte necessita tipus i valor");
            return;
        }
        boolean existeix = Jdbc.compta(c, "SELECT count(*) FROM contacte WHERE " + colPare + " = ? AND tipus = ? AND valor = ?",
                pareId, tipus, valor.trim()) > 0;
        if (existeix) return;
        Jdbc.executa(c, "INSERT INTO contacte (" + colPare + ", tipus, valor, font_id, ordre) VALUES (?, ?, ?, ?, ?)",
                pareId, tipus, valor.trim(), fontId, ordre);
        informe.nou("contacte");
    }

    /** Insereix l'horari si el pare no en té un d'equivalent; reconcilia les seues franges. */
    private void horari(String colPare, long pareId, String tipus, String descripcio, String zona, String desDe, String finsA,
                        Long fontId, List<Franja> franges, int ordre, String fitxer, String cami) throws SQLException {
        Date d1 = data(desDe, fitxer, cami + ".vigent_des_de"), d2 = data(finsA, fitxer, cami + ".vigent_fins_a");
        Long id = Jdbc.un(c, "SELECT id FROM horari WHERE " + colPare + " = ? AND tipus IS NOT DISTINCT FROM ?::text "
                        + "AND descripcio IS NOT DISTINCT FROM ?::text AND vigent_des_de IS NOT DISTINCT FROM ?::date "
                        + "AND vigent_fins_a IS NOT DISTINCT FROM ?::date",
                rs -> rs.getLong(1), pareId, tipus, descripcio, d1, d2).orElse(null);
        if (id == null) {
            id = Jdbc.retornaId(c, "INSERT INTO horari (" + colPare + ", tipus, descripcio, zona_horaria, vigent_des_de, vigent_fins_a, font_id, ordre) "
                            + "VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
                    pareId, tipus, descripcio, zona == null ? "Europe/Madrid" : zona, d1, d2, fontId, ordre);
            informe.nou("horari");
        }
        for (Franja f : franges) {
            Integer dia = enter(f.dia);
            Time ini = hora(f.inici), fi = hora(f.fi);
            if (dia == null || dia < 1 || dia > 7 || ini == null || fi == null) {
                informe.error(fitxer, f.cami, "franja no vàlida (dia ISO 1-7 i hores HH:MM)");
                continue;
            }
            Jdbc.executa(c, "INSERT INTO franja (horari_id, dia_setmana, hora_inici, hora_fi, final_dia_seguent) VALUES (?, ?, ?, ?, ?) "
                    + "ON CONFLICT DO NOTHING", id, dia.shortValue(), ini, fi, f.diaSeguent);
        }
    }

    // ------------------------------------------------------------------ recomptes i comprovacions

    private void compara(JsonNode manifest) throws Exception {
        Map<String, String> consultes = new LinkedHashMap<>();
        consultes.put("entitats", "SELECT count(*) FROM entitat");
        consultes.put("centres", "SELECT count(*) FROM centre");
        consultes.put("serveis", "SELECT count(*) FROM servei");
        consultes.put("prestacions", "SELECT count(*) FROM prestacio");
        consultes.put("prestacions_centres", "SELECT count(*) FROM prestacio_centre");
        consultes.put("contactes", "SELECT count(*) FROM contacte");
        consultes.put("horaris", "SELECT count(*) FROM horari");
        consultes.put("municipis", "SELECT count(*) FROM municipi");
        JsonNode rec = manifest.path("recomptes");
        for (var e : consultes.entrySet()) {
            if (!rec.has(e.getKey())) continue;
            informe.recomptes.put(e.getKey(), new long[]{rec.get(e.getKey()).asLong(), Jdbc.compta(c, e.getValue())});
        }
        if (!informe.recomptesCorrectes()) {
            informe.avisos.add("Els recomptes no coincideixen amb manifest.json (normal si la BD té fitxes afegides fora del paquet).");
        }

        Path fitxerComp = dir.resolve("comprovacions.json");
        if (Files.exists(fitxerComp)) {
            JsonNode comp = json.readTree(fitxerComp.toFile());
            var noms = comp.fieldNames();
            while (noms.hasNext()) {
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

    // ------------------------------------------------------------------ resolució de referències

    private Long resol(String tipus, String codi) throws SQLException {
        if (codi == null) return null;
        return Jdbc.un(c, "SELECT registre_id FROM identitat_importacio WHERE font_importacio_id = ? AND tipus_registre = ? AND codi_origen = ?",
                rs -> rs.getLong(1), fontImportacioId, tipus, codi).orElse(null);
    }

    private void registra(String tipus, String codi, long id) throws SQLException {
        Jdbc.executa(c, "INSERT INTO identitat_importacio (font_importacio_id, tipus_registre, codi_origen, registre_id) VALUES (?, ?, ?, ?)",
                fontImportacioId, tipus, codi, id);
    }

    /** Resol una referència a un registre ja importat. Null si el codi és nul; error si no existeix. */
    private Long referencia(String tipus, String codi, String fitxer, String cami) throws SQLException {
        if (codi == null) return null;
        Long id = resol(tipus, codi);
        if (id == null) informe.error(fitxer, cami, "referència a " + tipus + " inexistent «" + codi + "»");
        return id;
    }

    private Long font(String codi, String fitxer, String cami) {
        if (codi == null) return null;
        Long id = fonts.get(codi);
        if (id == null) informe.error(fitxer, cami, "font de procedència desconeguda «" + codi + "»");
        return id;
    }

    private Long cataleg(Map<String, Long> cat, String codi, String fitxer, String cami) {
        if (codi == null) return null;
        Long id = cat.get(codi);
        if (id == null) informe.error(fitxer, cami, "codi de catàleg desconegut «" + codi + "»");
        return id;
    }

    // ------------------------------------------------------------------ utilitats de lectura

    private static String adrecaNeta(String a) {
        if (a == null) return null;
        String t = a.trim();
        while (t.endsWith(",")) t = t.substring(0, t.length() - 1).trim();
        return t.isEmpty() ? null : t;
    }

    private static String txt(JsonNode n, String camp) {
        JsonNode v = n.get(camp);
        if (v == null || v.isNull()) return null;
        String s = v.asText();
        return s;
    }

    private static BigDecimal num(JsonNode n, String camp) {
        JsonNode v = n.get(camp);
        return (v == null || v.isNull()) ? null : v.decimalValue();
    }

    private Date data(String s, String fitxer, String cami) {
        if (s == null || s.isBlank()) return null;
        try { return Date.valueOf(s); } catch (IllegalArgumentException e) {
            informe.error(fitxer, cami, "data no vàlida «" + s + "» (AAAA-MM-DD)");
            return null;
        }
    }

    private static Integer enter(String s) {
        try { return s == null ? null : Integer.valueOf(s.trim()); } catch (NumberFormatException e) { return null; }
    }

    private static Time hora(String s) {
        if (s == null || !s.trim().matches("\\d{2}:\\d{2}")) return null;
        try { return Time.valueOf(s.trim() + ":00"); } catch (IllegalArgumentException e) { return null; }
    }

    private static List<Element> fills(Element pare, String nom) {
        List<Element> res = new ArrayList<>();
        NodeList nl = pare.getChildNodes();
        for (int i = 0; i < nl.getLength(); i++) {
            Node x = nl.item(i);
            if (x instanceof Element el && Objects.equals(el.getTagName(), nom)) res.add(el);
        }
        return res;
    }

    private static Element fill(Element pare, String nom) {
        List<Element> l = fills(pare, nom);
        return l.isEmpty() ? null : l.get(0);
    }

    /** Text d'un element opcional; absent = nul. */
    private static String text(Element pare, String nom) {
        Element e = fill(pare, nom);
        if (e == null) return null;
        return e.getTextContent();
    }
}
