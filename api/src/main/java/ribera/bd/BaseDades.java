package ribera.bd;

import org.postgresql.ds.PGSimpleDataSource;
import ribera.Configuracio;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.SQLException;

/** Crea el DataSource de PostgreSQL i espera que la base de dades estiga disponible. */
public final class BaseDades {

    private BaseDades() {}

    public static DataSource dataSource(Configuracio cfg) {
        PGSimpleDataSource ds = new PGSimpleDataSource();
        ds.setUrl(cfg.bdUrl());
        ds.setUser(cfg.bdUsuari());
        ds.setPassword(cfg.bdContrasenya());
        return ds;
    }

    /** Reintenta la connexió uns segons (útil quan Docker arrenca la BD i l'API alhora). */
    public static void esperaDisponible(DataSource ds, int intents) throws InterruptedException {
        for (int i = 1; i <= intents; i++) {
            try (Connection c = ds.getConnection()) {
                return;
            } catch (SQLException e) {
                System.out.println("Esperant la base de dades (" + i + "/" + intents + "): " + e.getMessage());
                Thread.sleep(2000);
            }
        }
        throw new IllegalStateException("No s'ha pogut connectar a la base de dades");
    }
}
