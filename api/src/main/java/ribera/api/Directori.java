package ribera.api;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import ribera.api.Models.*;
import ribera.bd.Jdbc;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Consultes de lectura del directori (JDBC + PreparedStatement).
 * Les llistes relacionades es construeixen amb json_agg per evitar N+1 consultes.
 */
public class Directori {

    private final DataSource ds;
    private final ObjectMapper om = new ObjectMapper();
    private static final TypeReference<List<Ref>> LLISTA_REF = new TypeReference<>() {};

    public Directori(DataSource ds) {
        this.ds = ds;
    }

    /** Filtres opcionals i combinables per a serveis i centres. */
    public record Filtres(String q, Long municipiId, String collectiu, String tipusCentre, Long serveiId, boolean nomesAmbPunt) {}

    // ================================================================= catàlegs i territori

    public List<Municipi> municipis() throws SQLException {
        try (Connection c = ds.getConnection()) {
            return Jdbc.llista(c, """
                    SELECT m.id, codi_origen('municipi', m.id) AS codi, m.nom,
                           co.id AS comarca_id, codi_origen('comarca', co.id) AS comarca_codi, co.nom AS comarca_nom
                      FROM municipi m JOIN comarca co ON co.id = m.comarca_id
                     ORDER BY normalitza(m.nom)""",
                    rs -> new Municipi(rs.getLong("id"), rs.getString("codi"), rs.getString("nom"),
                            new Ref(rs.getLong("comarca_id"), rs.getString("comarca_codi"), rs.getString("comarca_nom"))));
        }
    }

    public Catalegs catalegs() throws SQLException {
        try (Connection c = ds.getConnection()) {
            Jdbc.Mapejador<Ref> ref = rs -> new Ref(rs.getLong("id"), rs.getString("codi"), rs.getString("nom"));
            return new Catalegs(
                    Jdbc.llista(c, "SELECT id, codi, nom FROM collectiu ORDER BY normalitza(nom)", ref),
                    Jdbc.llista(c, "SELECT id, codi, nom FROM tipus_centre ORDER BY codi", ref),
                    Jdbc.llista(c, "SELECT id, codi, nom FROM forma_juridica ORDER BY codi", ref),
                    Jdbc.llista(c, "SELECT id, codi_origen('comarca', id) AS codi, nom FROM comarca ORDER BY nom", ref));
        }
    }

    // ================================================================= serveis

    private static final String SELECT_SERVEI_RESUM = """
            SELECT s.id, codi_origen('servei', s.id) AS codi, s.nom, s.descripcio,
                   (SELECT coalesce(json_agg(json_build_object('id', co.id, 'codi', co.codi, 'nom', co.nom) ORDER BY co.nom), '[]')
                      FROM servei_collectiu sc JOIN collectiu co ON co.id = sc.collectiu_id
                     WHERE sc.servei_id = s.id) AS collectius,
                   (SELECT coalesce(json_agg(json_build_object('id', e.id, 'codi', codi_origen('entitat', e.id), 'nom', e.nom) ORDER BY e.nom), '[]')
                      FROM prestacio p JOIN entitat e ON e.id = p.entitat_id
                     WHERE p.servei_id = s.id) AS entitats,
                   (SELECT coalesce(json_agg(DISTINCT jsonb_build_object('id', m.id, 'codi', codi_origen('municipi', m.id), 'nom', m.nom)), '[]')
                      FROM prestacio p JOIN prestacio_centre pc ON pc.prestacio_id = p.id
                      JOIN centre ce ON ce.id = pc.centre_id JOIN municipi m ON m.id = ce.municipi_id
                     WHERE p.servei_id = s.id) AS municipis,
                   (SELECT coalesce(json_agg(DISTINCT jsonb_build_object('id', tc.id, 'codi', tc.codi, 'nom', tc.nom)), '[]')
                      FROM prestacio p JOIN prestacio_centre pc ON pc.prestacio_id = p.id
                      JOIN centre ce ON ce.id = pc.centre_id JOIN tipus_centre tc ON tc.id = ce.tipus_centre_id
                     WHERE p.servei_id = s.id) AS tipus_centre
              FROM servei s
            """;

