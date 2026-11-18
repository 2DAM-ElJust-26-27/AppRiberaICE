package ribera.importacio;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import ribera.bd.Jdbc;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.Date;
import java.sql.SQLException;
import java.sql.Time;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Peces comunes de la importació: identitat dels registres, referències,
 * inserció/actualització genèrica, contactes, horaris i lectura de valors.
 */
abstract class BaseImportacio {

    protected final Connection c;
    protected final InformeImportacio informe = new InformeImportacio();
    protected final ObjectMapper json = new ObjectMapper();

    protected long fontImportacioId;
    protected final Map<String, Long> fonts = new HashMap<>();
    protected final Map<String, Long> formesJuridiques = new HashMap<>();
    protected final Map<String, Long> tipusCentre = new HashMap<>();
    protected final Map<String, Long> collectius = new HashMap<>();

    protected BaseImportacio(Connection c) {
        this.c = c;
    }

    // ------------------------------------------------------------------ identitat i referències

    /** ID generat d'un registre a partir del seu codi d'origen (null si encara no existeix). */
    protected Long resol(String tipus, String codi) throws SQLException {
        if (codi == null) return null;
        return Jdbc.un(c, "SELECT registre_id FROM identitat_importacio WHERE font_importacio_id = ? AND tipus_registre = ? AND codi_origen = ?",
                rs -> rs.getLong(1), fontImportacioId, tipus, codi).orElse(null);
    }

    protected void registra(String tipus, String codi, long id) throws SQLException {
        Jdbc.executa(c, "INSERT INTO identitat_importacio (font_importacio_id, tipus_registre, codi_origen, registre_id) VALUES (?, ?, ?, ?)",
                fontImportacioId, tipus, codi, id);
    }

    /** Referència a un registre ja importat. Null si el codi és nul; error amb el camí si no existeix. */
    protected Long referencia(String tipus, String codi, String fitxer, String cami) throws SQLException {
        if (codi == null) return null;
        Long id = resol(tipus, codi);
        if (id == null) informe.error(fitxer, cami, "referència a " + tipus + " inexistent «" + codi + "»");
        return id;
    }

    protected Long font(String codi, String fitxer, String cami) {
        return deMapa(fonts, codi, fitxer, cami, "font de procedència desconeguda");
    }

    protected Long cataleg(Map<String, Long> cat, String codi, String fitxer, String cami) {
        return deMapa(cat, codi, fitxer, cami, "codi de catàleg desconegut");
    }

    private Long deMapa(Map<String, Long> mapa, String codi, String fitxer, String cami, String error) {
        if (codi == null) return null;
        Long id = mapa.get(codi);
        if (id == null) informe.error(fitxer, cami, error + " «" + codi + "»");
        return id;
    }

    /** Font de procedència del camp {@code camp} d'un node JSON. */
    protected Long font(JsonNode n, String camp, String fitxer, String cami) {
        return font(txt(n, camp), fitxer, cami + "." + camp);
    }

    // ------------------------------------------------------------------ inserció / actualització

    /** Mapa ordenat de columnes a partir de parells nom, valor (accepta valors nuls). */
    protected static Map<String, Object> camps(Object... parells) {
        Map<String, Object> m = new LinkedHashMap<>();
        for (int i = 0; i < parells.length; i += 2) m.put((String) parells[i], parells[i + 1]);
        return m;
    }

    /**
     * Insereix el registre o, si ja existeix pel seu codi d'origen, l'actualitza.
     * En actualitzar, un valor nul de la font no esborra el valor que ja hi ha (COALESCE).
     */
    protected long desa(String taula, String tipus, String codi, Map<String, Object> camps) throws SQLException {
        List<String> cols = new ArrayList<>(camps.keySet());
        Object[] valors = camps.values().toArray();
        Long id = resol(tipus, codi);
        if (id == null) {
            id = Jdbc.retornaId(c, "INSERT INTO " + taula + " (" + String.join(", ", cols) + ") VALUES ("
                    + "?, ".repeat(cols.size() - 1) + "?) RETURNING id", valors);
            registra(tipus, codi, id);
            informe.nou(tipus);
            return id;
        }
        String set = cols.stream().map(k -> k + " = COALESCE(?, " + k + ")").collect(Collectors.joining(", "));
        Object[] ambId = Arrays.copyOf(valors, valors.length + 1);
        ambId[valors.length] = id;
        Jdbc.executa(c, "UPDATE " + taula + " SET " + set + " WHERE id = ?", ambId);
        return id;
    }

    // ------------------------------------------------------------------ contactes i horaris

    /** Contactes d'un pare: s'insereixen només si no n'hi ha ja un amb el mateix tipus i valor. */
    protected void contactes(String colPare, long pareId, JsonNode llista, String fitxer, String cami) throws SQLException {
        for (int j = 0; j < llista.size(); j++) {
            JsonNode ct = llista.get(j);
            String cc = cami + ".contactes[" + j + "]";
            String tipus = txt(ct, "tipus"), valor = txt(ct, "valor");
            Long fontId = font(ct, "font_codi", fitxer, cc);
            if (tipus == null || valor == null || valor.isBlank()) {
                informe.error(fitxer, cc, "un contacte necessita tipus i valor");
                continue;
            }
            valor = valor.trim();
            if (Jdbc.compta(c, "SELECT count(*) FROM contacte WHERE " + colPare + " = ? AND tipus = ? AND valor = ?", pareId, tipus, valor) > 0) continue;
            Jdbc.executa(c, "INSERT INTO contacte (" + colPare + ", tipus, valor, font_id, ordre) VALUES (?, ?, ?, ?, ?)",
                    pareId, tipus, valor, fontId, j);
            informe.nou("contacte");
        }
    }

