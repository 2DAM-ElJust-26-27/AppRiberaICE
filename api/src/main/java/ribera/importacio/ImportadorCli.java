package ribera.importacio;

import ribera.Configuracio;
import ribera.bd.BaseDades;

import javax.sql.DataSource;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.sql.Connection;

/**
 * Executa només la importació:
 *   java -cp target/api.jar ribera.importacio.ImportadorCli [directori_dades]
 * Retorna codi d'eixida 1 si hi ha errors.
 */
public final class ImportadorCli {

    public static void main(String[] args) throws Exception {
        System.setOut(new PrintStream(System.out, true, StandardCharsets.UTF_8));
        Configuracio cfg = Configuracio.desDeEntorn();
        Path dir = args.length > 0 ? Path.of(args[0]) : cfg.dirDades();
        DataSource ds = BaseDades.dataSource(cfg);
        BaseDades.esperaDisponible(ds, 15);
        try (Connection c = ds.getConnection()) {
            InformeImportacio inf = new Importador(c, dir).importa();
            System.out.print(inf.resum());
            if (!inf.correcte()) System.exit(1);
        }
    }
}