    private ServeiResum serveiResum(ResultSet rs) throws SQLException {
        return new ServeiResum(rs.getLong("id"), rs.getString("codi"), rs.getString("nom"), rs.getString("descripcio"),
                refs(rs.getString("collectius")), refs(rs.getString("entitats")), refs(rs.getString("municipis")),
                refs(rs.getString("tipus_centre")));
    }

    /**
     * Cerca de serveis. El filtre de municipi i de tipus de centre recorre
     * prestació → centre (on es presta), no la seu de l'entitat.
     */
    public List<ServeiResum> serveis(Filtres f) throws SQLException {
        StringBuilder sql = new StringBuilder(SELECT_SERVEI_RESUM).append(" WHERE TRUE");
        List<Object> p = new ArrayList<>();
        if (f.q() != null && !f.q().isBlank()) {
            for (String patro : patrons(f.q())) {
                sql.append(" ").append("""
                         AND (normalitza(s.nom) LIKE ? OR normalitza(s.descripcio) LIKE ?
                              OR EXISTS (SELECT 1 FROM servei_collectiu sc JOIN collectiu co ON co.id = sc.collectiu_id
                                          WHERE sc.servei_id = s.id AND normalitza(co.nom) LIKE ?)
                              OR EXISTS (SELECT 1 FROM prestacio pr JOIN entitat e ON e.id = pr.entitat_id
                                          WHERE pr.servei_id = s.id AND normalitza(e.nom) LIKE ?)
                              OR EXISTS (SELECT 1 FROM prestacio pr JOIN prestacio_centre pc ON pc.prestacio_id = pr.id
                                          JOIN centre ce ON ce.id = pc.centre_id JOIN municipi mu ON mu.id = ce.municipi_id
                                          WHERE pr.servei_id = s.id AND normalitza(mu.nom) LIKE ?))""");
                for (int i = 0; i < 5; i++) p.add(patro);
            }
        }
        if (f.collectiu() != null) {
            sql.append(" AND EXISTS (SELECT 1 FROM servei_collectiu sc JOIN collectiu co ON co.id = sc.collectiu_id WHERE sc.servei_id = s.id AND co.codi = ?)");
            p.add(f.collectiu());
        }
        if (f.municipiId() != null || f.tipusCentre() != null) {
            sql.append(" AND EXISTS (SELECT 1 FROM prestacio pr JOIN prestacio_centre pc ON pc.prestacio_id = pr.id "
                    + "JOIN centre ce ON ce.id = pc.centre_id LEFT JOIN tipus_centre tc ON tc.id = ce.tipus_centre_id WHERE pr.servei_id = s.id");
            if (f.municipiId() != null) { sql.append(" AND ce.municipi_id = ?"); p.add(f.municipiId()); }
            if (f.tipusCentre() != null) { sql.append(" AND tc.codi = ?"); p.add(f.tipusCentre()); }
            sql.append(")");
        }
        sql.append(" ORDER BY normalitza(s.nom)");
        try (Connection c = ds.getConnection()) {
            return Jdbc.llista(c, sql.toString(), this::serveiResum, p.toArray());
        }
    }

