package ribera;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.PropertyNamingStrategies;
import io.javalin.Javalin;
import io.javalin.json.JavalinJackson;
import ribera.api.Directori;
import ribera.api.Rutes;
import ribera.bd.BaseDades;
import ribera.importacio.Importador;
import ribera.importacio.InformeImportacio;

import javax.sql.DataSource;
import java.io.PrintStream;
import java.nio.charset.StandardCharsets;
import java.sql.Connection;

/**
 * Punt d'entrada de l'API de Connectant la Ribera.
 * Si IMPORTAR_EN_ARRANCAR=true, importa abans les dades de DIR_DADES (idempotent).
 */
public final class Aplicacio {

    public static void main(String[] args) throws Exception {
        System.setOut(new PrintStream(System.out, true, StandardCharsets.UTF_8));
        Configuracio cfg = Configuracio.desDeEntorn();
        DataSource ds = BaseDades.dataSource(cfg);
        BaseDades.esperaDisponible(ds, 30);

        if (cfg.importarEnArrancar()) {
            try (Connection c = ds.getConnection()) {
                InformeImportacio inf = new Importador(c, cfg.dirDades(), cfg.dirComplements()).importa();
                System.out.print(inf.resum());
            }
        }

        crea(ds).start(cfg.port());
        System.out.println("API de Connectant la Ribera escoltant al port " + cfg.port());
    }

    /** Crea l'aplicació Javalin (separat de main per poder provar-la). */
    public static Javalin crea(DataSource ds) {
        ObjectMapper om = new ObjectMapper().setPropertyNamingStrategy(PropertyNamingStrategies.SNAKE_CASE);
        Javalin app = Javalin.create(config -> {
            config.jsonMapper(new JavalinJackson(om, false));
            config.http.defaultContentType = "application/json; charset=utf-8";
            // El client Flutter web s'executa en un altre origen (port): cal CORS.
            config.bundledPlugins.enableCors(cors -> cors.addRule(regla -> regla.anyHost()));
            config.showJavalinBanner = false;
        });
        Rutes.registra(app, new Directori(ds));
        return app;
    }
}
