package ribera;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.w3c.dom.Element;
import org.w3c.dom.Node;

import javax.xml.parsers.DocumentBuilderFactory;
import java.math.BigDecimal;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static ribera.BaseDades.executa;
import static ribera.BaseDades.insereix;

/**
 * Carrega els fitxers del Sprint 1 a la base de dades.
 * Tot va en una transacció: si falla alguna cosa, no es guarda res.
 *
 * Els fitxers porten codis (MUN47, ENT03, CEN05…). La base de dades dona
 * a cada fila un ID nou, i guardem en mapes quin ID té cada codi.
 */
public class Importador {

    private final Connection c;
    private final Path dades;
    private final Path complements;
    private final ObjectMapper json = new ObjectMapper();

    // codi del fitxer → id a la base de dades
    private final Map<String, Long> catalegs = new HashMap<>();
    private final Map<String, Long> comarques = new HashMap<>();
    private final Map<String, Long> municipis = new HashMap<>();
    private final Map<String, Long> entitats = new HashMap<>();
    private final Map<String, Long> centres = new HashMap<>();
    private long paquetId;

    public Importador(Connection c, Path dades, Path complements) {
        this.c = c;
        this.dades = dades;
        this.complements = complements;
    }

    public void importa() throws Exception {
        c.setAutoCommit(false);
        try {
            paquetId = insereix(c, "INSERT INTO font_importacio (nom, versio, data_darrera_carrega) "
                    + "VALUES ('ribera-sprint1', 2, now()) RETURNING id");
            // L'ordre importa: un centre necessita que ja existisquen el seu municipi i la seua entitat
            importaCatalegs();
            importaTerritori();
            importaEntitats();
            importaCentres();
            importaServeis();
            importaPunts();
            c.commit();
        } catch (Exception e) {
            c.rollback();
            throw e;
        }
    }

    // ------------------------------------------------------------------ fitxers

    private void importaCatalegs() throws Exception {
        for (Map<String, String> fila : LectorCsv.llegeix(dades.resolve("catalegs.csv"))) {
            String taula = fila.get("tipus");
            if (!List.of("forma_juridica", "tipus_centre", "collectiu").contains(taula)) {
                throw new IllegalArgumentException("Catàleg desconegut: " + taula);
            }
            long id = insereix(c, "INSERT INTO " + taula + " (codi, nom) VALUES (?, ?) RETURNING id",
                    fila.get("codi"), fila.get("nom"));
            catalegs.put(fila.get("codi"), id);
        }
    }

    private void importaTerritori() throws Exception {
        for (Map<String, String> fila : LectorCsv.llegeix(dades.resolve("territori.csv"))) {
            String codiComarca = fila.get("comarca_codi");
            if (!comarques.containsKey(codiComarca)) {
                long id = insereix(c, "INSERT INTO comarca (nom) VALUES (?) RETURNING id", fila.get("comarca_nom"));
                comarques.put(codiComarca, id);
                registra("comarca", codiComarca, id);
            }
            long id = insereix(c, "INSERT INTO municipi (nom, comarca_id) VALUES (?, ?) RETURNING id",
                    fila.get("nom"), comarques.get(codiComarca));
            municipis.put(fila.get("codi"), id);
            registra("municipi", fila.get("codi"), id);
        }
    }

    /** entitats.xml: cada <entitat> té fills com <nom>, <contactes> i <horaris>. */
    private void importaEntitats() throws Exception {
        Element arrel = DocumentBuilderFactory.newInstance().newDocumentBuilder()
                .parse(dades.resolve("entitats.xml").toFile()).getDocumentElement();

        for (Element e : fills(arrel)) {
            String codi = e.getAttribute("codi");
            long id = insereix(c, """
                    INSERT INTO entitat (nom, forma_juridica_id, sector, adreca, municipi_id, codi_postal)
                    VALUES (?, ?, ?, ?, ?, ?) RETURNING id""",
                    text(e, "nom"), id(catalegs, text(e, "forma_juridica_codi")), text(e, "sector"),
                    text(e, "adreca"), id(municipis, text(e, "municipi_codi")), text(e, "codi_postal"));
            entitats.put(codi, id);
            registra("entitat", codi, id);

            int ordre = 0;
            for (Element ct : fills(fill(e, "contactes"))) {
                contacte("entitat_id", id, text(ct, "tipus"), text(ct, "valor"), ordre++);
            }
            ordre = 0;
            for (Element h : fills(fill(e, "horaris"))) {
                horari("entitat_id", id, text(h, "tipus"), text(h, "descripcio"), ordre++);
            }
        }
    }

    private void importaCentres() throws Exception {
        for (JsonNode n : json.readTree(dades.resolve("centres.json").toFile())) {
            String codi = text(n, "codi");
            long id = insereix(c, """
                    INSERT INTO centre (nom, tipus_centre_id, titular_id, gestor_id, adreca, municipi_id,
                                        codi_postal, latitud, longitud, precisio_punt)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?) RETURNING id""",
                    text(n, "nom"), id(catalegs, text(n, "tipus_centre_codi")),
                    id(entitats, text(n, "titular_codi")), id(entitats, text(n, "gestor_codi")),
                    text(n, "adreca"), id(municipis, text(n, "municipi_codi")), text(n, "codi_postal"),
                    numero(n, "latitud"), numero(n, "longitud"), text(n, "precisio_punt"));
            centres.put(codi, id);
            registra("centre", codi, id);
            contactesIHoraris(n, "centre_id", id);
        }
    }

