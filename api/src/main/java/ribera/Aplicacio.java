package ribera;

import io.javalin.Javalin;
import io.javalin.http.Context;

import java.sql.Connection;
import java.util.Map;

/**
 * Punt d'entrada de l'API (les dades les carrega abans l'Importador). Totes les rutes són GET: només es consulta.
 *
 *   GET /api/centres            GET /api/centres?servei={id}     GET /api/centres/{id}
 *   GET /api/serveis            GET /api/serveis?municipi={id}   GET /api/serveis/{id}
 *   GET /api/entitats           GET /api/entitats/{id}
 */
public class Aplicacio {

    public static void main(String[] args) throws Exception {
        esperaBaseDades();
        crea().start(8080);
    }

    /** Crea l'aplicació amb les rutes (separat de main per poder provar-la). */
    public static Javalin crea() {
        Javalin app = Javalin.create(config -> {
            // L'app web s'obri en un altre port: el navegador necessita permís (CORS)
            config.bundledPlugins.enableCors(cors -> cors.addRule(regla -> regla.anyHost()));
        });

        app.get("/api/centres", ctx -> ctx.json(Consultes.centres(numero(ctx, "servei"))));
        app.get("/api/centres/{id}", ctx -> retorna(ctx, Consultes.centre(id(ctx))));

        app.get("/api/serveis", ctx -> ctx.json(Consultes.serveis(numero(ctx, "municipi"))));
        app.get("/api/serveis/{id}", ctx -> retorna(ctx, Consultes.servei(id(ctx))));

        app.get("/api/entitats", ctx -> ctx.json(Consultes.entitats()));
        app.get("/api/entitats/{id}", ctx -> retorna(ctx, Consultes.entitat(id(ctx))));

        // Si l'id no és un número: error 400
        app.exception(NumberFormatException.class, (e, ctx) ->
                ctx.status(400).json(Map.of("error", "L'id ha de ser un número")));
        return app;
    }

    /** Torna la fitxa o, si no existeix, un error 404. */
    private static void retorna(Context ctx, Map<String, Object> fitxa) {
        if (fitxa == null) {
            ctx.status(404).json(Map.of("error", "No existeix"));
        } else {
            ctx.json(fitxa);
        }
    }

    private static long id(Context ctx) {
        return Long.parseLong(ctx.pathParam("id"));
    }

    /** Paràmetre opcional de l'adreça (?servei=4). Null si no hi és. */
    private static Long numero(Context ctx, String nom) {
        String valor = ctx.queryParam(nom);
        return (valor == null || valor.isBlank()) ? null : Long.parseLong(valor);
    }

    /** Docker arranca la BD i l'API alhora: esperem fins que la BD respon. */
    private static void esperaBaseDades() throws InterruptedException {
        for (int intent = 1; intent <= 30; intent++) {
            try (Connection c = BaseDades.connecta()) {
                return;
            } catch (Exception e) {
                System.out.println("Esperant la base de dades...");
                Thread.sleep(2000);
            }
        }
        throw new IllegalStateException("No s'ha pogut connectar a la base de dades");
    }
}
