package ribera;

import java.sql.SQLException;
import java.util.List;
import java.util.Map;

import static ribera.BaseDades.llista;
import static ribera.BaseDades.textos;
import static ribera.BaseDades.una;

/**
 * Totes les consultes de l'API. Cada mètode torna mapes i llistes,
 * que Javalin converteix directament a JSON.
 */
public class Consultes {

    // ------------------------------------------------------------------ centres

    private static final String SELECT_CENTRE = """
            SELECT c.id, c.nom, c.adreca, m.nom AS municipi, tc.nom AS tipus,
                   c.latitud::float8 AS latitud, c.longitud::float8 AS longitud
              FROM centre c
              LEFT JOIN municipi m ON m.id = c.municipi_id
              LEFT JOIN tipus_centre tc ON tc.id = c.tipus_centre_id
            """;

    /** Tots els centres o, si es passa un servei, només els centres on es fa. */
    public static List<Map<String, Object>> centres(Long serveiId) throws SQLException {
        if (serveiId == null) {
            return llista(SELECT_CENTRE + " ORDER BY c.nom");
        }
        return llista(SELECT_CENTRE + """
                 WHERE c.id IN (SELECT pc.centre_id
                                  FROM prestacio_centre pc
                                  JOIN prestacio p ON p.id = pc.prestacio_id
                                 WHERE p.servei_id = ?)
                 ORDER BY c.nom""", serveiId);
    }

    public static Map<String, Object> centre(long id) throws SQLException {
        Map<String, Object> centre = una("""
                SELECT c.id, c.nom, c.adreca, c.codi_postal, m.nom AS municipi, tc.nom AS tipus,
                       c.latitud::float8 AS latitud, c.longitud::float8 AS longitud,
                       t.nom AS titular, g.nom AS gestor
                  FROM centre c
                  LEFT JOIN municipi m ON m.id = c.municipi_id
                  LEFT JOIN tipus_centre tc ON tc.id = c.tipus_centre_id
                  LEFT JOIN entitat t ON t.id = c.titular_id
                  LEFT JOIN entitat g ON g.id = c.gestor_id
                 WHERE c.id = ?""", id);
        if (centre == null) return null;

        centre.put("contactes", contactes("centre_id", id));
        centre.put("horaris", horaris("centre_id", id));
        centre.put("serveis", llista("""
                SELECT DISTINCT s.id, s.nom
                  FROM servei s
                  JOIN prestacio p ON p.servei_id = s.id
                  JOIN prestacio_centre pc ON pc.prestacio_id = p.id
                 WHERE pc.centre_id = ?
                 ORDER BY s.nom""", id));
        return centre;
    }

    // ------------------------------------------------------------------ serveis

    /**
     * Tots els serveis o, si es passa un municipi, els que es fan en un centre
     * d'aquest municipi (servei → prestació → centre → municipi).
     */
    public static List<Map<String, Object>> serveis(Long municipiId) throws SQLException {
        List<Map<String, Object>> serveis;
        if (municipiId == null) {
            serveis = llista("SELECT id, nom, descripcio FROM servei ORDER BY nom");
        } else {
            serveis = llista("""
                    SELECT id, nom, descripcio FROM servei
                     WHERE id IN (SELECT p.servei_id
                                    FROM prestacio p
                                    JOIN prestacio_centre pc ON pc.prestacio_id = p.id
                                    JOIN centre c ON c.id = pc.centre_id
                                   WHERE c.municipi_id = ?)
                     ORDER BY nom""", municipiId);
        }

        // Per a cada servei afegim les llistes que necessita l'assistent de l'app
        for (Map<String, Object> servei : serveis) {
            Object id = servei.get("id");
            servei.put("collectius", textos("""
                    SELECT co.nom FROM servei_collectiu sc
                      JOIN collectiu co ON co.id = sc.collectiu_id
                     WHERE sc.servei_id = ? ORDER BY co.nom""", id));
            servei.put("municipis", textos("""
                    SELECT DISTINCT m.nom FROM prestacio p
                      JOIN prestacio_centre pc ON pc.prestacio_id = p.id
                      JOIN centre c ON c.id = pc.centre_id
                      JOIN municipi m ON m.id = c.municipi_id
                     WHERE p.servei_id = ? ORDER BY m.nom""", id));
            servei.put("tipus", textos("""
                    SELECT DISTINCT tc.nom FROM prestacio p
                      JOIN prestacio_centre pc ON pc.prestacio_id = p.id
                      JOIN centre c ON c.id = pc.centre_id
                      JOIN tipus_centre tc ON tc.id = c.tipus_centre_id
                     WHERE p.servei_id = ? ORDER BY tc.nom""", id));
        }
        return serveis;
    }