    public Optional<ServeiDetall> servei(long id) throws SQLException {
        try (Connection c = ds.getConnection()) {
            Optional<ServeiDetall> base = Jdbc.un(c, """
                    SELECT s.*, codi_origen('servei', s.id) AS codi, f.codi AS f_codi, f.referencia AS f_ref
                      FROM servei s LEFT JOIN font f ON f.id = s.font_id WHERE s.id = ?""",
                    rs -> new ServeiDetall(rs.getLong("id"), rs.getString("codi"), rs.getString("nom"), rs.getString("descripcio"),
                            rs.getString("modalitat_codi"), rs.getString("via_acces"), rs.getString("cobertura"),
                            rs.getString("imatge"), rs.getString("observacions"), font(rs, "f_codi", "f_ref"),
                            null, null, null, null), id);
            if (base.isEmpty()) return base;
            ServeiDetall b = base.get();

            List<Ref> collectius = Jdbc.llista(c, """
                    SELECT co.id, co.codi, co.nom FROM servei_collectiu sc JOIN collectiu co ON co.id = sc.collectiu_id
                     WHERE sc.servei_id = ? ORDER BY co.nom""",
                    rs -> new Ref(rs.getLong("id"), rs.getString("codi"), rs.getString("nom")), id);

            List<Prestacio> prestacions = new ArrayList<>();
            for (var pr : Jdbc.llista(c, """
                    SELECT p.id, e.id AS e_id, codi_origen('entitat', e.id) AS e_codi, e.nom AS e_nom,
                           f.codi AS f_codi, f.referencia AS f_ref
                      FROM prestacio p JOIN entitat e ON e.id = p.entitat_id LEFT JOIN font f ON f.id = p.font_id
                     WHERE p.servei_id = ? ORDER BY e.nom""",
                    rs -> new Object[]{rs.getLong("id"), new Ref(rs.getLong("e_id"), rs.getString("e_codi"), rs.getString("e_nom")),
                            font(rs, "f_codi", "f_ref")}, id)) {
                List<CentreResum> centres = Jdbc.llista(c, SELECT_CENTRE_RESUM
                        + " JOIN prestacio_centre pc ON pc.centre_id = c.id WHERE pc.prestacio_id = ? ORDER BY c.nom",
                        this::centreResum, pr[0]);
                prestacions.add(new Prestacio((Ref) pr[1], (Font) pr[2], centres));
            }
            return Optional.of(new ServeiDetall(b.id(), b.codi(), b.nom(), b.descripcio(), b.modalitatCodi(), b.viaAcces(),
                    b.cobertura(), b.imatge(), b.observacions(), b.font(), collectius,
                    contactes(c, "servei_id", id), horaris(c, "servei_id", id), prestacions));
        }
    }

    // ================================================================= centres

    private static final String SELECT_CENTRE_RESUM = """
            SELECT c.id, codi_origen('centre', c.id) AS codi, c.nom, c.adreca, c.codi_postal,
                   c.latitud, c.longitud, c.precisio_punt,
                   tc.id AS tc_id, tc.codi AS tc_codi, tc.nom AS tc_nom,
                   m.id AS m_id, codi_origen('municipi', m.id) AS m_codi, m.nom AS m_nom
              FROM centre c
              LEFT JOIN tipus_centre tc ON tc.id = c.tipus_centre_id
              LEFT JOIN municipi m ON m.id = c.municipi_id
            """;

    private CentreResum centreResum(ResultSet rs) throws SQLException {
        return new CentreResum(rs.getLong("id"), rs.getString("codi"), rs.getString("nom"),
                ref(rs, "tc_id", "tc_codi", "tc_nom"), ref(rs, "m_id", "m_codi", "m_nom"),
                rs.getString("adreca"), rs.getString("codi_postal"),
                Jdbc.doble(rs, "latitud"), Jdbc.doble(rs, "longitud"), rs.getString("precisio_punt"));
    }

    /** Llista de centres. Amb nomesAmbPunt=true només els que tenen coordenades (per al mapa). */
    public List<CentreResum> centres(Filtres f) throws SQLException {
        StringBuilder sql = new StringBuilder(SELECT_CENTRE_RESUM).append(" WHERE TRUE");
        List<Object> p = new ArrayList<>();
        if (f.q() != null && !f.q().isBlank()) {
            for (String patro : patrons(f.q())) {
                sql.append(" AND (normalitza(c.nom) LIKE ? OR normalitza(c.adreca) LIKE ? OR normalitza(m.nom) LIKE ?)");
                p.add(patro); p.add(patro); p.add(patro);
            }
        }
        if (f.municipiId() != null) { sql.append(" AND c.municipi_id = ?"); p.add(f.municipiId()); }
        if (f.tipusCentre() != null) { sql.append(" AND tc.codi = ?"); p.add(f.tipusCentre()); }
        if (f.collectiu() != null) {
            sql.append(" AND EXISTS (SELECT 1 FROM prestacio_centre pc JOIN prestacio pr ON pr.id = pc.prestacio_id "
                    + "JOIN servei_collectiu sc ON sc.servei_id = pr.servei_id JOIN collectiu co ON co.id = sc.collectiu_id "
                    + "WHERE pc.centre_id = c.id AND co.codi = ?)");
            p.add(f.collectiu());
        }
        if (f.serveiId() != null) {
            sql.append(" AND EXISTS (SELECT 1 FROM prestacio_centre pc JOIN prestacio pr ON pr.id = pc.prestacio_id "
                    + "WHERE pc.centre_id = c.id AND pr.servei_id = ?)");
            p.add(f.serveiId());
        }
        if (f.nomesAmbPunt()) sql.append(" AND c.latitud IS NOT NULL AND c.longitud IS NOT NULL");
        sql.append(" ORDER BY normalitza(c.nom)");
        try (Connection c = ds.getConnection()) {
            return Jdbc.llista(c, sql.toString(), this::centreResum, p.toArray());
        }
    }