    /** Horaris d'un pare: s'insereixen si no n'hi ha un d'equivalent; les franges no es dupliquen. */
    protected void horaris(String colPare, long pareId, JsonNode llista, String fitxer, String cami) throws SQLException {
        for (int j = 0; j < llista.size(); j++) {
            JsonNode h = llista.get(j);
            String ch = cami + ".horaris[" + j + "]";
            String tipus = txt(h, "tipus"), descripcio = txt(h, "descripcio"), zona = txt(h, "zona_horaria");
            Date desDe = data(h, "vigent_des_de", fitxer, ch), finsA = data(h, "vigent_fins_a", fitxer, ch);
            Long fontId = font(h, "font_codi", fitxer, ch);

            Long id = Jdbc.un(c, "SELECT id FROM horari WHERE " + colPare + " = ? AND tipus IS NOT DISTINCT FROM ?::text "
                            + "AND descripcio IS NOT DISTINCT FROM ?::text AND vigent_des_de IS NOT DISTINCT FROM ?::date "
                            + "AND vigent_fins_a IS NOT DISTINCT FROM ?::date",
                    rs -> rs.getLong(1), pareId, tipus, descripcio, desDe, finsA).orElse(null);
            if (id == null) {
                id = Jdbc.retornaId(c, "INSERT INTO horari (" + colPare + ", tipus, descripcio, zona_horaria, vigent_des_de, vigent_fins_a, font_id, ordre) "
                        + "VALUES (?, ?, ?, ?, ?, ?, ?, ?) RETURNING id",
                        pareId, tipus, descripcio, zona == null ? "Europe/Madrid" : zona, desDe, finsA, fontId, j);
                informe.nou("horari");
            }
            JsonNode franges = h.path("franges");
            for (int k = 0; k < franges.size(); k++) {
                JsonNode f = franges.get(k);
                Integer dia = enter(txt(f, "dia_setmana"));
                Time inici = hora(txt(f, "hora_inici")), fi = hora(txt(f, "hora_fi"));
                if (dia == null || dia < 1 || dia > 7 || inici == null || fi == null) {
                    informe.error(fitxer, ch + ".franges[" + k + "]", "franja no vàlida (dia ISO 1-7 i hores HH:MM)");
                    continue;
                }
                Jdbc.executa(c, "INSERT INTO franja (horari_id, dia_setmana, hora_inici, hora_fi, final_dia_seguent) VALUES (?, ?, ?, ?, ?) "
                        + "ON CONFLICT DO NOTHING", id, dia.shortValue(), inici, fi, f.path("final_dia_seguent").asBoolean(false));
            }
        }
    }

    // ------------------------------------------------------------------ lectura de valors

    protected static String txt(JsonNode n, String camp) {
        JsonNode v = n.get(camp);
        return (v == null || v.isNull()) ? null : v.asText();
    }

    protected static BigDecimal num(JsonNode n, String camp) {
        JsonNode v = n.get(camp);
        return (v == null || v.isNull()) ? null : v.decimalValue();
    }

    /** Adreça sense espais ni comes sobrants al final. */
    protected static String adrecaNeta(String a) {
        if (a == null) return null;
        String t = a.trim().replaceAll("[,\\s]+$", "");
        return t.isEmpty() ? null : t;
    }

    private Date data(JsonNode n, String camp, String fitxer, String cami) {
        String s = txt(n, camp);
        if (s == null || s.isBlank()) return null;
        try {
            return Date.valueOf(s);
        } catch (IllegalArgumentException e) {
            informe.error(fitxer, cami + "." + camp, "data no vàlida «" + s + "» (AAAA-MM-DD)");
            return null;
        }
    }

    private static Integer enter(String s) {
        try {
            return s == null ? null : Integer.valueOf(s.trim());
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private static Time hora(String s) {
        return (s != null && s.trim().matches("([01]\\d|2[0-3]):[0-5]\\d")) ? Time.valueOf(s.trim() + ":00") : null;
    }

    // ------------------------------------------------------------------ XML → JSON

    /** Elements XML que contenen una llista de fills (es converteixen en arrays). */
    private static final Set<String> LLISTES = Set.of("contactes", "horaris", "franges");

    /**
     * Converteix un element XML en un objecte JSON equivalent, perquè les entitats
     * (XML) es processen amb el mateix codi que centres i serveis (JSON).
     */
    protected ObjectNode xmlAJson(Element e) {
        ObjectNode o = json.createObjectNode();
        for (int i = 0; i < e.getAttributes().getLength(); i++) {
            Node a = e.getAttributes().item(i);
            o.put(a.getNodeName(), a.getNodeValue());
        }
        for (Element fill : fills(e)) {
            String nom = fill.getTagName();
            if (LLISTES.contains(nom)) {
                ArrayNode arr = o.putArray(nom);
                for (Element x : fills(fill)) arr.add(xmlAJson(x));
            } else if (!fills(fill).isEmpty()) {
                o.set(nom, xmlAJson(fill));
            } else {
                o.put(nom, fill.getTextContent());
            }
        }
        return o;
    }

    protected static List<Element> fills(Element pare) {
        List<Element> res = new ArrayList<>();
        for (Node x = pare.getFirstChild(); x != null; x = x.getNextSibling()) {
            if (x instanceof Element el) res.add(el);
        }
        return res;
    }
}
