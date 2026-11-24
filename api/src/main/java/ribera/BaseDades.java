package ribera;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Connexió amb PostgreSQL i tres mètodes per fer consultes.
 * Les dades de connexió es lligen de variables d'entorn (Docker les posa).
 */
public class BaseDades {

    public static String url = entorn("BD_URL", "jdbc:postgresql://localhost:5432/ribera");
    public static String usuari = entorn("BD_USUARI", "ribera");
    public static String contrasenya = entorn("BD_CONTRASENYA", "ribera");

    public static Connection connecta() throws SQLException {
        return DriverManager.getConnection(url, usuari, contrasenya);
    }

    /** Executa un SELECT i torna cada fila com un mapa columna → valor. */
    public static List<Map<String, Object>> llista(String sql, Object... parametres) throws SQLException {
        try (Connection c = connecta(); PreparedStatement ps = c.prepareStatement(sql)) {
            for (int i = 0; i < parametres.length; i++) {
                ps.setObject(i + 1, parametres[i]);
            }
            ResultSet rs = ps.executeQuery();
            ResultSetMetaData columnes = rs.getMetaData();
            List<Map<String, Object>> files = new ArrayList<>();
            while (rs.next()) {
                Map<String, Object> fila = new LinkedHashMap<>();
                for (int i = 1; i <= columnes.getColumnCount(); i++) {
                    fila.put(columnes.getColumnLabel(i), rs.getObject(i));
                }
                files.add(fila);
            }
            return files;
        }
    }

    /** Com llista(), però per a consultes d'una sola fila. Torna null si no n'hi ha cap. */
    public static Map<String, Object> una(String sql, Object... parametres) throws SQLException {
        List<Map<String, Object>> files = llista(sql, parametres);
        return files.isEmpty() ? null : files.get(0);
    }

    /** Per a consultes d'una sola columna: torna només els valors, com a text. */
    public static List<String> textos(String sql, Object... parametres) throws SQLException {
        List<String> res = new ArrayList<>();
        for (Map<String, Object> fila : llista(sql, parametres)) {
            Object valor = fila.values().iterator().next();
            if (valor != null) res.add(valor.toString());
        }
        return res;
    }

    private static String entorn(String nom, String perDefecte) {
        String valor = System.getenv(nom);
        return (valor == null || valor.isBlank()) ? perDefecte : valor;
    }
}
