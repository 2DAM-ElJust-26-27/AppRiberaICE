package ribera.api;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import ribera.api.Models.*;
import ribera.bd.Jdbc;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

/** Ajudes de {@link Directori}: fills comuns (contactes, horaris), cerca i conversió de files. */
final class Mapejos {

    private static final ObjectMapper OM = new ObjectMapper();
    private static final TypeReference<List<Ref>> LLISTA_REF = new TypeReference<>() {};

    private Mapejos() {}

    static List<Contacte> contactes(Connection c, String colPare, long id) throws SQLException {
        return Jdbc.llista(c, "SELECT tipus, valor FROM contacte WHERE " + colPare + " = ? ORDER BY ordre, id",
                rs -> new Contacte(rs.getString("tipus"), rs.getString("valor")), id);
    }

    static List<Horari> horaris(Connection c, String colPare, long id) throws SQLException {
        List<Horari> res = new ArrayList<>();
        for (var h : Jdbc.llista(c, "SELECT * FROM horari WHERE " + colPare + " = ? ORDER BY ordre, id",
                rs -> new Object[]{rs.getLong("id"), rs.getString("tipus"), rs.getString("descripcio"), rs.getString("zona_horaria"),
                        rs.getString("vigent_des_de"), rs.getString("vigent_fins_a")}, id)) {
            List<Franja> franges = Jdbc.llista(c, """
                    SELECT dia_setmana, to_char(hora_inici, 'HH24:MI') AS ini, to_char(hora_fi, 'HH24:MI') AS fi, final_dia_seguent
                      FROM franja WHERE horari_id = ? ORDER BY dia_setmana, hora_inici""",
                    rs -> new Franja(rs.getInt("dia_setmana"), rs.getString("ini"), rs.getString("fi"), rs.getBoolean("final_dia_seguent")),
                    h[0]);
            res.add(new Horari((String) h[1], (String) h[2], (String) h[3], (String) h[4], (String) h[5], franges));
        }
        return res;
    }

    /** Un patró LIKE per paraula: totes les paraules han d'aparéixer (en qualsevol camp). */
    static List<String> patrons(String q) {
        List<String> res = new ArrayList<>();
        for (String paraula : normalitzaJava(q).trim().split("\\s+")) {
            if (paraula.isBlank()) continue;
            String net = paraula.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
            res.add("%" + net + "%");
        }
        return res;
    }

    /** Mateixa normalització que la funció SQL normalitza(). */
    static String normalitzaJava(String t) {
        String a = "àáâäèéêëìíîïòóôöùúûüçñ·’'";
        String b = "aaaaeeeeiiiioooouuuucn.  ";
        StringBuilder sb = new StringBuilder();
        for (char ch : t.toLowerCase().toCharArray()) {
            int i = a.indexOf(ch);
            sb.append(i >= 0 ? b.charAt(i) : ch);
        }
        return sb.toString();
    }

    static Ref ref(ResultSet rs, String id, String codi, String nom) throws SQLException {
        Long v = Jdbc.llarg(rs, id);
        return v == null ? null : new Ref(v, rs.getString(codi), rs.getString(nom));
    }

    static Font font(ResultSet rs, String codi, String ref) throws SQLException {
        String c = rs.getString(codi);
        return c == null ? null : new Font(c, rs.getString(ref));
    }

    static List<Ref> refs(String json) {
        try {
            List<Ref> l = OM.readValue(json, LLISTA_REF);
            l.sort((x, y) -> normalitzaJava(x.nom()).compareTo(normalitzaJava(y.nom())));
            return l;
        } catch (Exception e) {
            throw new IllegalStateException("JSON intern no vàlid: " + json, e);
        }
    }
}