    public static Map<String, Object> servei(long id) throws SQLException {
        Map<String, Object> servei = una("""
                SELECT id, nom, descripcio, via_acces, cobertura, observacions
                  FROM servei WHERE id = ?""", id);
        if (servei == null) return null;

        servei.put("collectius", textos("""
                SELECT co.nom FROM servei_collectiu sc
                  JOIN collectiu co ON co.id = sc.collectiu_id
                 WHERE sc.servei_id = ? ORDER BY co.nom""", id));
        servei.put("contactes", contactes("servei_id", id));
        servei.put("horaris", horaris("servei_id", id));
        servei.put("entitats", llista("""
                SELECT e.id, e.nom FROM prestacio p
                  JOIN entitat e ON e.id = p.entitat_id
                 WHERE p.servei_id = ? ORDER BY e.nom""", id));
        servei.put("centres", llista("""
                SELECT DISTINCT c.id, c.nom, m.nom AS municipi
                  FROM prestacio p
                  JOIN prestacio_centre pc ON pc.prestacio_id = p.id
                  JOIN centre c ON c.id = pc.centre_id
                  LEFT JOIN municipi m ON m.id = c.municipi_id
                 WHERE p.servei_id = ? ORDER BY c.nom""", id));
        return servei;
    }

    // ------------------------------------------------------------------ entitats

    public static List<Map<String, Object>> entitats() throws SQLException {
        return llista("""
                SELECT e.id, e.nom, fj.nom AS forma_juridica, m.nom AS municipi
                  FROM entitat e
                  LEFT JOIN forma_juridica fj ON fj.id = e.forma_juridica_id
                  LEFT JOIN municipi m ON m.id = e.municipi_id
                 ORDER BY e.nom""");
    }

    public static Map<String, Object> entitat(long id) throws SQLException {
        Map<String, Object> entitat = una("""
                SELECT e.id, e.nom, e.sector, e.adreca, e.codi_postal,
                       fj.nom AS forma_juridica, m.nom AS municipi
                  FROM entitat e
                  LEFT JOIN forma_juridica fj ON fj.id = e.forma_juridica_id
                  LEFT JOIN municipi m ON m.id = e.municipi_id
                 WHERE e.id = ?""", id);
        if (entitat == null) return null;

        entitat.put("contactes", contactes("entitat_id", id));
        entitat.put("horaris", horaris("entitat_id", id));
        entitat.put("serveis", llista("""
                SELECT s.id, s.nom FROM prestacio p
                  JOIN servei s ON s.id = p.servei_id
                 WHERE p.entitat_id = ? ORDER BY s.nom""", id));
        entitat.put("centres", llista("""
                SELECT id, nom FROM centre
                 WHERE titular_id = ? OR gestor_id = ? ORDER BY nom""", id, id));
        return entitat;
    }

    // ------------------------------------------------------------------ contactes i horaris

    /** columna = "centre_id", "servei_id" o "entitat_id" (la posem nosaltres, no l'usuari). */
    private static List<Map<String, Object>> contactes(String columna, long id) throws SQLException {
        return llista("SELECT tipus, valor FROM contacte WHERE " + columna + " = ? ORDER BY ordre", id);
    }

    private static List<String> horaris(String columna, long id) throws SQLException {
        return textos("SELECT coalesce(descripcio, tipus) FROM horari WHERE " + columna + " = ? ORDER BY ordre", id);
    }
}