    public Optional<CentreDetall> centre(long id) throws SQLException {
        try (Connection c = ds.getConnection()) {
            Optional<CentreResum> r = Jdbc.un(c, SELECT_CENTRE_RESUM + " WHERE c.id = ?", this::centreResum, id);
            if (r.isEmpty()) return Optional.empty();
            CentreResum b = r.get();
            record Extra(String imatge, Ref titular, Ref gestor, Font font, Font fontPunt) {}
            Extra x = Jdbc.un(c, """
                    SELECT c.imatge,
                           t.id AS t_id, codi_origen('entitat', t.id) AS t_codi, t.nom AS t_nom,
                           g.id AS g_id, codi_origen('entitat', g.id) AS g_codi, g.nom AS g_nom,
                           f.codi AS f_codi, f.referencia AS f_ref, fp.codi AS fp_codi, fp.referencia AS fp_ref
                      FROM centre c
                      LEFT JOIN entitat t ON t.id = c.titular_id
                      LEFT JOIN entitat g ON g.id = c.gestor_id
                      LEFT JOIN font f ON f.id = c.font_id
                      LEFT JOIN font fp ON fp.id = c.font_punt_id
                     WHERE c.id = ?""",
                    rs -> new Extra(rs.getString("imatge"), ref(rs, "t_id", "t_codi", "t_nom"), ref(rs, "g_id", "g_codi", "g_nom"),
                            font(rs, "f_codi", "f_ref"), font(rs, "fp_codi", "fp_ref")), id).orElseThrow();
            List<ServeiResum> serveis = Jdbc.llista(c, SELECT_SERVEI_RESUM + " " + """
                     WHERE EXISTS (SELECT 1 FROM prestacio pr JOIN prestacio_centre pc ON pc.prestacio_id = pr.id
                                    WHERE pr.servei_id = s.id AND pc.centre_id = ?)
                     ORDER BY normalitza(s.nom)""", this::serveiResum, id);
            return Optional.of(new CentreDetall(b.id(), b.codi(), b.nom(), b.tipusCentre(), b.municipi(), b.adreca(),
                    b.codiPostal(), b.latitud(), b.longitud(), b.precisioPunt(), x.fontPunt(), x.imatge(), x.titular(),
                    x.gestor(), x.font(), contactes(c, "centre_id", id), horaris(c, "centre_id", id), serveis));
        }
    }

    // ================================================================= entitats

    private static final String SELECT_ENTITAT = """
            SELECT e.id, codi_origen('entitat', e.id) AS codi, e.nom, e.sector, e.adreca, e.codi_postal,
                   fj.id AS fj_id, fj.codi AS fj_codi, fj.nom AS fj_nom,
                   m.id AS m_id, codi_origen('municipi', m.id) AS m_codi, m.nom AS m_nom,
                   f.codi AS f_codi, f.referencia AS f_ref
              FROM entitat e
              LEFT JOIN forma_juridica fj ON fj.id = e.forma_juridica_id
              LEFT JOIN municipi m ON m.id = e.municipi_id
              LEFT JOIN font f ON f.id = e.font_id
            """;