    private void importaServeis() throws Exception {
        for (JsonNode n : json.readTree(dades.resolve("serveis.json").toFile())) {
            long id = insereix(c, """
                    INSERT INTO servei (nom, descripcio, modalitat_codi, via_acces, cobertura, observacions)
                    VALUES (?, ?, ?, ?, ?, ?) RETURNING id""",
                    text(n, "nom"), text(n, "descripcio"), text(n, "modalitat_codi"),
                    text(n, "via_acces"), text(n, "cobertura"), text(n, "observacions"));
            registra("servei", text(n, "codi"), id);

            for (JsonNode col : n.get("collectius")) {
                executa(c, "INSERT INTO servei_collectiu (servei_id, collectiu_id) VALUES (?, ?)", id, id(catalegs, col.asText()));
            }
            contactesIHoraris(n, "servei_id", id);

            // Prestació: quina entitat fa el servei i en quins centres
            for (JsonNode p : n.get("prestacions")) {
                long prestacioId = insereix(c, "INSERT INTO prestacio (servei_id, entitat_id) VALUES (?, ?) RETURNING id",
                        id, id(entitats, text(p, "entitat_codi")));
                for (JsonNode pc : p.get("centres")) {
                    executa(c, "INSERT INTO prestacio_centre (prestacio_id, centre_id) VALUES (?, ?)",
                            prestacioId, id(centres, text(pc, "centre_codi")));
                }
            }
        }
    }

    /** Coordenades que vam buscar a CartoCiudad. Només s'omplin centres que no en tenien. */
    private void importaPunts() throws Exception {
        for (Map<String, String> fila : LectorCsv.llegeix(complements.resolve("punts-centres.csv"))) {
            executa(c, "UPDATE centre SET latitud = ?, longitud = ?, precisio_punt = ? WHERE id = ? AND latitud IS NULL",
                    new BigDecimal(fila.get("latitud")), new BigDecimal(fila.get("longitud")),
                    fila.get("precisio_punt"), id(centres, fila.get("codi")));
        }
    }

    // ------------------------------------------------------------------ contactes i horaris

    private void contactesIHoraris(JsonNode n, String columna, long id) throws SQLException {
        int ordre = 0;
        for (JsonNode ct : n.get("contactes")) {
            contacte(columna, id, text(ct, "tipus"), text(ct, "valor"), ordre++);
        }
        ordre = 0;
        for (JsonNode h : n.get("horaris")) {
            horari(columna, id, text(h, "tipus"), text(h, "descripcio"), ordre++);
        }
    }

    private void contacte(String columna, long id, String tipus, String valor, int ordre) throws SQLException {
        executa(c, "INSERT INTO contacte (" + columna + ", tipus, valor, ordre) VALUES (?, ?, ?, ?)",
                id, tipus, valor, ordre);
    }

    private void horari(String columna, long id, String tipus, String descripcio, int ordre) throws SQLException {
        executa(c, "INSERT INTO horari (" + columna + ", tipus, descripcio, ordre) VALUES (?, ?, ?, ?)",
                id, tipus, descripcio, ordre);
    }

    // ------------------------------------------------------------------ ajudes

    /** Busca l'id d'un codi. Si el codi no existeix, para la importació. */
    private Long id(Map<String, Long> mapa, String codi) {
        if (codi == null) return null;
        Long id = mapa.get(codi);
        if (id == null) throw new IllegalArgumentException("Codi desconegut: " + codi);
        return id;
    }

    /** Guarda quin codi tenia cada fila, per poder-lo consultar després. */
    private void registra(String tipus, String codi, long id) throws SQLException {
        executa(c, "INSERT INTO identitat_importacio (font_importacio_id, tipus_registre, codi_origen, registre_id) "
                + "VALUES (?, ?, ?, ?)", paquetId, tipus, codi, id);
    }

    private static String text(JsonNode n, String camp) {
        JsonNode v = n.get(camp);
        return (v == null || v.isNull()) ? null : v.asText().trim();
    }

    private static BigDecimal numero(JsonNode n, String camp) {
        JsonNode v = n.get(camp);
        return (v == null || v.isNull()) ? null : v.decimalValue();
    }

    /** Text del fill <nom> d'un element XML (null si no hi és). */
    private static String text(Element e, String nom) {
        Element f = fill(e, nom);
        return f == null ? null : f.getTextContent().trim();
    }

    private static Element fill(Element e, String nom) {
        for (Element f : fills(e)) {
            if (f.getTagName().equals(nom)) return f;
        }
        return null;
    }

    private static List<Element> fills(Element e) {
        List<Element> res = new ArrayList<>();
        if (e == null) return res;
        for (Node n = e.getFirstChild(); n != null; n = n.getNextSibling()) {
            if (n instanceof Element el) res.add(el);
        }
        return res;
    }
}
