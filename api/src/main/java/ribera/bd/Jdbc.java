package ribera.bd;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Types;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/** Utilitats mínimes de JDBC: consultes parametritzades amb PreparedStatement. */
public final class Jdbc {

    private Jdbc() {}

    @FunctionalInterface
    public interface Mapejador<T> {
        T mapeja(ResultSet rs) throws SQLException;
    }

    public static <T> List<T> llista(Connection c, String sql, Mapejador<T> m, Object... params) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            assigna(ps, params);
            try (ResultSet rs = ps.executeQuery()) {
                List<T> res = new ArrayList<>();
                while (rs.next()) res.add(m.mapeja(rs));
                return res;
            }
        }
    }

    public static <T> Optional<T> un(Connection c, String sql, Mapejador<T> m, Object... params) throws SQLException {
        List<T> l = llista(c, sql, m, params);
        return l.isEmpty() ? Optional.empty() : Optional.of(l.get(0));
    }

    /** Executa un INSERT/UPDATE/DELETE i retorna les files afectades. */
    public static int executa(Connection c, String sql, Object... params) throws SQLException {
        try (PreparedStatement ps = c.prepareStatement(sql)) {
            assigna(ps, params);
            return ps.executeUpdate();
        }
    }

    /** Executa una sentència amb RETURNING id i retorna l'id (o null si no retorna cap fila). */
    public static Long retornaId(Connection c, String sql, Object... params) throws SQLException {
        return un(c, sql, rs -> rs.getLong(1), params).orElse(null);
    }

    public static long compta(Connection c, String sql, Object... params) throws SQLException {
        return un(c, sql, rs -> rs.getLong(1), params).orElse(0L);
    }

    /** Llegeix un BIGINT que pot ser nul. */
    public static Long llarg(ResultSet rs, String col) throws SQLException {
        long v = rs.getLong(col);
        return rs.wasNull() ? null : v;
    }

    /** Llegeix un NUMERIC que pot ser nul com a Double. */
    public static Double doble(ResultSet rs, String col) throws SQLException {
        double v = rs.getDouble(col);
        return rs.wasNull() ? null : v;
    }

    private static void assigna(PreparedStatement ps, Object... params) throws SQLException {
        for (int i = 0; i < params.length; i++) {
            Object p = params[i];
            if (p == null) ps.setNull(i + 1, Types.NULL);
            else ps.setObject(i + 1, p);
        }
    }
}