    public List<EntitatResum> entitats(String q) throws SQLException {
        StringBuilder sql = new StringBuilder(SELECT_ENTITAT);
        List<Object> p = new ArrayList<>();
        sql.append(" WHERE TRUE");
        if (q != null && !q.isBlank()) {
            for (String patro : patrons(q)) { sql.append(" AND normalitza(e.nom) LIKE ?"); p.add(patro); }
        }
        sql.append(" ORDER BY normalitza(e.nom)");
        try (Connection c = ds.getConnection()) {
            return Jdbc.llista(c, sql.toString(), rs -> new EntitatResum(rs.getLong("id"), rs.getString("codi"),
                    rs.getString("nom"), ref(rs, "fj_id", "fj_codi", "fj_nom"), rs.getString("sector"),
                    ref(rs, "m_id", "m_codi", "m_nom")), p.toArray());
        }
    }

    public Optional<EntitatDetall> entitat(long id) throws SQLException {
        try (Connection c = ds.getConnection()) {
            Optional<EntitatDetall> base = Jdbc.un(c, SELECT_ENTITAT + " WHERE e.id = ?",
                    rs -> new EntitatDetall(rs.getLong("id"), rs.getString("codi"), rs.getString("nom"),
                            ref(rs, "fj_id", "fj_codi", "fj_nom"), rs.getString("sector"), rs.getString("adreca"),
                            ref(rs, "m_id", "m_codi", "m_nom"), rs.getString("codi_postal"), font(rs, "f_codi", "f_ref"),
                            null, null, null, null, null), id);
            if (base.isEmpty()) return base;
            EntitatDetall b = base.get();
            List<ServeiResum> serveis = Jdbc.llista(c, SELECT_SERVEI_RESUM
                    + " WHERE EXISTS (SELECT 1 FROM prestacio pr WHERE pr.servei_id = s.id AND pr.entitat_id = ?) ORDER BY normalitza(s.nom)",
                    this::serveiResum, id);
            List<CentreResum> titulats = Jdbc.llista(c, SELECT_CENTRE_RESUM + " WHERE c.titular_id = ? ORDER BY c.nom", this::centreResum, id);
            List<CentreResum> gestionats = Jdbc.llista(c, SELECT_CENTRE_RESUM + " WHERE c.gestor_id = ? ORDER BY c.nom", this::centreResum, id);
            return Optional.of(new EntitatDetall(b.id(), b.codi(), b.nom(), b.formaJuridica(), b.sector(), b.adreca(),
                    b.municipi(), b.codiPostal(), b.font(), contactes(c, "entitat_id", id), horaris(c, "entitat_id", id),
                    serveis, titulats, gestionats));
        }
    }

    // ================================================================= fills comuns

    private List<Contacte> contactes(Connection c, String colPare, long id) throws SQLException {
        return Jdbc.llista(c, "SELECT tipus, valor FROM contacte WHERE " + colPare + " = ? ORDER BY ordre, id",
                rs -> new Contacte(rs.getString("tipus"), rs.getString("valor")), id);
    }

    private List<Horari> horaris(Connection c, String colPare, long id) throws SQLException {
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

    // ================================================================= utilitats

    /** Un patró LIKE per paraula: totes les paraules han d'aparéixer (en qualsevol camp). */
    private static List<String> patrons(String q) {
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

    private static Ref ref(ResultSet rs, String id, String codi, String nom) throws SQLException {
        Long v = Jdbc.llarg(rs, id);
        return v == null ? null : new Ref(v, rs.getString(codi), rs.getString(nom));
    }

    private static Font font(ResultSet rs, String codi, String ref) throws SQLException {
        String c = rs.getString(codi);
        return c == null ? null : new Font(c, rs.getString(ref));
    }

    private List<Ref> refs(String json) {
        try {
            List<Ref> l = om.readValue(json, LLISTA_REF);
            l.sort((x, y) -> normalitzaJava(x.nom()).compareTo(normalitzaJava(y.nom())));
            return l;
        } catch (Exception e) {
            throw new IllegalStateException("JSON intern no vàlid: " + json, e);
        }
    }
}
