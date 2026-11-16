package ribera.importacio;

import ribera.bd.Jdbc;

import java.sql.Connection;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Consultes de comprovacions.json. Comparen conjunts de codis d'origen
 * (no ID ni ordre). «Prestat a X» recorre prestació → centre → municipi:
 * no es confon la ubicació de l'entitat amb la cobertura.
 */
public final class Comprovacions {

    private Comprovacions() {}

    private static final String CODI_SERVEI =
            "(SELECT ii.codi_origen FROM identitat_importacio ii WHERE ii.font_importacio_id = ? "
            + "AND ii.tipus_registre = 'servei' AND ii.registre_id = s.id)";
    private static final String CODI_CENTRE =
            "(SELECT ii.codi_origen FROM identitat_importacio ii WHERE ii.font_importacio_id = ? "
            + "AND ii.tipus_registre = 'centre' AND ii.registre_id = c.id)";

    private static String serveisPrestatsA(String municipi, String collectiu) {
        return "SELECT DISTINCT " + CODI_SERVEI + " AS codi FROM servei s "
                + "JOIN prestacio p ON p.servei_id = s.id "
                + "JOIN prestacio_centre pc ON pc.prestacio_id = p.id "
                + "JOIN centre c ON c.id = pc.centre_id "
                + "JOIN municipi m ON m.id = c.municipi_id "
                + "WHERE m.nom = '" + municipi + "'"
                + (collectiu == null ? "" : " AND EXISTS (SELECT 1 FROM servei_collectiu sc JOIN collectiu co ON co.id = sc.collectiu_id "
                + "WHERE sc.servei_id = s.id AND co.codi = '" + collectiu + "')")
                + " ORDER BY 1";
    }

    /** Nom de la comprovació → SQL que retorna codis d'origen (un paràmetre: font_importacio_id). */
    public static final Map<String, String> CONSULTES = new LinkedHashMap<>();

    static {
        CONSULTES.put("centres_amb_serveis_majors",
                "SELECT DISTINCT " + CODI_CENTRE + " AS codi FROM centre c "
                + "JOIN prestacio_centre pc ON pc.centre_id = c.id "
                + "JOIN prestacio p ON p.id = pc.prestacio_id "
                + "JOIN servei_collectiu sc ON sc.servei_id = p.servei_id "
                + "JOIN collectiu co ON co.id = sc.collectiu_id AND co.codi = 'COL_MAJORS' ORDER BY 1");
        CONSULTES.put("serveis_prestats_cullera", serveisPrestatsA("Cullera", null));
        CONSULTES.put("serveis_smg_cullera", serveisPrestatsA("Cullera", "COL_SMG"));
        CONSULTES.put("serveis_smg_sueca", serveisPrestatsA("Sueca", "COL_SMG"));
        CONSULTES.put("centres_residencials_sueca",
                "SELECT " + CODI_CENTRE + " AS codi FROM centre c "
                + "JOIN tipus_centre tc ON tc.id = c.tipus_centre_id AND tc.codi = 'TC04' "
                + "JOIN municipi m ON m.id = c.municipi_id AND m.nom = 'Sueca' ORDER BY 1");
    }

    public static List<String> executa(Connection c, String nom, long fontImportacioId) throws SQLException {
        String sql = CONSULTES.get(nom);
        if (sql == null) throw new IllegalArgumentException("Comprovació desconeguda: " + nom);
        return Jdbc.llista(c, sql, rs -> rs.getString("codi"), fontImportacioId);
    }
}
